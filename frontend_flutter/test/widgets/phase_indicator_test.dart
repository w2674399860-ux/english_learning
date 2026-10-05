import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:english_learning_app/providers/flow_phase.dart';
import 'package:english_learning_app/widgets/phase_indicator.dart';

const _recognizing = 'Recognizing words in your photo...';
const _generating = 'Writing your story and exercises...';

Future<void> _pump(WidgetTester tester, FlowPhase phase, {bool compact = false}) {
  return tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(colorSchemeSeed: Colors.blue, useMaterial3: true),
      home: Scaffold(body: PhaseIndicator(phase: phase, compact: compact)),
    ),
  );
}

void main() {
  testWidgets('识别阶段显示识别文案与进度圈', (tester) async {
    await _pump(tester, FlowPhase.recognizing);
    expect(find.text(_recognizing), findsOneWidget);
    expect(find.text(_generating), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('生成阶段显示生成文案与进度圈', (tester) async {
    await _pump(tester, FlowPhase.generating);
    expect(find.text(_generating), findsOneWidget);
    expect(find.text(_recognizing), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('空闲阶段不显示任何内容', (tester) async {
    await _pump(tester, FlowPhase.idle);
    expect(find.text(_recognizing), findsNothing);
    expect(find.text(_generating), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('紧凑模式文案与默认模式一致', (tester) async {
    await _pump(tester, FlowPhase.generating, compact: true);
    expect(find.text(_generating), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}
