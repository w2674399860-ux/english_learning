import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:english_learning_app/widgets/highlighted_text.dart';

/// 取出 RichText 的根 span 与其子 span。
(TextSpan root, List<TextSpan> children) _spansOf(WidgetTester tester) {
  final richText = tester.widget<RichText>(find.byType(RichText));
  final root = richText.text as TextSpan;
  return (root, root.children!.cast<TextSpan>());
}

Future<void> _pump(WidgetTester tester, Widget child) {
  return tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(colorSchemeSeed: Colors.blue, useMaterial3: true),
      home: Scaffold(body: child),
    ),
  );
}

void main() {
  group('HighlightedText.english', () {
    testWidgets('目标词的实际渲染样式与正文不同', (tester) async {
      await _pump(
        tester,
        const HighlightedText.english(
          text: 'The cat sat on the mat.',
          words: ['cat'],
        ),
      );

      final (root, children) = _spansOf(tester);
      final baseStyle = root.style!;
      final target = children.firstWhere((s) => s.text == 'cat');

      // 关键断言：把 span 自己的样式合并到基准样式之后，结果必须与基准样式
      // 不同。只比较 target.style 与普通 span 的 style 是不够的——修复前
      // 目标词是 TextStyle(color: black87)、普通 span 是 null，两者"不同"，
      // 但合并到同样是 black87 的基准样式上之后渲染结果完全一致。
      expect(baseStyle.merge(target.style), isNot(equals(baseStyle)));
    });

    testWidgets('目标词加粗且使用主题主色', (tester) async {
      await _pump(
        tester,
        const HighlightedText.english(
          text: 'The cat sat on the mat.',
          words: ['cat'],
        ),
      );

      final context = tester.element(find.byType(RichText));
      final primary = Theme.of(context).colorScheme.primary;

      final (root, children) = _spansOf(tester);
      final effective = root.style!.merge(
        children.firstWhere((s) => s.text == 'cat').style,
      );

      expect(effective.fontWeight, FontWeight.w700);
      expect(effective.color, primary);
    });

    testWidgets('非目标词保持正文样式', (tester) async {
      await _pump(
        tester,
        const HighlightedText.english(
          text: 'The cat sat on the mat.',
          words: ['cat'],
        ),
      );

      final (root, children) = _spansOf(tester);
      final baseStyle = root.style!;
      final plain = children.firstWhere((s) => s.text != 'cat');

      expect(baseStyle.merge(plain.style), equals(baseStyle));
    });
  });

  group('HighlightedText.chinese', () {
    testWidgets('命中的夹注与正文样式不同', (tester) async {
      await _pump(
        tester,
        const HighlightedText.chinese(
          text: '那只猫 (cat) 坐在垫子上。',
          words: ['cat'],
        ),
      );

      final (root, children) = _spansOf(tester);
      final baseStyle = root.style!;
      final target = children.firstWhere((s) => s.text == '(cat)');

      expect(baseStyle.merge(target.style), isNot(equals(baseStyle)));
    });

    testWidgets('未命中的括号保持正文样式', (tester) async {
      await _pump(
        tester,
        const HighlightedText.chinese(
          text: '那只猫 (cat) 坐在垫子 (mat) 上。',
          words: ['cat'],
        ),
      );

      final (root, children) = _spansOf(tester);
      final baseStyle = root.style!;
      final notMatched = children.firstWhere((s) => s.text == '(mat)');

      expect(baseStyle.merge(notMatched.style), equals(baseStyle));
    });
  });
}
