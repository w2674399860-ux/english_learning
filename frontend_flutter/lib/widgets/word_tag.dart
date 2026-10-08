import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../theme/theme_x.dart';

/// 只读单词标签（结果页、详情页、历史卡片）：胶囊形，左侧绿色小圆点，小号硬阴影。
class WordTag extends StatelessWidget {
  const WordTag({super.key, required this.word});

  final String word;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final c = context.colors;
    return _TagShell(
      color: c.surfaceContainerLow,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: tokens.tagDot,
            height: tokens.tagDot,
            decoration: BoxDecoration(
              color: c.secondary,
              shape: BoxShape.circle,
            ),
          ),
          SizedBox(width: tokens.spaceXs),
          Flexible(child: Text(word, style: context.text.labelMedium)),
        ],
      ),
    );
  }
}

/// 单词太多时的溢出数徽章，如 "+13"。
class MoreWordsTag extends StatelessWidget {
  const MoreWordsTag({super.key, required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return _TagShell(
      color: c.tertiaryFixed,
      child: Text(
        context.l10n.historyCardMoreWords(count),
        style: context.text.labelMedium?.copyWith(color: c.onTertiaryFixed),
      ),
    );
  }
}

/// 一组只读标签。[maxVisible] 不为空且单词更多时，只显示前 [maxVisible] 个，再加一个 "+N"。
class WordTagWrap extends StatelessWidget {
  const WordTagWrap({super.key, required this.words, this.maxVisible});

  final List<String> words;
  final int? maxVisible;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final limit = maxVisible;
    final overflow = limit != null && words.length > limit;
    final shown = overflow ? words.take(limit) : words;

    return Wrap(
      spacing: tokens.spaceSm,
      runSpacing: tokens.spaceSm,
      children: [
        for (final w in shown) WordTag(word: w),
        if (overflow) MoreWordsTag(count: words.length - limit),
      ],
    );
  }
}

class _TagShell extends StatelessWidget {
  const _TagShell({required this.color, required this.child});

  final Color color;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: tokens.spaceMd,
        vertical: tokens.spaceXs,
      ),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(tokens.radiusLg),
        boxShadow: tokens.hardShadow(tokens.shadowSmall),
      ),
      child: child,
    );
  }
}
