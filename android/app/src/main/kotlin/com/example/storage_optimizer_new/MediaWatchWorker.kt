package com.example.storage_optimizer_new

import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.os.Build
import android.provider.MediaStore
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import androidx.work.Worker
import androidx.work.WorkerParameters
import java.util.Locale

/**
 * Periodically asks MediaStore what has appeared since the last run and posts a
 * notification when new media has landed.
 *
 * This is what makes the alerts *proactive*: the in-app checks can only fire
 * while the dashboard is on screen, which is exactly when the user can already
 * see the numbers. WorkManager keeps this running when the app is closed.
 */
class MediaWatchWorker(
    context: Context,
    params: WorkerParameters,
) : Worker(context, params) {

    companion object {
        const val WORK_NAME = "media_watch"
        const val PREFS = "media_watch_prefs"
        const val KEY_LAST_SEEN = "last_seen_epoch_seconds"

        private const val CHANNEL_ID = "storage_optimizer_media"
        private const val CHANNEL_NAME = "New media alerts"
        private const val CHANNEL_DESC =
            "Tells you when new photos, videos or music take up space"
        private const val NOTIFICATION_ID = 3

        /**
         * MediaStore keeps DATE_ADDED in whole seconds, so the watermark is
         * stored in the same unit to avoid comparing across scales.
         */
        fun nowSeconds(): Long = System.currentTimeMillis() / 1000
    }

    override fun doWork(): Result {
        val prefs = applicationContext.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

        // On the very first run there is no watermark. Recording "now" and
        // returning stops the app announcing the user's entire existing library
        // as brand new.
        val lastSeen = prefs.getLong(KEY_LAST_SEEN, -1L)
        if (lastSeen < 0) {
            prefs.edit().putLong(KEY_LAST_SEEN, nowSeconds()).apply()
            return Result.success()
        }

        return try {
            val found = queryNewMedia(lastSeen)
            if (found.count > 0) {
                notifyNewMedia(found)
            }
            // Only move the watermark once the query succeeded, so a failed run
            // does not silently skip over files.
            prefs.edit().putLong(KEY_LAST_SEEN, nowSeconds()).apply()
            Result.success()
        } catch (e: SecurityException) {
            // Storage permission was revoked; retrying immediately would just
            // fail again, so wait for the next scheduled run.
            Result.success()
        } catch (e: Exception) {
            Result.retry()
        }
    }

    private data class NewMedia(val count: Int, val totalBytes: Long, val newest: String?)

    private fun queryNewMedia(sinceSeconds: Long): NewMedia {
        val collection = MediaStore.Files.getContentUri(MediaStore.VOLUME_EXTERNAL)
        val projection = arrayOf(
            MediaStore.Files.FileColumns.DISPLAY_NAME,
            MediaStore.Files.FileColumns.SIZE,
        )
        val selection = "${MediaStore.Files.FileColumns.DATE_ADDED} > ? AND " +
            "${MediaStore.Files.FileColumns.MEDIA_TYPE} IN (?, ?, ?)"
        val args = arrayOf(
            sinceSeconds.toString(),
            MediaStore.Files.FileColumns.MEDIA_TYPE_IMAGE.toString(),
            MediaStore.Files.FileColumns.MEDIA_TYPE_VIDEO.toString(),
            MediaStore.Files.FileColumns.MEDIA_TYPE_AUDIO.toString(),
        )
        val order = "${MediaStore.Files.FileColumns.DATE_ADDED} DESC"

        var count = 0
        var totalBytes = 0L
        var newest: String? = null

        applicationContext.contentResolver
            .query(collection, projection, selection, args, order)
            ?.use { cursor ->
                val nameColumn =
                    cursor.getColumnIndex(MediaStore.Files.FileColumns.DISPLAY_NAME)
                val sizeColumn =
                    cursor.getColumnIndex(MediaStore.Files.FileColumns.SIZE)
                while (cursor.moveToNext()) {
                    count++
                    if (sizeColumn >= 0) totalBytes += cursor.getLong(sizeColumn)
                    if (newest == null && nameColumn >= 0) {
                        newest = cursor.getString(nameColumn)
                    }
                }
            }

        return NewMedia(count, totalBytes, newest)
    }

    private fun notifyNewMedia(found: NewMedia) {
        val manager = NotificationManagerCompat.from(applicationContext)

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            manager.createNotificationChannel(
                NotificationChannel(
                    CHANNEL_ID, CHANNEL_NAME, NotificationManager.IMPORTANCE_DEFAULT
                ).apply { description = CHANNEL_DESC }
            )
        }

        val size = formatBytes(found.totalBytes)
        val title = if (found.count == 1) {
            "New media added"
        } else {
            "${found.count} new media files"
        }
        val body = if (found.count == 1 && found.newest != null) {
            "${found.newest} added, using $size. Scan to see what you can free up."
        } else {
            "$size of new photos, video or music. Scan to see what you can free up."
        }

        val notification = NotificationCompat.Builder(applicationContext, CHANNEL_ID)
            .setSmallIcon(android.R.drawable.stat_sys_download_done)
            .setContentTitle(title)
            .setContentText(body)
            .setStyle(NotificationCompat.BigTextStyle().bigText(body))
            .setPriority(NotificationCompat.PRIORITY_DEFAULT)
            .setAutoCancel(true)
            .build()

        try {
            manager.notify(NOTIFICATION_ID, notification)
        } catch (e: SecurityException) {
            // POST_NOTIFICATIONS not granted on Android 13+; nothing to do.
        }
    }

    private fun formatBytes(bytes: Long): String = when {
        bytes < 1024 -> "$bytes B"
        bytes < 1024 * 1024 ->
            String.format(Locale.US, "%.1f KB", bytes / 1024.0)
        bytes < 1024L * 1024 * 1024 ->
            String.format(Locale.US, "%.1f MB", bytes / (1024.0 * 1024))
        else ->
            String.format(Locale.US, "%.2f GB", bytes / (1024.0 * 1024 * 1024))
    }
}
