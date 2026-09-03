import 'package:flutter_test/flutter_test.dart';
import 'package:storage_optimizer_new/models/file_metadata.dart';
import 'package:storage_optimizer_new/models/forecast_result.dart';
import 'package:storage_optimizer_new/services/optimization_service.dart';

/// Regression coverage for the "scan recommends nothing" defect.
///
/// The original selection rule flagged files whose composite value score fell
/// below an absolute 0.35 cutoff. Because every scanned file carries
/// accessCount == 1, the frequency term contributed a constant 0.30 to every
/// score, leaving 0.05 of headroom — so a single very large file on the device
/// pushed every other file's size_norm down and the recommendation list went
/// empty. Selection is now rank-based: the score orders the files, the plan
/// decides how many are flagged.

const _gb = 1024 * 1024 * 1024;

FileMetadata _file(String name, int sizeBytes, double score) {
  final now = DateTime(2026, 1, 1);
  return FileMetadata(
    path: '/storage/emulated/0/DCIM/$name',
    name: name,
    sizeBytes: sizeBytes,
    fileType: 'image',
    createdAt: now,
    lastAccessedAt: now,
    valueScore: score,
  );
}

/// Catalogue of [n] files with strictly increasing value scores, so the
/// expected selection order is unambiguous.
List<FileMetadata> _catalogue(int n, {int sizeBytes = 5 * 1024 * 1024}) {
  return List.generate(
    n,
    (i) => _file('f$i.jpg', sizeBytes, 0.30 + i * 0.001),
  );
}

int _flagged(List<FileMetadata> files) =>
    files.where((f) => f.isRecommendedForDeletion).length;

void main() {
  final svc = OptimizationService.instance;
  final forecast = ForecastResult.noData();

  List<FileMetadata> apply(
    List<FileMetadata> files, {
    required int freeBytes,
    int totalBytes = 128 * _gb,
  }) =>
      svc.applyPlan(
        files: files,
        forecast: forecast,
        freeBytes: freeBytes,
        totalBytes: totalBytes,
      );

  group('applyPlan — healthy storage', () {
    test('flags the bottom 30% by value score', () {
      final out = apply(_catalogue(100), freeBytes: 64 * _gb);
      expect(_flagged(out), 30);
    });

    test('flags the lowest-scoring files, not arbitrary ones', () {
      final out = apply(_catalogue(10), freeBytes: 64 * _gb);
      final picked = out
          .where((f) => f.isRecommendedForDeletion)
          .map((f) => f.name)
          .toSet();
      expect(picked, {'f0.jpg', 'f1.jpg', 'f2.jpg'});
    });

    test('never returns an empty list when files exist', () {
      for (final n in [1, 2, 3, 7, 50, 331]) {
        final out = apply(_catalogue(n), freeBytes: 64 * _gb);
        expect(_flagged(out), greaterThan(0),
            reason: 'catalogue of $n files produced no recommendations');
      }
    });

    test('a single file is still recommended', () {
      final out = apply(_catalogue(1), freeBytes: 64 * _gb);
      expect(_flagged(out), 1);
    });
  });

  group('applyPlan — critical storage', () {
    test('picks enough files to cover the shortfall', () {
      // Target is 10% of 128 GB = 12.8 GB; 1 GB free means ~11.8 GB to free.
      final files = _catalogue(40, sizeBytes: 2 * _gb);
      final out = apply(files, freeBytes: 1 * _gb);
      expect(_flagged(out), 6); // 6 x 2 GB = 12 GB >= 11.8 GB
    });

    test('caps at half the catalogue when the shortfall cannot be covered',
        () {
      // Small files that can never free 11.8 GB — must not flag everything.
      final files = _catalogue(100, sizeBytes: 1024 * 1024);
      final out = apply(files, freeBytes: 1 * _gb);
      expect(_flagged(out), 50);
      expect(_flagged(out), lessThan(files.length));
    });
  });

  group('applyPlan — edge cases', () {
    test('empty catalogue yields an empty result', () {
      expect(apply(const <FileMetadata>[], freeBytes: 64 * _gb), isEmpty);
    });

    test('clears stale flags on files not in the plan', () {
      final stale = _catalogue(10)
          .map((f) => f.copyWith(isRecommendedForDeletion: true))
          .toList();
      final out = apply(stale, freeBytes: 64 * _gb);
      expect(_flagged(out), 3);
    });

    test('preserves every input file and its identity', () {
      final input = _catalogue(20);
      final out = apply(input, freeBytes: 64 * _gb);
      expect(out.length, input.length);
      expect(out.map((f) => f.path).toSet(), input.map((f) => f.path).toSet());
    });
  });

  group('regression — the original failure mode', () {
    test('one huge file no longer suppresses all recommendations', () {
      // Under the old 0.35 threshold this catalogue produced 1 recommendation
      // out of 331. Rank-based selection is independent of the size spread.
      final files = [
        ..._catalogue(330),
        _file('backup.img', 30 * _gb, 0.301),
      ];
      final out = apply(files, freeBytes: 64 * _gb);
      expect(_flagged(out), 100);
    });
  });
}
