package com.example.storage_optimizer_new

import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.pdf.PdfRenderer
import android.media.MediaMetadataRetriever
import android.os.Build
import android.os.Environment
import android.os.ParcelFileDescriptor
import android.os.StatFs
import androidx.work.ExistingPeriodicWorkPolicy
import androidx.work.OneTimeWorkRequestBuilder
import androidx.work.PeriodicWorkRequestBuilder
import androidx.work.WorkManager
import java.io.ByteArrayOutputStream
import java.io.File
import java.util.Locale
import java.util.concurrent.TimeUnit
import com.chaquo.python.Python
import com.chaquo.python.android.AndroidPlatform
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val channel = "com.example.storage_optimizer/storage"

    private companion object {
        val videoExts = setOf(
            "mp4", "avi", "mkv", "mov", "wmv", "flv", "3gp", "webm", "ts"
        )
        val audioExts = setOf(
            "mp3", "aac", "wav", "flac", "ogg", "m4a", "wma", "opus"
        )
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Initialise Chaquopy Python runtime (on-device, no internet needed)
        if (!Python.isStarted()) {
            Python.start(AndroidPlatform(this))
        }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channel)
            .setMethodCallHandler { call, result ->
                when (call.method) {

                    // ── Device storage info ──────────────────────────────────
                    "getStorageInfo" -> {
                        try {
                            val path = Environment.getExternalStorageDirectory().absolutePath
                            val stat = StatFs(path)
                            result.success(
                                mapOf(
                                    "totalBytes" to stat.totalBytes,
                                    "usedBytes"  to (stat.totalBytes - stat.availableBytes),
                                    "freeBytes"  to stat.availableBytes,
                                )
                            )
                        } catch (e: Exception) {
                            result.error("STORAGE_ERROR", e.message, null)
                        }
                    }

                    "getSdkInt" -> result.success(Build.VERSION.SDK_INT)

                    // ── Proactive alerts: background new-media watcher ───────
                    "setMediaWatchEnabled" -> {
                        val enabled = call.argument<Boolean>("enabled") ?: false
                        try {
                            if (enabled) scheduleMediaWatch() else cancelMediaWatch()
                            result.success(enabled)
                        } catch (e: Exception) {
                            result.error("WATCH_ERROR", e.message, null)
                        }
                    }

                    "isMediaWatchEnabled" -> {
                        try {
                            val infos = WorkManager.getInstance(applicationContext)
                                .getWorkInfosForUniqueWork(MediaWatchWorker.WORK_NAME)
                                .get()
                            result.success(
                                infos.any { !it.state.isFinished }
                            )
                        } catch (e: Exception) {
                            result.success(false)
                        }
                    }

                    // Runs the watcher immediately so the user can confirm the
                    // alert works without waiting for the next periodic run.
                    "checkMediaNow" -> {
                        try {
                            WorkManager.getInstance(applicationContext).enqueue(
                                OneTimeWorkRequestBuilder<MediaWatchWorker>().build()
                            )
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("WATCH_ERROR", e.message, null)
                        }
                    }

                    // ── Preview: thumbnail bytes for non-image media ─────────
                    // Images are decoded directly by Flutter; video frames,
                    // embedded album art and PDF pages can only be reached
                    // through the platform APIs, so they come across as PNG.
                    "getThumbnail" -> {
                        val path = call.argument<String>("path")
                        val maxSize = call.argument<Int>("maxSize") ?: 512
                        if (path == null) {
                            result.success(null)
                        } else {
                            try {
                                result.success(buildThumbnail(path, maxSize))
                            } catch (e: Exception) {
                                // An unreadable or corrupt file is a normal
                                // outcome here, not an error worth surfacing.
                                result.success(null)
                            }
                        }
                    }

                    // ── Preview: human-readable media metadata ───────────────
                    "getMediaInfo" -> {
                        val path = call.argument<String>("path")
                        if (path == null) {
                            result.success(emptyMap<String, String>())
                        } else {
                            try {
                                result.success(readMediaInfo(path))
                            } catch (e: Exception) {
                                result.success(emptyMap<String, String>())
                            }
                        }
                    }

                    // ── AI: Storage growth forecasting (scikit-learn) ────────
                    "runForecast" -> {
                        try {
                            val timestamps = toDoubleList(call.argument("timestamps"))
                            val usedBytes  = toDoubleList(call.argument("usedBytes"))
                            val totalBytes = (call.argument<Number>("totalBytes"))
                                ?.toDouble() ?: 0.0

                            val py     = Python.getInstance()
                            val module = py.getModule("storage_predictor")
                            // Pass primitive arrays, not Java collections. Chaquopy
                            // exposes a java.util.List as an opaque proxy that Python
                            // cannot iterate or measure ("'ArrayList' object is not
                            // iterable"), whereas a Java array arrives as a jarray,
                            // which supports the sequence protocol and numpy.
                            val res    = module.callAttr(
                                "forecast",
                                timestamps.toDoubleArray(),
                                usedBytes.toDoubleArray(),
                                totalBytes,
                            )

                            // Read dict entries through Python's own dict.get.
                            // Chaquopy's PyObject implements Map as ATTRIBUTE access,
                            // so res["mae"] asks a dict for an attribute called "mae",
                            // finds none and yields null — which silently collapsed
                            // every engine result to the defaults below.
                            val payload = mutableMapOf<String, Any?>(
                                "daysUntilFull"    to (res.callAttr("get", "days_until_full")?.toInt() ?: -1),
                                "dailyGrowthBytes" to (res.callAttr("get", "daily_growth_bytes")?.toDouble() ?: 0.0),
                                "mae"              to (res.callAttr("get", "mae")?.toDouble()  ?: 0.0),
                                "rmse"             to (res.callAttr("get", "rmse")?.toDouble() ?: 0.0),
                                "r2"               to (res.callAttr("get", "r2")?.toDouble()   ?: 0.0),
                            )
                            // The engine reports failure in-band. Forward it, or the
                            // Dart side accepts the zeroed metrics as a real result
                            // and never falls back to its own regression.
                            res.callAttr("get", "error")?.let { payload["error"] = it.toString() }
                            result.success(payload)
                        } catch (e: Exception) {
                            result.error("FORECAST_ERROR", e.message, null)
                        }
                    }

                    // ── AI: Value-based file scoring (numpy) ─────────────────
                    "scoreFiles" -> {
                        try {
                            val days   = toDoubleList(call.argument("daysSinceAccess"))
                            val counts = toIntList(call.argument("accessCounts"))
                            val sizes  = toLongList(call.argument("sizeBytes"))

                            val py     = Python.getInstance()
                            val module = py.getModule("value_scorer")
                            val res    = module.callAttr(
                                "score_files",
                                days.toDoubleArray(),
                                counts.toIntArray(),
                                sizes.toLongArray(),
                            )

                            // Same attribute-vs-item trap as runForecast above.
                            val scores    = res.callAttr("get", "scores")?.asList()
                                ?.map { it.toDouble() } ?: emptyList()
                            val recommended = res.callAttr("get", "recommended")?.asList()
                                ?.map { it.toBoolean() } ?: emptyList()
                            val reasons   = res.callAttr("get", "reasons")?.asList()
                                ?.map { it.toString() } ?: emptyList()

                            result.success(
                                mapOf(
                                    "scores"      to scores,
                                    "recommended" to recommended,
                                    "reasons"     to reasons,
                                )
                            )
                        } catch (e: Exception) {
                            result.error("SCORING_ERROR", e.message, null)
                        }
                    }

                    else -> result.notImplemented()
                }
            }
    }

    // ── Background new-media watcher ─────────────────────────────────────────

    /**
     * Fifteen minutes is the shortest period WorkManager honours for periodic
     * work; anything smaller is silently rounded up to it.
     */
    private fun scheduleMediaWatch() {
        val request = PeriodicWorkRequestBuilder<MediaWatchWorker>(
            15, TimeUnit.MINUTES
        ).build()

        WorkManager.getInstance(applicationContext).enqueueUniquePeriodicWork(
            MediaWatchWorker.WORK_NAME,
            // KEEP, so toggling the setting on twice does not reset the timer
            // and lose the pending run.
            ExistingPeriodicWorkPolicy.KEEP,
            request,
        )
    }

    private fun cancelMediaWatch() {
        WorkManager.getInstance(applicationContext)
            .cancelUniqueWork(MediaWatchWorker.WORK_NAME)
    }

    // ── Preview helpers ──────────────────────────────────────────────────────

    private fun extensionOf(path: String): String =
        path.substringAfterLast('.', "").lowercase()

    /** Renders a preview image for a video, audio or PDF file as PNG bytes. */
    private fun buildThumbnail(path: String, maxSize: Int): ByteArray? {
        val file = File(path)
        if (!file.exists() || !file.canRead()) return null

        val bitmap = when (extensionOf(path)) {
            in videoExts -> videoFrame(path)
            in audioExts -> albumArt(path)
            "pdf" -> pdfFirstPage(file, maxSize)
            else -> null
        } ?: return null

        val scaled = scaleToFit(bitmap, maxSize)
        return ByteArrayOutputStream().use { out ->
            scaled.compress(Bitmap.CompressFormat.PNG, 100, out)
            if (scaled !== bitmap) scaled.recycle()
            bitmap.recycle()
            out.toByteArray()
        }
    }

    /**
     * MediaMetadataRetriever only implements AutoCloseable from API 29, which is
     * above this app's minSdk, so it cannot be used with `use`. Release it by
     * hand instead - leaking one starves the device's media extractor.
     */
    private inline fun <T> withRetriever(
        path: String,
        block: (MediaMetadataRetriever) -> T,
    ): T? {
        val retriever = MediaMetadataRetriever()
        return try {
            retriever.setDataSource(path)
            block(retriever)
        } catch (e: Exception) {
            null
        } finally {
            try {
                retriever.release()
            } catch (e: Exception) {
                // Nothing useful to do if the release itself fails.
            }
        }
    }

    private fun videoFrame(path: String): Bitmap? =
        withRetriever(path) { retriever ->
            // A frame one second in avoids the black leader many clips start on.
            retriever.getFrameAtTime(
                1_000_000, MediaMetadataRetriever.OPTION_CLOSEST_SYNC
            ) ?: retriever.frameAtTime
        }

    private fun albumArt(path: String): Bitmap? =
        withRetriever(path) { retriever ->
            retriever.embeddedPicture?.let {
                BitmapFactory.decodeByteArray(it, 0, it.size)
            }
        }

    private fun pdfFirstPage(file: File, maxSize: Int): Bitmap? {
        ParcelFileDescriptor.open(file, ParcelFileDescriptor.MODE_READ_ONLY)
            .use { descriptor ->
                PdfRenderer(descriptor).use { renderer ->
                    if (renderer.pageCount == 0) return null
                    renderer.openPage(0).use { page ->
                        val scale = maxSize.toFloat() /
                            maxOf(page.width, page.height).coerceAtLeast(1)
                        val width = (page.width * scale).toInt().coerceAtLeast(1)
                        val height = (page.height * scale).toInt().coerceAtLeast(1)
                        val bitmap = Bitmap.createBitmap(
                            width, height, Bitmap.Config.ARGB_8888
                        )
                        // Pages are transparent where there is no ink; paint the
                        // sheet white so the text is legible on a dark theme.
                        Canvas(bitmap).drawColor(Color.WHITE)
                        page.render(
                            bitmap, null, null,
                            PdfRenderer.Page.RENDER_MODE_FOR_DISPLAY
                        )
                        return bitmap
                    }
                }
            }
    }

    private fun scaleToFit(bitmap: Bitmap, maxSize: Int): Bitmap {
        val longest = maxOf(bitmap.width, bitmap.height)
        if (longest <= maxSize || longest == 0) return bitmap
        val scale = maxSize.toFloat() / longest
        return Bitmap.createScaledBitmap(
            bitmap,
            (bitmap.width * scale).toInt().coerceAtLeast(1),
            (bitmap.height * scale).toInt().coerceAtLeast(1),
            true,
        )
    }

    /** Duration, artist, resolution and page counts for the preview panel. */
    private fun readMediaInfo(path: String): Map<String, String> {
        val info = mutableMapOf<String, String>()
        val ext = extensionOf(path)

        if (ext in videoExts || ext in audioExts) {
            withRetriever(path) { retriever ->
                fun key(id: Int): String? =
                    retriever.extractMetadata(id)?.takeIf { it.isNotBlank() }

                key(MediaMetadataRetriever.METADATA_KEY_DURATION)
                    ?.toLongOrNull()
                    ?.let { info["duration"] = formatDuration(it) }
                key(MediaMetadataRetriever.METADATA_KEY_TITLE)
                    ?.let { info["title"] = it }
                key(MediaMetadataRetriever.METADATA_KEY_ARTIST)
                    ?.let { info["artist"] = it }
                key(MediaMetadataRetriever.METADATA_KEY_ALBUM)
                    ?.let { info["album"] = it }

                if (ext in videoExts) {
                    val w = key(MediaMetadataRetriever.METADATA_KEY_VIDEO_WIDTH)
                    val h = key(MediaMetadataRetriever.METADATA_KEY_VIDEO_HEIGHT)
                    if (w != null && h != null) info["resolution"] = "$w x $h"
                }
            }
        } else if (ext == "pdf") {
            val file = File(path)
            if (file.exists() && file.canRead()) {
                ParcelFileDescriptor.open(file, ParcelFileDescriptor.MODE_READ_ONLY)
                    .use { descriptor ->
                        PdfRenderer(descriptor).use { renderer ->
                            info["pages"] = renderer.pageCount.toString()
                        }
                    }
            }
        }
        return info
    }

    private fun formatDuration(millis: Long): String {
        val totalSeconds = millis / 1000
        val hours = totalSeconds / 3600
        val minutes = (totalSeconds % 3600) / 60
        val seconds = totalSeconds % 60
        return if (hours > 0) {
            String.format(Locale.US, "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            String.format(Locale.US, "%d:%02d", minutes, seconds)
        }
    }

    // ── Type-safe list converters ────────────────────────────────────────────

    private fun toDoubleList(raw: List<*>?): List<Double> =
        raw?.map { (it as? Number)?.toDouble() ?: 0.0 } ?: emptyList()

    private fun toIntList(raw: List<*>?): List<Int> =
        raw?.map { (it as? Number)?.toInt() ?: 0 } ?: emptyList()

    private fun toLongList(raw: List<*>?): List<Long> =
        raw?.map { (it as? Number)?.toLong() ?: 0L } ?: emptyList()
}
