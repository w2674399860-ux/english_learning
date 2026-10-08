import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/theme_x.dart';

/// Build TextSpans for an English passage, highlighting the memorized words.
/// Matching memorized words case-insensitively with word boundaries.
List<TextSpan> buildEnglishSpans(
  String text,
  List<String> words,
  TextStyle highlightStyle,
) {
  if (words.isEmpty || text.isEmpty) {
    return [TextSpan(text: text)];
  }

  // Sort by length descending so longer words match before substrings
  final sorted = List<String>.from(words)
    ..sort((a, b) => b.length.compareTo(a.length));

  final escaped = sorted.map((w) => RegExp.escape(w)).join('|');
  final pattern = RegExp('\\b($escaped)\\b', caseSensitive: false);

  final spans = <TextSpan>[];
  int lastEnd = 0;

  for (final m in pattern.allMatches(text)) {
    if (m.start > lastEnd) {
      spans.add(TextSpan(text: text.substring(lastEnd, m.start)));
    }
    spans.add(TextSpan(text: m.group(0), style: highlightStyle));
    lastEnd = m.end;
  }

  if (lastEnd < text.length) {
    spans.add(TextSpan(text: text.substring(lastEnd)));
  }

  return spans;
}

/// Build TextSpans for a Chinese passage, highlighting the memorized words.
/// Matches English words in parentheses: (word) or （word）.
List<TextSpan> buildChineseSpans(
  String text,
  List<String> words,
  TextStyle highlightStyle,
) {
  if (words.isEmpty || text.isEmpty) {
    return [TextSpan(text: text)];
  }

  final wordSet = words.map((w) => w.toLowerCase()).toSet();
  // Match both half-width (word) and full-width （word） parentheses
  final pattern = RegExp(r'（([^）]*)）|\(([^)]*)\)');

  final spans = <TextSpan>[];
  int lastEnd = 0;

  for (final m in pattern.allMatches(text)) {
    if (m.start > lastEnd) {
      spans.add(TextSpan(text: text.substring(lastEnd, m.start)));
    }

    final inner = (m.group(1) ?? m.group(2) ?? '').trim();
    spans.add(
      TextSpan(
        text: m.group(0),
        style: wordSet.contains(inner.toLowerCase()) ? highlightStyle : null,
      ),
    );
    lastEnd = m.end;
  }

  if (lastEnd < text.length) {
    spans.add(TextSpan(text: text.substring(lastEnd)));
  }

  return spans;
}

/// 渲染一段短文，并把目标单词高亮出来。
///
/// `HighlightedText.english` 按词边界匹配英文原词；
/// `HighlightedText.chinese` 匹配中译里 “苹果 (apple)” 这种夹注形式。
class HighlightedText extends StatelessWidget {
  const HighlightedText.english({
    super.key,
    required this.text,
    required this.words,
  }) : _isChinese = false;

  const HighlightedText.chinese({
    super.key,
    required this.text,
    required this.words,
  }) : _isChinese = true;

  final String text;
  final List<String> words;
  final bool _isChinese;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final tokens = context.tokens;
    final baseStyle = readingTextStyle(context, english: !_isChinese);
    // 加粗 + 主题主色（withWeight 同步可变字体的 wght 轴，否则拉丁字母看不出加粗）。
    // 英文短文的目标词再加奶油黄底（设计稿 _1）；中译夹注只加粗变色。
    // 不加下划线：填空区块用下划线表示空格，二者语义相近容易混淆。
    var highlightStyle = baseStyle
        .withWeight(FontWeight.w700)
        .copyWith(color: c.primary);
    if (!_isChinese) {
      highlightStyle = highlightStyle.copyWith(
        backgroundColor: c.tertiaryFixed.withValues(
          alpha: tokens.targetWordBackgroundOpacity,
        ),
      );
    }

    return RichText(
      // 放在 SelectionArea 中时可以选中复制（直接用 RichText 不会自动注册）
      selectionRegistrar: SelectionContainer.maybeOf(context),
      selectionColor:
          DefaultSelectionStyle.of(context).selectionColor ??
          DefaultSelectionStyle.defaultColor,
      text: TextSpan(
        style: baseStyle,
        children: _isChinese
            ? buildChineseSpans(text, words, highlightStyle)
            : buildEnglishSpans(text, words, highlightStyle),
      ),
    );
  }
}

/// 阅读区正文样式：bodyLarge，行高 1.8；英文加 0.015em 字距（DESIGN.md）。
TextStyle readingTextStyle(BuildContext context, {required bool english}) {
  final tokens = context.tokens;
  return context.text.bodyLarge!.copyWith(
    color: context.colors.onSurface,
    height: tokens.readingLineHeight,
    letterSpacing: english ? tokens.englishLetterSpacing : 0,
  );
}
