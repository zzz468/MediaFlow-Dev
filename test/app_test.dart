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
    expect(find.text('Parse link'), findsOneWidget);
    expect(find.text('解析状态：等待输入'), findsOneWidget);
  });

  testWidgets('shows simulated video information after parsing', (
    tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: MediaFlowApp()));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byType(TextField),
      'https://www.bilibili.com/video/BV1xx',
    );
    await tester.pumpAndSettle();
    expect(find.text('解析状态：等待解析'), findsOneWidget);

    await tester.tap(find.text('Parse link'));
    await tester.pumpAndSettle();

    expect(find.text('测试视频'), findsOneWidget);
    expect(find.text('作者：MediaFlow Demo'), findsOneWidget);
    expect(find.text('平台：Bilibili'), findsOneWidget);
    expect(find.text('解析状态：解析成功'), findsOneWidget);
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
