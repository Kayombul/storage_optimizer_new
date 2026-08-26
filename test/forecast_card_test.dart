import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:storage_optimizer_new/models/forecast_result.dart';
import 'package:storage_optimizer_new/widgets/forecast_card.dart';

Future<void> _pumpAt(
  WidgetTester tester,
  ForecastResult forecast,
  double width,
) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(width: width, child: ForecastCard(forecast: forecast)),
        ),
      ),
    ),
  );
}

void main() {
  // Every label the card can show, including the long phrases that are not a
  // headline number.
  final cases = <String, ForecastResult>{
    'collecting': ForecastResult.noData(
      sampleCount: 5,
      spanMinutes: 21,
      requiredSpanMinutes: 30,
    ),
    'not growing': const ForecastResult(
      daysUntilFull: -1,
      dailyGrowthBytes: 0,
      mae: 263.6 * 1024 * 1024,
      rmse: 330.7 * 1024 * 1024,
      r2: 0.548,
    ),
    'full now': const ForecastResult(
      daysUntilFull: 0,
      dailyGrowthBytes: 5 * 1024 * 1024 * 1024,
      mae: 0,
      rmse: 0,
    ),
    'days remaining': const ForecastResult(
      daysUntilFull: 28,
      dailyGrowthBytes: 290 * 1024 * 1024,
      mae: 0,
      rmse: 0,
    ),
  };

  // 320 dp is the narrowest phone width still worth supporting; the card sat
  // inside 16 dp page padding on a 360 dp screen when it overflowed by 20 px.
  for (final width in <double>[280, 320, 360]) {
    for (final entry in cases.entries) {
      testWidgets('${entry.key} label fits at ${width.toInt()} dp',
          (tester) async {
        await _pumpAt(tester, entry.value, width);
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('a long label wraps rather than clipping', (tester) async {
    await _pumpAt(tester, cases['not growing']!, 280);

    expect(find.text('Storage not growing'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
