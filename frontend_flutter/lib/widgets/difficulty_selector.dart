import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../providers/difficulty.dart';
import '../theme/theme_x.dart';
import 'ink/ink_box.dart';

/// 确认页的难度选择（设计稿 ai_1 底栏）："短文难度"标签 + 三个选项，选中为亮绿底。
/// onChanged 为 null 时禁用（例如生成中）。
class DifficultySelector extends StatelessWidget {
  const DifficultySelector({super.key, required this.value, this.onChanged});

  final Difficulty value;
  final ValueChanged<Difficulty>? onChanged;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final c = context.colors;
    final l10n = context.l10n;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: tokens.spaceSm,
        vertical: tokens.spaceXs,
      ),
      decoration: BoxDecoration(
        color: c.surfaceContainer,
        borderRadius: BorderRadius.circular(tokens.radiusLg),
      ),
      child: Row(
        children: [
          Icon(Icons.tune, size: tokens.iconSm, color: c.tertiary),
          SizedBox(width: tokens.spaceXs),
          Expanded(
            child: Text(l10n.difficultyLabel, style: context.text.labelMedium),
          ),
          for (final d in Difficulty.values) ...[
            SizedBox(width: tokens.spaceXs),
            _DifficultyOption(
              label: difficultyLabel(l10n, d),
              selected: d == value,
              onTap: onChanged == null ? null : () => onChanged!(d),
            ),
          ],
        ],
      ),
    );
  }
}

class _DifficultyOption extends StatelessWidget {
  const _DifficultyOption({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final c = context.colors;
    final style = context.text.labelMedium?.copyWith(
      color: selected ? c.onSecondaryFixed : c.onSurface,
    );

    // 合并为一个语义节点：读屏读出"中级，已选中，按钮"
    Widget option = MergeSemantics(
      child: Semantics(
        selected: selected,
        inMutuallyExclusiveGroup: true,
        child: InkBox(
          color: selected ? c.secondaryContainer : tokens.cardSurface,
          borderRadius: BorderRadius.circular(tokens.radiusMd),
          shadow: selected ? tokens.shadowChip : tokens.shadowSmall,
          onTap: onTap,
          isButton: true,
          padding: EdgeInsets.symmetric(
            horizontal: tokens.spaceMd,
            vertical: tokens.spaceSm,
          ),
          child: Text(label, style: style),
        ),
      ),
    );
    if (onTap == null) {
      option = Opacity(opacity: tokens.disabledOpacity, child: option);
    }
    return option;
  }
}
