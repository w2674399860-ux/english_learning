import 'package:english_learning_app/widgets/blank_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/pump_app.dart';

void main() {
  const blank = TextStyle(decoration: TextDecoration.underline);

  test('英文填空：___ 拆成空格片段，其余为普通片段', () {
    final spans = buildBlankSpans('walked through the ___ to help', blank);
    expect(spans.map((s) => s.text), [
      'walked through the ',
      '___',
      ' to help',
    ]);
    expect(spans[1].style, blank);
    expect(spans[0].style, isNull);
  });

  test('中文填空：___ (___) 里的两个空格都识别', () {
    final spans = buildBlankSpans('穿过___ (___)，去帮奶奶', blank);
    expect(spans.where((s) => s.style == blank), hasLength(2));
    expect(spans.map((s) => s.text).join(), '穿过___ (___)，去帮奶奶');
  });

  test('单个下划线不算空格；没有空格时原样返回', () {
    final spans = buildBlankSpans('snake_case word', blank);
    expect(spans, hasLength(1));
    expect(spans.single.style, isNull);
  });

  testWidgets('空格片段：下划线字符透明，下方是主色虚线', (tester) async {
    await pumpLocalized(
      tester,
      const BlankText(text: 'the ___ sat', english: true),
    );
    final root =
        tester.widget<RichText>(find.byType(RichText)).text as TextSpan;
    final blankSpan = (root.children!.cast<TextSpan>()).firstWhere(
      (s) => s.text == '___',
    );
    final context = tester.element(find.byType(BlankText));
    final style = blankSpan.style!;
    expect(style.color, Colors.transparent);
    expect(style.decoration, TextDecoration.underline);
    expect(style.decorationStyle, TextDecorationStyle.dashed);
    expect(style.decorationColor, Theme.of(context).colorScheme.primary);
  });
}
