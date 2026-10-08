import 'package:flutter_test/flutter_test.dart';

import 'package:english_learning_app/widgets/degraded_banner.dart';

import '../helpers/pump_app.dart';

void main() {
  testWidgets('OCR 不可用：提示示例词，并显示 reason', (tester) async {
    await pumpLocalized(
      tester,
      const DegradedBanner(reason: 'ocr_unavailable'),
    );
    // 关键文案直接写中文，防止 ARB 被误改
    expect(find.text('识别服务不可用。以下是示例单词，不是从你的照片中识别的。'), findsOneWidget);
    expect(find.text('原因：ocr_unavailable'), findsOneWidget);
  });

  testWidgets('OCR mock 模式', (tester) async {
    await pumpLocalized(tester, const DegradedBanner(reason: 'ocr_mock'));
    expect(find.text(testL10n.degradedOcrMock), findsOneWidget);
  });

  testWidgets('AI 未配置', (tester) async {
    await pumpLocalized(
      tester,
      const DegradedBanner(reason: 'ai_not_configured'),
    );
    expect(find.text(testL10n.degradedAiNotConfigured), findsOneWidget);
  });

  testWidgets('其他 AI reason 统一提示不可用', (tester) async {
    for (final reason in [
      'ai_unavailable',
      'ai_timeout',
      'ai_upstream_error',
      'ai_parse_failed',
    ]) {
      await pumpLocalized(tester, DegradedBanner(reason: reason));
      expect(
        find.text('AI 服务不可用。这是一篇示例短文，不是根据你的单词写的。'),
        findsOneWidget,
        reason: reason,
      );
      expect(find.text(testL10n.degradedReason(reason)), findsOneWidget);
    }
  });

  testWidgets('未知 reason 兜底', (tester) async {
    await pumpLocalized(tester, const DegradedBanner(reason: 'unknown'));
    expect(find.text(testL10n.degradedOther), findsOneWidget);
  });

  testWidgets('showReason 为 false 时不显示原因行', (tester) async {
    await pumpLocalized(
      tester,
      const DegradedBanner(reason: 'ai_unavailable', showReason: false),
    );
    expect(find.text(testL10n.degradedAi), findsOneWidget);
    expect(find.textContaining('原因：'), findsNothing);
  });
}
