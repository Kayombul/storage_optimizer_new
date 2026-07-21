import 'package:flutter_test/flutter_test.dart';
import 'package:storage_optimizer_new/main.dart';

void main() {
  testWidgets('App launches smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const StorageOptimizerApp());
    expect(find.byType(StorageOptimizerApp), findsOneWidget);
  });
}
