import 'dart:math';
import 'package:flutter/services.dart';
import '../models/storage_snapshot.dart';
import '../models/forecast_result.dart';

/// Forecasts storage growth using scikit-learn LinearRegression running
/// on-device via Chaquopy (Python embedded in the APK).
///
/// Falls back to a pure-Dart linear regression if the Python bridge fails.
class PredictionService {
  static final PredictionService instance = PredictionService._();
  PredictionService._();

  static const _channel =
      MethodChannel('com.example.storage_optimizer/storage');
  static const int _minDataPoints = 3;

  /// Projecting "days until full" from a few minutes of history produces
  /// nonsense: a single download can imply hundreds of GB per day. Require a
  /// usable baseline before reporting a trend at all.
  static const double _minSpanMinutes = 30;

  /// Least-squares on near-flat data yields a slope of a few bytes per day
  /// rather than exactly zero, which divides into a horizon of billions of
  /// days. Anything under a megabyte a day is noise, not growth.
  static const double _minGrowthBytesPerDay = 1024 * 1024;

  /// Beyond this the answer is "not filling", not a number worth printing.
  static const int _maxForecastDays = 3650;

  /// Rejects horizons that are arithmetically valid but meaningless.
  static int _sanitiseHorizon(int days, double growthBytesPerDay) {
    if (growthBytesPerDay < _minGrowthBytesPerDay) return -1;
    if (days > _maxForecastDays) return -1;
    return days;
  }

  Future<ForecastResult> forecast(
      List<StorageSnapshot> snapshots, int totalBytes) async {
    final spanMinutes = snapshots.length < 2
        ? 0.0
        : snapshots.last.timestamp
                .difference(snapshots.first.timestamp)
                .inSeconds /
            60.0;

    if (snapshots.length < _minDataPoints || spanMinutes < _minSpanMinutes) {
      return ForecastResult.noData(
        sampleCount: snapshots.length,
        spanMinutes: spanMinutes,
        requiredSpanMinutes: _minSpanMinutes,
      );
    }

    // Build a day-index time series (day 0 = first snapshot).
    //
    // This must stay fractional. Using Duration.inHours here truncates toward
    // zero, so every snapshot inside the first hour collapses to x = 0, the
    // regression's denominator becomes 0, and the forecast reports "no data"
    // no matter how many readings have been taken.
    final base = snapshots.first.timestamp;
    final timestamps = snapshots
        .map((s) =>
            s.timestamp.difference(base).inMilliseconds /
            Duration.millisecondsPerDay)
        .toList();
    final usedBytes =
        snapshots.map((s) => s.usedBytes.toDouble()).toList();

    // ── Try Python (scikit-learn) first ────────────────────────────────────
    try {
      final raw = await _channel.invokeMethod<Map>('runForecast', {
        'timestamps': timestamps,
        'usedBytes': usedBytes,
        'totalBytes': totalBytes,
      });
      if (raw != null && !raw.containsKey('error')) {
        return ForecastResult(
          sampleCount: snapshots.length,
          spanMinutes: spanMinutes,
          requiredSpanMinutes: _minSpanMinutes,
          daysUntilFull: _sanitiseHorizon(
            (raw['daysUntilFull'] as num?)?.toInt() ?? -1,
            (raw['dailyGrowthBytes'] as num?)?.toDouble() ?? 0.0,
          ),
          dailyGrowthBytes:
              (raw['dailyGrowthBytes'] as num?)?.toDouble() ?? 0.0,
          mae: (raw['mae'] as num?)?.toDouble() ?? 0.0,
          rmse: (raw['rmse'] as num?)?.toDouble() ?? 0.0,
          r2: (raw['r2'] as num?)?.toDouble() ?? 0.0,
        );
      }
    } catch (_) {
      // Python bridge unavailable → fall through to Dart implementation
    }

    // ── Dart fallback: ordinary least-squares linear regression ────────────
    return _dartForecast(
      timestamps,
      usedBytes,
      totalBytes,
      sampleCount: snapshots.length,
      spanMinutes: spanMinutes,
    );
  }

  ForecastResult _dartForecast(
    List<double> xs,
    List<double> ys,
    int totalBytes, {
    int sampleCount = 0,
    double spanMinutes = 0,
  }) {
    final n = xs.length;
    double sumX = 0, sumY = 0, sumXY = 0, sumX2 = 0;
    for (int i = 0; i < n; i++) {
      sumX += xs[i];
      sumY += ys[i];
      sumXY += xs[i] * ys[i];
      sumX2 += xs[i] * xs[i];
    }
    final denom = n * sumX2 - sumX * sumX;
    if (denom == 0) {
      return ForecastResult.noData(
        sampleCount: sampleCount,
        spanMinutes: spanMinutes,
        requiredSpanMinutes: _minSpanMinutes,
      );
    }

    final slope = (n * sumXY - sumX * sumY) / denom;
    final intercept = (sumY - slope * sumX) / n;

    double maeSum = 0, rmseSum = 0;
    for (int i = 0; i < n; i++) {
      final err = (slope * xs[i] + intercept - ys[i]).abs();
      maeSum += err;
      rmseSum += err * err;
    }
    final mae = maeSum / n;
    final rmse = sqrt(rmseSum / n);

    int daysUntilFull = -1;
    if (slope >= _minGrowthBytesPerDay) {
      final remaining = totalBytes - ys.last;
      daysUntilFull = remaining <= 0
          ? 0
          : _sanitiseHorizon((remaining / slope).ceil(), slope);
    }

    return ForecastResult(
      daysUntilFull: daysUntilFull,
      dailyGrowthBytes: slope >= _minGrowthBytesPerDay ? slope : 0,
      mae: mae,
      rmse: rmse,
      r2: _rSquared(xs, ys, slope, intercept),
      sampleCount: sampleCount,
      spanMinutes: spanMinutes,
      requiredSpanMinutes: _minSpanMinutes,
    );
  }

  /// Coefficient of determination, so the Dart fallback reports the same fit
  /// quality metric the Python path does instead of a hard-coded zero.
  double _rSquared(
      List<double> xs, List<double> ys, double slope, double intercept) {
    final meanY = ys.reduce((a, b) => a + b) / ys.length;
    double ssRes = 0, ssTot = 0;
    for (int i = 0; i < xs.length; i++) {
      final predicted = slope * xs[i] + intercept;
      ssRes += (ys[i] - predicted) * (ys[i] - predicted);
      ssTot += (ys[i] - meanY) * (ys[i] - meanY);
    }
    if (ssTot == 0) return ssRes == 0 ? 1.0 : 0.0;
    return 1.0 - ssRes / ssTot;
  }
}
