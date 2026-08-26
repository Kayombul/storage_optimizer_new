import 'package:flutter_test/flutter_test.dart';
import 'package:storage_optimizer_new/models/forecast_result.dart';
import 'package:storage_optimizer_new/utils/duration_text.dart';

void main() {
  test('one day is singular', () {
    expect(dayCount(1), '1 day');
  });

  test('every other count is plural', () {
    expect(dayCount(0), '0 days');
    expect(dayCount(2), '2 days');
    expect(dayCount(28), '28 days');
  });

  test('forecast headline pluralises', () {
    ForecastResult at(int days) => ForecastResult(
          daysUntilFull: days,
          dailyGrowthBytes: 1024 * 1024 * 1024,
          mae: 0,
          rmse: 0,
        );

    // "1 days until full" was shown on the dashboard, in the alert threshold
    // slider and its description, and in the notification body.
    expect(at(1).daysLabel, '1 day');
    expect(at(2).daysLabel, '2 days');
    expect(at(0).daysLabel, 'Full now!');
    expect(at(-1).daysLabel, 'Storage not growing');
  });
}
