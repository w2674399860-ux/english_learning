import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:english_learning_app/providers/difficulty.dart';
import 'package:english_learning_app/widgets/difficulty_selector.dart';

Future<void> _pump(
  WidgetTester tester, {
  required Difficulty value,
  ValueChanged<Difficulty>? onChanged,
}) {
  return tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(colorSchemeSeed: Colors.blue, useMaterial3: true),
      home: Scaffold(
        body: DifficultySelector(value: value, onChanged: onChanged),
      ),
    ),
  );
}

ChoiceChip _chip(WidgetTester tester, String label) => tester.widget<ChoiceChip>(
      find.ancestor(of: find.text(label), matching: find.byType(ChoiceChip)),
    );

void main() {
  test('默认难度为 intermediate，API 取值与后端一致', () {
    expect(Difficulty.defaultValue, Difficulty.intermediate);
    expect(Difficulty.values.map((d) => d.apiValue),
        ['beginner', 'intermediate', 'advanced']);
  });

  testWidgets('显示三个选项，只有当前值被选中', (tester) async {
    await _pump(tester, value: Difficulty.intermediate, onChanged: (_) {});

    expect(find.byType(ChoiceChip), findsNWidgets(3));
    expect(_chip(tester, 'Beginner').selected, isFalse);
    expect(_chip(tester, 'Intermediate').selected, isTrue);
    expect(_chip(tester, 'Advanced').selected, isFalse);
  });

  testWidgets('点击其他选项回调所选难度', (tester) async {
    Difficulty? picked;
    await _pump(tester, value: Difficulty.intermediate, onChanged: (d) => picked = d);

    await tester.tap(find.text('Advanced'));
    expect(picked, Difficulty.advanced);

    await tester.tap(find.text('Beginner'));
    expect(picked, Difficulty.beginner);
  });

  testWidgets('onChanged 为 null 时三个选项都不可点', (tester) async {
    await _pump(tester, value: Difficulty.beginner);

    for (final label in ['Beginner', 'Intermediate', 'Advanced']) {
      expect(_chip(tester, label).onSelected, isNull, reason: label);
    }
  });
}
