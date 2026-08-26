import 'dart:math';
import 'package:flutter/services.dart';
import '../models/file_metadata.dart';
import '../utils/duration_text.dart';

/// Scores each file with a composite value metric using numpy running
/// on-device via Chaquopy (Python embedded in the APK).
///
/// Score = 0.40 * recency  +  0.30 * frequency  +  0.30 * (1 − size_norm)
///
/// Falls back to a pure-Dart implementation if the Python bridge fails.
class ValueScoringService {
  static final ValueScoringService instance = ValueScoringService._();
  ValueScoringService._();

  static const _channel =
      MethodChannel('com.example.storage_optimizer/storage');

  Future<List<FileMetadata>> scoreAll(List<FileMetadata> files) async {
    if (files.isEmpty) return files;

    final now = DateTime.now();
    final daysSince = files
        .map((f) => now.difference(f.lastAccessedAt).inDays.toDouble())
        .toList();
    final counts = files.map((f) => f.accessCount).toList();
    final sizes = files.map((f) => f.sizeBytes).toList();

    // ── Try Python (numpy) first ───────────────────────────────────────────
    try {
      final raw = await _channel.invokeMethod<Map>('scoreFiles', {
        'daysSinceAccess': daysSince,
        'accessCounts': counts,
        'sizeBytes': sizes,
      });
      if (raw != null) {
        final scores =
            (raw['scores'] as List?)?.map((e) => (e as num).toDouble()).toList()
                ?? [];
        final recommended =
            (raw['recommended'] as List?)?.map((e) => e as bool).toList()
                ?? [];
        final reasons =
            (raw['reasons'] as List?)?.map((e) => e.toString()).toList()
                ?? [];

        if (scores.length == files.length) {
          return List.generate(files.length, (i) {
            return files[i].copyWith(
              valueScore: scores[i],
              isRecommendedForDeletion:
                  i < recommended.length ? recommended[i] : scores[i] < 0.35,
              scoreReason: i < reasons.length ? reasons[i] : '',
            );
          });
        }
      }
    } catch (_) {
      // Python bridge unavailable → fall through to Dart implementation
    }

    // ── Dart fallback ──────────────────────────────────────────────────────
    return _dartScore(files, now);
  }

  List<FileMetadata> _dartScore(List<FileMetadata> files, DateTime now) {
    final maxSize =
        files.map((f) => f.sizeBytes).reduce(max).toDouble();
    final maxAccess =
        files.map((f) => f.accessCount).reduce(max).toDouble();

    return files.map((f) {
      final days =
          now.difference(f.lastAccessedAt).inDays.toDouble().clamp(0, 365);
      final recency = exp(-days / 30.0);
      final freq = maxAccess > 0
          ? (f.accessCount / maxAccess).clamp(0.0, 1.0)
          : 0.0;
      final logMax = maxSize > 1 ? log(maxSize) : 1.0;
      final logSize = f.sizeBytes > 1 ? log(f.sizeBytes.toDouble()) : 0.0;
      final sizeNorm = logMax > 0 ? (logSize / logMax).clamp(0.0, 1.0) : 0.0;
      final score = 0.4 * recency + 0.3 * freq + 0.3 * (1.0 - sizeNorm);
      final reason = _reason(recency, freq, sizeNorm, days.round());
      return f.copyWith(
        valueScore: score,
        isRecommendedForDeletion: score < 0.35,
        scoreReason: reason,
      );
    }).toList();
  }

  String _reason(double r, double f, double s, int days) {
    final parts = <String>[];
    if (r < 0.30) parts.add('not accessed in ${dayCount(days)}');
    if (f < 0.10) parts.add('rarely opened');
    if (s > 0.70) parts.add('large file');
    return parts.isEmpty ? 'low overall utility' : parts.join(', ');
  }
}
