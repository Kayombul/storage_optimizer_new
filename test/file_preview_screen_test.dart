import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:storage_optimizer_new/models/file_metadata.dart';
import 'package:storage_optimizer_new/screens/file_preview_screen.dart';

FileMetadata _file(String name, {String type = 'video'}) => FileMetadata(
      path: '/storage/emulated/0/Movies/$name',
      name: name,
      sizeBytes: 12 * 1024 * 1024,
      fileType: type,
      createdAt: DateTime(2025, 1, 1),
      lastAccessedAt: DateTime(2025, 6, 1),
      accessCount: 2,
      valueScore: 0.21,
      isRecommendedForDeletion: true,
      scoreReason: 'Not opened in 6 months',
    );

Widget _host(Widget child) => MaterialApp(home: child);

const _channel = MethodChannel('com.example.storage_optimizer/storage');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // The preview asks the platform to render video frames, album art and PDF
  // pages. There is no platform under test, so answer for it: null thumbnail
  // and no metadata exercises the fallback path these tests care about.
  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, (call) async {
      switch (call.method) {
        case 'getThumbnail':
          return null;
        case 'getMediaInfo':
          return <String, String>{};
      }
      return null;
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, null);
  });
  testWidgets('shows the file, its position in the list and why it was flagged',
      (tester) async {
    await tester.pumpWidget(_host(FilePreviewScreen(
      files: [_file('a.mp4'), _file('b.mp4')],
      onDelete: (_) async => true,
      onKeep: (_) {},
    )));

    expect(find.text('a.mp4'), findsOneWidget);
    expect(find.text('1 / 2'), findsOneWidget);
    expect(find.text('Not opened in 6 months'), findsOneWidget);
    expect(find.text('Recommended'), findsOneWidget);
  });

  testWidgets('swiping moves to the next recommended file', (tester) async {
    await tester.pumpWidget(_host(FilePreviewScreen(
      files: [_file('a.mp4'), _file('b.mp4')],
      onDelete: (_) async => true,
      onKeep: (_) {},
    )));

    await tester.fling(find.byType(PageView), const Offset(-400, 0), 1000);
    await tester.pumpAndSettle();

    expect(find.text('b.mp4'), findsOneWidget);
    expect(find.text('2 / 2'), findsOneWidget);
  });

  testWidgets('keeping a file drops its page', (tester) async {
    final kept = <String>[];
    await tester.pumpWidget(_host(FilePreviewScreen(
      files: [_file('a.mp4'), _file('b.mp4')],
      onDelete: (_) async => true,
      onKeep: (f) => kept.add(f.name),
    )));

    await tester.tap(find.widgetWithText(OutlinedButton, 'Keep'));
    await tester.pumpAndSettle();

    expect(kept, ['a.mp4']);
    expect(find.text('b.mp4'), findsOneWidget);
    expect(find.text('1 / 1'), findsOneWidget);
  });

  testWidgets('a refused deletion keeps the page in place', (tester) async {
    await tester.pumpWidget(_host(FilePreviewScreen(
      files: [_file('a.mp4'), _file('b.mp4')],
      onDelete: (_) async => false,
      onKeep: (_) {},
    )));

    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();

    expect(find.text('a.mp4'), findsOneWidget);
    expect(find.text('1 / 2'), findsOneWidget);
  });

  testWidgets('types without a renderer explain that instead', (tester) async {
    await tester.pumpWidget(_host(FilePreviewScreen(
      files: [_file('song.mp3', type: 'audio')],
      onDelete: (_) async => true,
      onKeep: (_) {},
    )));
    await tester.pumpAndSettle();

    expect(find.textContaining('no embedded artwork'), findsOneWidget);
  });
}
