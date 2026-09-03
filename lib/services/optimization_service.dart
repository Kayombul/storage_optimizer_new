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

    // Storage critically low — greedily pick until target is met.
    // Capped at half the catalogue: if the scanned files cannot cover the
    // shortfall on their own, recommending literally everything is useless
    // advice, so the plan degrades to the lowest-value half instead.
    final maxCount = (sorted.length * 0.50).ceil();
    int accumulated = 0;
    final plan = <FileMetadata>[];
    for (final f in sorted) {
      plan.add(f);
      accumulated += f.sizeBytes;
      if (accumulated >= targetFree - freeBytes) break;
      if (plan.length >= maxCount) break;
    }
    return plan;
  }

  /// Returns [files] with `isRecommendedForDeletion` set to true for exactly
  /// the members of the ranked deletion plan, and false for everything else.
  ///
  /// Selection is rank-based rather than an absolute score cutoff: the value
  /// score decides the *ordering*, the plan decides *how many* to flag. This
  /// keeps the recommendation list populated whenever files exist, instead of
  /// depending on scores falling below a fixed threshold.
  List<FileMetadata> applyPlan({
    required List<FileMetadata> files,
    required ForecastResult forecast,
    required int freeBytes,
    required int totalBytes,
  }) {
    if (files.isEmpty) return files;

    final plan = generatePlan(
      files: files,
      forecast: forecast,
      freeBytes: freeBytes,
      totalBytes: totalBytes,
    );
    final selected = plan.map((f) => f.path).toSet();

    return files
        .map((f) => f.copyWith(
            isRecommendedForDeletion: selected.contains(f.path)))
        .toList();
  }

  int totalSizeBytes(List<FileMetadata> files) =>
      files.fold(0, (sum, f) => sum + f.sizeBytes);
}
