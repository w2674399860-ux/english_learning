import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:english_learning_app/providers/difficulty.dart';
import 'package:english_learning_app/widgets/difficulty_selector.dart';

import '../helpers/pump_app.dart';

Future<void> _pump(
  WidgetTester tester, {
  required Difficulty value,
  ValueChanged<Difficulty>? onChanged,
}) {
  return pumpLocalized(
    tester,
    DifficultySelector(value: value, onChanged: onChanged),
  );
}

bool _isSelected(WidgetTester tester, String label) {
  return isSemantics(
    isSelected: true,
  ).matches(tester.getSemantics(find.text(label)), {});
}

void main() {
  test('默认难度为 intermediate，API 取值与后端一致', () {
    expect(Difficulty.defaultValue, Difficulty.intermediate);
    expect(Difficulty.values.map((d) => d.apiValue), [
      'beginner',
      'intermediate',
      'advanced',
    ]);
  });

  testWidgets('显示标签与三个中文选项，只有当前值被选中', (tester) async {
    await _pump(tester, value: Difficulty.intermediate, onChanged: (_) {});
    expect(find.text('短文难度'), findsOneWidget);
    for (final label in ['初级', '中级', '高级']) {
      expect(find.text(label), findsOneWidget);
    }
    expect(_isSelected(tester, '初级'), isFalse);
    expect(_isSelected(tester, '中级'), isTrue);
    expect(_isSelected(tester, '高级'), isFalse);
  });

  testWidgets('点击其他选项回调所选难度', (tester) async {
    Difficulty? picked;
    await _pump(
      tester,
      value: Difficulty.intermediate,
      onChanged: (d) => picked = d,
    );

    await tester.tap(find.text('高级'));
    expect(picked, Difficulty.advanced);

    await tester.tap(find.text('初级'));
    expect(picked, Difficulty.beginner);
  });

  testWidgets('onChanged 为 null 时点击无效', (tester) async {
    await _pump(tester, value: Difficulty.beginner);
    // 没有回调可触发；确认点击不会抛异常，且选中项不变
    await tester.tap(find.text('高级'));
    await tester.pump();
    expect(_isSelected(tester, '初级'), isTrue);
    expect(_isSelected(tester, '高级'), isFalse);
  });
}
