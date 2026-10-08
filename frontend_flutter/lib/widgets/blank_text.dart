import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/theme_x.dart';
import 'highlighted_text.dart';

/// 连续两个及以上的下划线视为一个空格（后端填空用 ___ 表示）。
final RegExp _blankPattern = RegExp(r'_{2,}');

/// 把填空文本拆成普通片段与空格片段。空格片段的下划线字符本身透明，
/// 下方画一条主色虚线，看起来是"待填写的横线"（设计稿 _2，Q-F2：不做查看答案）。
List<TextSpan> buildBlankSpans(String text, TextStyle blankStyle) {
  final spans = <TextSpan>[];
  var last = 0;
  for (final m in _blankPattern.allMatches(text)) {
    if (m.start > last) {
      spans.add(TextSpan(text: text.substring(last, m.start)));
    }
    spans.add(TextSpan(text: m.group(0), style: blankStyle));
    last = m.end;
  }
  if (last < text.length) spans.add(TextSpan(text: text.substring(last)));
  return spans;
}

/// 填空正文（英文填空、中文填空）。复制时仍是原来的 ___，便于粘贴到别处作答。
class BlankText extends StatelessWidget {
  const BlankText({super.key, required this.text, required this.english});

  final String text;

  /// 英文填空加 0.015em 字距，中文不加。
  final bool english;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final tokens = context.tokens;
    final baseStyle = readingTextStyle(context, english: english);
    final blankStyle = baseStyle
        .withWeight(FontWeight.w700)
        .copyWith(
          color: Colors.transparent,
          decoration: TextDecoration.underline,
          decorationStyle: TextDecorationStyle.dashed,
          decorationColor: c.primary,
          decorationThickness: tokens.chipStrokeWidth,
        );

    return RichText(
      selectionRegistrar: SelectionContainer.maybeOf(context),
      selectionColor:
          DefaultSelectionStyle.of(context).selectionColor ??
          DefaultSelectionStyle.defaultColor,
      text: TextSpan(
        style: baseStyle,
        children: buildBlankSpans(text, blankStyle),
      ),
    );
  }
}
