import 'package:english_learning_app/pages/words/confirm_action_bar.dart';
import 'package:english_learning_app/providers/difficulty.dart';
import 'package:english_learning_app/services/api_response.dart';
import 'package:english_learning_app/widgets/ink_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/pump_app.dart';

class _Calls {
  int add = 0;
  int generate = 0;
  int retry = 0;
  Difficulty? difficulty;
}

Future<_Calls> _pump(
  WidgetTester tester, {
  bool isGenerating = false,
  bool canGenerate = true,
  bool hasResult = false,
  String? error,
  FlowErrorKind? errorKind,
}) async {
  final calls = _Calls();
  final controller = TextEditingController();
  addTearDown(controller.dispose);
  await pumpLocalized(
    tester,
    Align(
      alignment: Alignment.bottomCenter,
      child: ConfirmActionBar(
        addController: controller,
        onAdd: () => calls.add++,
        difficulty: Difficulty.intermediate,
        onDifficultyChanged: (d) => calls.difficulty = d,
        isGenerating: isGenerating,
        canGenerate: canGenerate,
        hasResult: hasResult,
        onGenerate: () => calls.generate++,
        onRetry: () => calls.retry++,
        error: error,
        errorKind: errorKind,
      ),
    ),
    surfaceSize: const Size(360, 800),
  );
  return calls;
}

InkButton _generateButton(WidgetTester tester) =>
    tester.widget<InkButton>(find.byType(InkButton).last);

void main() {
  testWidgets('默认：添加、难度、生成都可用', (tester) async {
    final calls = await _pump(tester);
    expect(find.text('生成'), findsOneWidget);
    await tester.tap(find.text('生成'));
    await tester.tap(find.text('添加'));
    await tester.tap(find.text('高级'));
    expect(calls.generate, 1);
    expect(calls.add, 1);
    expect(calls.difficulty, Difficulty.advanced);
    expect(tester.takeException(), isNull);
  });

  testWidgets('已生成过：按钮显示"重新生成"', (tester) async {
    await _pump(tester, hasResult: true);
    expect(find.text('重新生成'), findsOneWidget);
  });

  testWidgets('不能生成（没选或超过上限）：生成按钮禁用', (tester) async {
    final calls = await _pump(tester, canGenerate: false);
    expect(_generateButton(tester).onPressed, isNull);
    await tester.tap(find.text('生成'));
    expect(calls.generate, 0);
  });

  testWidgets('生成中：按钮显示进度与文案；添加、难度禁用', (tester) async {
    final calls = await _pump(tester, isGenerating: true);
    expect(find.text('正在写短文和练习题…'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(tester.widget<TextField>(find.byType(TextField)).enabled, isFalse);

    await tester.tap(find.text('添加'));
    await tester.tap(find.text('高级'));
    await tester.tap(find.text('正在写短文和练习题…'));
    expect(calls.add, 0);
    expect(calls.difficulty, isNull);
    expect(calls.generate, 0);
  });

  testWidgets('生成失败（可重试）：错误条带"重试"', (tester) async {
    final calls = await _pump(
      tester,
      error: '生成失败：生成超时，请重试',
      errorKind: FlowErrorKind.retryable,
    );
    expect(find.text('生成失败：生成超时，请重试'), findsOneWidget);
    await tester.tap(find.text('重试'));
    expect(calls.retry, 1);
  });

  testWidgets('生成失败（网络）：同样带"重试"', (tester) async {
    await _pump(
      tester,
      error: '生成失败：无法连接服务器，请检查网络。',
      errorKind: FlowErrorKind.network,
    );
    expect(find.text('重试'), findsOneWidget);
  });

  testWidgets('生成次数用完（429）：错误条不带"重试"', (tester) async {
    await _pump(
      tester,
      error: '生成失败：生成次数已用完（每天 30 次），请约 3 小时后再试',
      errorKind: FlowErrorKind.notRetryable,
    );
    expect(find.textContaining('生成次数已用完'), findsOneWidget);
    expect(find.text('重试'), findsNothing);
  });
}
