package com.example.storage_optimizer_new

import android.os.Build
import android.os.Environment
import android.os.StatFs
import com.chaquo.python.Python
import com.chaquo.python.android.AndroidPlatform
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val channel = "com.example.storage_optimizer/storage"

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

                    // ── AI: Storage growth forecasting (scikit-learn) ────────
                    "runForecast" -> {
                        try {
                            val timestamps = toDoubleList(call.argument("timestamps"))
                            val usedBytes  = toDoubleList(call.argument("usedBytes"))
                            val totalBytes = (call.argument<Number>("totalBytes"))
                                ?.toDouble() ?: 0.0

                            val py     = Python.getInstance()
                            val module = py.getModule("storage_predictor")
                            val res    = module.callAttr("forecast", timestamps, usedBytes, totalBytes)

                            result.success(
                                mapOf(
                                    "daysUntilFull"    to (res["days_until_full"]?.toInt()    ?: -1),
                                    "dailyGrowthBytes" to (res["daily_growth_bytes"]?.toDouble() ?: 0.0),
                                    "mae"              to (res["mae"]?.toDouble()              ?: 0.0),
                                    "rmse"             to (res["rmse"]?.toDouble()             ?: 0.0),
                                    "r2"               to (res["r2"]?.toDouble()               ?: 0.0),
                                )
                            )
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
                            val res    = module.callAttr("score_files", days, counts, sizes)

                            val scores    = res["scores"]?.asList()
                                ?.map { it.toDouble() } ?: emptyList()
                            val recommended = res["recommended"]?.asList()
                                ?.map { it.toBoolean() } ?: emptyList()
                            val reasons   = res["reasons"]?.asList()
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

    // ── Type-safe list converters ────────────────────────────────────────────

    private fun toDoubleList(raw: List<*>?): List<Double> =
        raw?.map { (it as? Number)?.toDouble() ?: 0.0 } ?: emptyList()

    private fun toIntList(raw: List<*>?): List<Int> =
        raw?.map { (it as? Number)?.toInt() ?: 0 } ?: emptyList()

    private fun toLongList(raw: List<*>?): List<Long> =
        raw?.map { (it as? Number)?.toLong() ?: 0L } ?: emptyList()
}
