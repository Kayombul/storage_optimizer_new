import '../models/file_metadata.dart';
import '../models/forecast_result.dart';

class OptimizationService {
  static final OptimizationService instance = OptimizationService._();
  OptimizationService._();

  /// Returns a ranked deletion plan.
  ///
  /// Files are sorted by valueScore ASC (lowest value = best candidate).
  /// If storage is critically low, enough files are selected to free ≥10% of
  /// total capacity; otherwise the bottom 30% by value are returned.
  List<FileMetadata> generatePlan({
    required List<FileMetadata> files,
    required ForecastResult forecast,
    required int freeBytes,
    required int totalBytes,
  }) {
    final sorted = [...files]
      ..sort((a, b) => a.valueScore.compareTo(b.valueScore));

    final targetFree = (totalBytes * 0.10).ceil();

    if (freeBytes >= targetFree) {
      final count = (sorted.length * 0.30).ceil();
      return sorted.take(count).toList();
    }

    // Storage critically low — greedily pick until target is met
    int accumulated = 0;
    final plan = <FileMetadata>[];
    for (final f in sorted) {
      plan.add(f);
      accumulated += f.sizeBytes;
      if (accumulated >= targetFree - freeBytes) break;
    }
    return plan;
  }

  int totalSizeBytes(List<FileMetadata> files) =>
      files.fold(0, (sum, f) => sum + f.sizeBytes);
}
