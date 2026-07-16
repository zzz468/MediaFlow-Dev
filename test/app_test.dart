import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mediaflow/app/mediaflow_app.dart';

void main() {
  testWidgets('shows the MediaFlow home workspace', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: MediaFlowApp()));
    await tester.pumpAndSettle();

    expect(find.text('MediaFlow'), findsOneWidget);
    expect(find.text('Video link'), findsOneWidget);
    expect(find.text('Inspect link'), findsOneWidget);
  });

  testWidgets('shows detected platform before media parsing', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: MediaFlowApp()));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byType(TextField),
      'https://www.bilibili.com/video/BV1xx',
    );
    await tester.pumpAndSettle();

    expect(find.text('平台：Bilibili'), findsOneWidget);
    expect(find.text('状态：等待解析'), findsOneWidget);
  });

  testWidgets('switches to settings and changes the theme', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: MediaFlowApp()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Settings').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Dark mode'));
    await tester.pumpAndSettle();

    expect(find.text('About MediaFlow'), findsOneWidget);
  });
}
