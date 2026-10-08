import 'package:english_learning_app/pages/ocr/ocr_status_view.dart';
import 'package:english_learning_app/services/api_response.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/pump_app.dart';

class _Calls {
  int retry = 0;
  int repick = 0;
}

Future<_Calls> _pump(
  WidgetTester tester, {
  bool isRecognizing = false,
  String? error,
  FlowErrorKind? kind,
}) async {
  final calls = _Calls();
  await pumpLocalized(
    tester,
    OcrStatusView(
      isRecognizing: isRecognizing,
      error: error,
      errorKind: kind,
      onRetry: () => calls.retry++,
      onRepick: () => calls.repick++,
    ),
    surfaceSize: const Size(400, 1200),
  );
  return calls;
}

void main() {
  testWidgets('识别中：标题、说明与不确定进度条，没有按钮和百分比', (tester) async {
    await _pump(tester, isRecognizing: true);
    expect(find.text('正在识别照片中的单词…'), findsOneWidget);
    expect(find.text('通常需要几秒钟'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    expect(find.textContaining('%'), findsNothing);
    expect(find.text('重试'), findsNothing);
  });

  testWidgets('识别失败（可重试，如超时）：原因、提示卡、重试与重新选图', (tester) async {
    final calls = await _pump(
      tester,
      error: '请求超时，请重试。',
      kind: FlowErrorKind.retryable,
    );
    expect(find.text('识别失败'), findsOneWidget);
    expect(find.text('请求超时，请重试。'), findsOneWidget);
    expect(find.text('拍得清晰、光线充足时更容易识别。'), findsOneWidget);

    await tester.tap(find.text('重试'));
    await tester.tap(find.text('重新选图'));
    expect((calls.retry, calls.repick), (1, 1));
  });

  testWidgets('识别失败（不可重试，如 429、不是图片）：只有重新选图', (tester) async {
    final calls = await _pump(
      tester,
      error: '识别次数已用完（每天 60 次），请约 3 小时后再试',
      kind: FlowErrorKind.notRetryable,
    );
    expect(find.text('识别失败'), findsOneWidget);
    expect(find.textContaining('识别次数已用完'), findsOneWidget);
    expect(find.text('重试'), findsNothing);
    await tester.tap(find.text('重新选图'));
    expect(calls.repick, 1);
  });

  testWidgets('无法连接服务器：网络错误画面，带角标，重试与重新选图', (tester) async {
    final calls = await _pump(
      tester,
      error: '无法连接服务器，请检查网络。',
      kind: FlowErrorKind.network,
    );
    expect(find.text('无法连接服务器'), findsOneWidget);
    expect(find.text('请检查网络后重试。'), findsOneWidget);
    expect(find.byIcon(Icons.wifi_off), findsOneWidget);
    expect(find.text('识别失败'), findsNothing);

    await tester.tap(find.text('重试'));
    expect(calls.retry, 1);
  });

  testWidgets('没有失败也不在识别中：什么都不显示', (tester) async {
    await _pump(tester);
    expect(find.text('识别失败'), findsNothing);
    expect(find.byType(LinearProgressIndicator), findsNothing);
  });
}
