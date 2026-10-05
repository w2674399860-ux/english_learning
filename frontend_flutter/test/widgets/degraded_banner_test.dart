import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:english_learning_app/widgets/degraded_banner.dart';

Future<void> _pump(WidgetTester tester, String reason) {
  return tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(colorSchemeSeed: Colors.blue, useMaterial3: true),
      home: Scaffold(body: DegradedBanner(reason: reason)),
    ),
  );
}

void main() {
  testWidgets('OCR 不可用：提示示例词，并显示 reason', (tester) async {
    await _pump(tester, 'ocr_unavailable');
    expect(
      find.text('OCR service unavailable. '
          'These are sample words, not words from your photo.'),
      findsOneWidget,
    );
    expect(find.text('Reason: ocr_unavailable'), findsOneWidget);
  });

  testWidgets('OCR mock 模式', (tester) async {
    await _pump(tester, 'ocr_mock');
    expect(
      find.text('OCR is in mock mode. '
          'These are sample words, not words from your photo.'),
      findsOneWidget,
    );
  });

  testWidgets('AI 未配置', (tester) async {
    await _pump(tester, 'ai_not_configured');
    expect(
      find.text('AI service is not configured. '
          'This is a sample story, not one written from your words.'),
      findsOneWidget,
    );
  });

  testWidgets('其他 AI reason 统一提示不可用', (tester) async {
    for (final reason in [
      'ai_unavailable',
      'ai_timeout',
      'ai_upstream_error',
      'ai_parse_failed',
    ]) {
      await _pump(tester, reason);
      expect(
        find.text('AI service unavailable. '
            'This is a sample story, not one written from your words.'),
        findsOneWidget,
        reason: reason,
      );
      expect(find.text('Reason: $reason'), findsOneWidget);
    }
  });

  testWidgets('未知 reason 兜底', (tester) async {
    await _pump(tester, 'unknown');
    expect(
      find.text('Some results are sample data, not generated from your input.'),
      findsOneWidget,
    );
  });
}
