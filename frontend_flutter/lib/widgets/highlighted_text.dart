import 'package:flutter/material.dart';

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
    spans.add(TextSpan(
      text: m.group(0),
      style: highlightStyle,
    ));
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
    spans.add(TextSpan(
      text: m.group(0),
      style: wordSet.contains(inner.toLowerCase()) ? highlightStyle : null,
    ));
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
    final baseStyle =
        DefaultTextStyle.of(context).style.copyWith(color: Colors.black87);
    // 加粗 + 主题主色。不加下划线：目标词在短文中密度较高，三重强调会让
    // 正文过噪；且填空区块用 ___ 表示空格，下划线与之语义相近容易混淆。
    final highlightStyle = TextStyle(
      fontWeight: FontWeight.w700,
      color: Theme.of(context).colorScheme.primary,
    );

    return RichText(
      text: TextSpan(
        style: baseStyle,
        children: _isChinese
            ? buildChineseSpans(text, words, highlightStyle)
            : buildEnglishSpans(text, words, highlightStyle),
      ),
    );
  }
}
