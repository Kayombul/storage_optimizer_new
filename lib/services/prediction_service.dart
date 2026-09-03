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

  /// Longest horizon worth reporting (10 years). Guards against a near-zero
  /// slope on a flat series producing an astronomical day count.
  static const int _maxHorizonDays = 3650;

  Future<ForecastResult> forecast(
      List<StorageSnapshot> snapshots, int totalBytes) async {
    if (snapshots.length < _minDataPoints) return ForecastResult.noData();

    // Build day-index time series (day 0 = first snapshot)
    final base = snapshots.first.timestamp;
    final timestamps = snapshots
        .map((s) => s.timestamp.difference(base).inHours / 24.0)
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
          daysUntilFull: (raw['daysUntilFull'] as num?)?.toInt() ?? -1,
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
    return _dartForecast(timestamps, usedBytes, totalBytes);
  }

  ForecastResult _dartForecast(
      List<double> xs, List<double> ys, int totalBytes) {
    final n = xs.length;
    double sumX = 0, sumY = 0, sumXY = 0, sumX2 = 0;
    for (int i = 0; i < n; i++) {
      sumX += xs[i];
      sumY += ys[i];
      sumXY += xs[i] * ys[i];
      sumX2 += xs[i] * xs[i];
    }
    final denom = n * sumX2 - sumX * sumX;
    if (denom == 0) return ForecastResult.noData();

    final slope = (n * sumXY - sumX * sumY) / denom;
    final intercept = (sumY - slope * sumX) / n;

    double maeSum = 0, rmseSum = 0, ssRes = 0;
    for (int i = 0; i < n; i++) {
      final err = (slope * xs[i] + intercept - ys[i]).abs();
      maeSum += err;
      rmseSum += err * err;
      ssRes += err * err;
    }
    final mae = maeSum / n;
    final rmse = sqrt(rmseSum / n);

    // Coefficient of determination, so the fallback reports a real fit
    // quality instead of a hardcoded zero.
    final meanY = sumY / n;
    double ssTot = 0;
    for (int i = 0; i < n; i++) {
      ssTot += (ys[i] - meanY) * (ys[i] - meanY);
    }
    final r2 = ssTot == 0 ? (ssRes == 0 ? 1.0 : 0.0) : 1.0 - ssRes / ssTot;

    int daysUntilFull = -1;
    if (slope > 0) {
      final remaining = totalBytes - ys.last;
      if (remaining <= 0) {
        daysUntilFull = 0;
      } else {
        final horizon = remaining / slope;
        if (horizon.isFinite && horizon <= _maxHorizonDays) {
          daysUntilFull = horizon.ceil();
        }
      }
    }

    return ForecastResult(
      daysUntilFull: daysUntilFull,
      dailyGrowthBytes: slope > 0 ? slope : 0,
      mae: mae,
      rmse: rmse,
      r2: r2,
    );
  }
}
