import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:english_learning_app/providers/flow_phase.dart';
import 'package:english_learning_app/widgets/phase_indicator.dart';

import '../helpers/pump_app.dart';

const _recognizing = '正在识别照片中的单词…';
const _generating = '正在写短文和练习题…';

Future<void> _pump(
  WidgetTester tester,
  FlowPhase phase, {
  bool compact = false,
}) {
  return pumpLocalized(tester, PhaseIndicator(phase: phase, compact: compact));
}

void main() {
  testWidgets('识别阶段：吉祥物、标题、说明与不确定进度条，不显示百分比', (tester) async {
    await _pump(tester, FlowPhase.recognizing);
    expect(find.text(_recognizing), findsOneWidget);
    expect(find.text(testL10n.ocrRecognizingHint), findsOneWidget);
    expect(find.text(_generating), findsNothing);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    expect(find.textContaining('%'), findsNothing);
  });

  testWidgets('生成阶段显示生成文案', (tester) async {
    await _pump(tester, FlowPhase.generating);
    expect(find.text(_generating), findsOneWidget);
    expect(find.text(_recognizing), findsNothing);
  });

  testWidgets('空闲阶段不显示任何内容', (tester) async {
    await _pump(tester, FlowPhase.idle);
    expect(find.text(_recognizing), findsNothing);
    expect(find.text(_generating), findsNothing);
    expect(find.byType(LinearProgressIndicator), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('紧凑模式：小进度圈 + 同样的文案', (tester) async {
    await _pump(tester, FlowPhase.generating, compact: true);
    expect(find.text(_generating), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}
