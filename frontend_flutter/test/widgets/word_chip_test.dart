import 'package:english_learning_app/widgets/word_chip.dart';
import 'package:english_learning_app/widgets/word_tag.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/pump_app.dart';

Future<void> _pumpChip(
  WidgetTester tester, {
  bool selected = true,
  bool enabled = true,
  VoidCallback? onToggle,
  VoidCallback? onDelete,
}) {
  return pumpLocalized(
    tester,
    Center(
      child: WordChip(
        word: 'harvest',
        selected: selected,
        enabled: enabled,
        onToggle: onToggle ?? () {},
        onDelete: onDelete ?? () {},
      ),
    ),
  );
}

void main() {
  group('WordChip', () {
    testWidgets('点按单词切换，点 × 删除，两者互不触发', (tester) async {
      var toggles = 0;
      var deletes = 0;
      await _pumpChip(
        tester,
        onToggle: () => toggles++,
        onDelete: () => deletes++,
      );

      await tester.tap(find.text('harvest'));
      expect((toggles, deletes), (1, 0));

      await tester.tap(find.byIcon(Icons.close));
      expect((toggles, deletes), (1, 1));
    });

    testWidgets('删除按钮带"删除 {单词}"语义标签', (tester) async {
      await _pumpChip(tester);
      expect(find.bySemanticsLabel('删除 harvest'), findsOneWidget);
    });

    testWidgets('选中：对勾、无删除线；未选中：减号、删除线、虚线描边', (tester) async {
      await _pumpChip(tester, selected: true);
      expect(find.byIcon(Icons.check), findsOneWidget);
      expect(
        tester.widget<Text>(find.text('harvest')).style!.decoration,
        isNot(TextDecoration.lineThrough),
      );

      await _pumpChip(tester, selected: false);
      expect(find.byIcon(Icons.remove), findsOneWidget);
      expect(
        tester.widget<Text>(find.text('harvest')).style!.decoration,
        TextDecoration.lineThrough,
      );
      expect(
        find.descendant(
          of: find.byType(WordChip),
          matching: find.byType(CustomPaint),
        ),
        findsWidgets,
      );
    });

    testWidgets('禁用（生成中）时既不能切换也不能删除', (tester) async {
      var calls = 0;
      await _pumpChip(
        tester,
        enabled: false,
        onToggle: () => calls++,
        onDelete: () => calls++,
      );
      await tester.tap(find.text('harvest'));
      await tester.tap(find.byIcon(Icons.close));
      expect(calls, 0);
    });
  });

  group('WordTagWrap', () {
    const words = ['a1', 'a2', 'a3', 'a4', 'a5', 'a6', 'a7'];

    testWidgets('超过 maxVisible 时只显示前几个并加 +N', (tester) async {
      await pumpLocalized(
        tester,
        const WordTagWrap(words: words, maxVisible: 5),
      );
      expect(find.byType(WordTag), findsNWidgets(5));
      expect(find.text('+2'), findsOneWidget);
      expect(find.text('a6'), findsNothing);
    });

    testWidgets('不超过时全部显示，没有 +N', (tester) async {
      await pumpLocalized(
        tester,
        const WordTagWrap(words: words, maxVisible: 7),
      );
      expect(find.byType(WordTag), findsNWidgets(7));
      expect(find.byType(MoreWordsTag), findsNothing);
    });

    testWidgets('不限数量时全部显示', (tester) async {
      await pumpLocalized(tester, const WordTagWrap(words: words));
      expect(find.byType(WordTag), findsNWidgets(7));
    });
  });
}
