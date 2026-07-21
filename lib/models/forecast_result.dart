class ForecastResult {
  final int daysUntilFull;
  final double dailyGrowthBytes;
  final double mae;
  final double rmse;
  final bool hasEnoughData;

  final double r2;

  const ForecastResult({
    required this.daysUntilFull,
    required this.dailyGrowthBytes,
    required this.mae,
    required this.rmse,
    this.r2 = 0.0,
    this.hasEnoughData = true,
  });

  factory ForecastResult.noData() => const ForecastResult(
        r2: 0.0,
        daysUntilFull: -1,
        dailyGrowthBytes: 0,
        mae: 0,
        rmse: 0,
        hasEnoughData: false,
      );

  String get daysLabel {
    if (!hasEnoughData) return 'Collecting data…';
    if (daysUntilFull < 0) return 'Storage not growing';
    if (daysUntilFull == 0) return 'Full now!';
    return '$daysUntilFull days';
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
