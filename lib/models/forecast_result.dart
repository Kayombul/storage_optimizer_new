import '../utils/duration_text.dart';

class ForecastResult {
  final int daysUntilFull;
  final double dailyGrowthBytes;
  final double mae;
  final double rmse;
  final bool hasEnoughData;

  final double r2;

  /// How much history the forecast was built from. Carried even when there is
  /// not enough of it yet, so the UI can show progress instead of an opaque
  /// "collecting data" with no end in sight.
  final int sampleCount;
  final double spanMinutes;
  final double requiredSpanMinutes;

  const ForecastResult({
    required this.daysUntilFull,
    required this.dailyGrowthBytes,
    required this.mae,
    required this.rmse,
    this.r2 = 0.0,
    this.hasEnoughData = true,
    this.sampleCount = 0,
    this.spanMinutes = 0,
    this.requiredSpanMinutes = 0,
  });

  factory ForecastResult.noData({
    int sampleCount = 0,
    double spanMinutes = 0,
    double requiredSpanMinutes = 0,
  }) =>
      ForecastResult(
        r2: 0.0,
        daysUntilFull: -1,
        dailyGrowthBytes: 0,
        mae: 0,
        rmse: 0,
        hasEnoughData: false,
        sampleCount: sampleCount,
        spanMinutes: spanMinutes,
        requiredSpanMinutes: requiredSpanMinutes,
      );

  /// Explains what the forecast is still waiting for.
  String get collectingHint {
    if (requiredSpanMinutes <= 0) return 'Waiting for the first readings';
    if (spanMinutes < requiredSpanMinutes) {
      final remaining = (requiredSpanMinutes - spanMinutes).ceil();
      return '$sampleCount readings over ${spanMinutes.floor()} min - '
          'about $remaining min more needed';
    }
    return '$sampleCount readings so far';
  }

  String get daysLabel {
    if (!hasEnoughData) return 'Collecting data…';
    if (daysUntilFull < 0) return 'Storage not growing';
    if (daysUntilFull == 0) return 'Full now!';
    return dayCount(daysUntilFull);
  }

  String get growthLabel {
    if (dailyGrowthBytes <= 0) return '0 MB/day';
    const mb = 1024 * 1024;
    const gb = 1024 * 1024 * 1024;
    if (dailyGrowthBytes < mb) {
      return '${(dailyGrowthBytes / 1024).toStringAsFixed(1)} KB/day';
    }
    if (dailyGrowthBytes < gb) {
      return '${(dailyGrowthBytes / mb).toStringAsFixed(1)} MB/day';
    }
    return '${(dailyGrowthBytes / gb).toStringAsFixed(2)} GB/day';
  }

  bool get isCritical => hasEnoughData && daysUntilFull >= 0 && daysUntilFull <= 7;
  bool get isWarning =>
      hasEnoughData && daysUntilFull >= 0 && daysUntilFull <= 30;
}
