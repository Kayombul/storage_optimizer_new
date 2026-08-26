import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:storage_optimizer_new/models/storage_snapshot.dart';
import 'package:storage_optimizer_new/services/prediction_service.dart';

const _channel = MethodChannel('com.example.storage_optimizer/storage');
const _totalBytes = 100 * 1024 * 1024 * 1024;

/// Snapshots [count] apart by [step], growing by [growthPerStep] each time.
List<StorageSnapshot> _series({
  required int count,
  required Duration step,
  required int growthPerStep,
  int startUsed = 90 * 1024 * 1024 * 1024,
}) {
  final start = DateTime(2026, 8, 26, 9);
  return List.generate(count, (i) {
    final used = startUsed + growthPerStep * i;
    return StorageSnapshot(
      timestamp: start.add(step * i),
      totalBytes: _totalBytes,
      usedBytes: used,
      freeBytes: _totalBytes - used,
    );
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Force the pure-Dart path: there is no Python bridge under test.
  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, (call) async => null);
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, null);
  });

  test('forecasts from readings taken inside a single hour', () async {
    // Regression test. The time series used Duration.inHours, which truncates
    // toward zero, so readings less than an hour apart all landed on x = 0 and
    // the regression denominator collapsed — the forecast reported "no data"
    // forever no matter how many readings had been taken.
    final snapshots = _series(
      count: 6,
      step: const Duration(minutes: 12),
      growthPerStep: 100 * 1024 * 1024,
    );

    final result =
        await PredictionService.instance.forecast(snapshots, _totalBytes);

    expect(result.hasEnoughData, isTrue);
    expect(result.dailyGrowthBytes, greaterThan(0));
    expect(result.daysUntilFull, greaterThan(0));
  });

  test('growth rate is per day, not per sample', () async {
    // 100 MiB every 12 minutes is 120 intervals a day: 12000 MiB per day.
    final snapshots = _series(
      count: 6,
      step: const Duration(minutes: 12),
      growthPerStep: 100 * 1024 * 1024,
    );

    final result =
        await PredictionService.instance.forecast(snapshots, _totalBytes);

    const expected = 12000 * 1024 * 1024.0;
    expect(result.dailyGrowthBytes, closeTo(expected, expected * 0.01));
  });

  test('reports progress instead of a trend from too little history', () async {
    final snapshots = _series(
      count: 3,
      step: const Duration(minutes: 2),
      growthPerStep: 50 * 1024 * 1024,
    );

    final result =
        await PredictionService.instance.forecast(snapshots, _totalBytes);

    expect(result.hasEnoughData, isFalse);
    expect(result.sampleCount, 3);
    expect(result.collectingHint, contains('3 readings'));
  });

  test('flat usage is reported as not growing, not as missing data', () async {
    final snapshots = _series(
      count: 5,
      step: const Duration(minutes: 15),
      growthPerStep: 0,
    );

    final result =
        await PredictionService.instance.forecast(snapshots, _totalBytes);

    expect(result.hasEnoughData, isTrue);
    expect(result.daysUntilFull, -1);
    expect(result.daysLabel, 'Storage not growing');
  });
}
