import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../theme/theme_x.dart';
import 'ink/dashed_border.dart';
import 'ink/ink_box.dart';

/// 确认页可勾选的单词标签（设计稿 ai_1）。
///
/// - 选中：卡片底色、2px 墨线实线描边、硬阴影，左侧亮绿对勾圆点。
/// - 未选中：灰底、虚线描边、半透明、删除线，左侧减号圆点。
/// - 右侧 × 删除。[enabled] 为 false 时（生成中）既不能切换也不能删除。
class WordChip extends StatelessWidget {
  const WordChip({
    super.key,
    required this.word,
    required this.selected,
    required this.onToggle,
    required this.onDelete,
    this.enabled = true,
  });

  final String word;
  final bool selected;
  final VoidCallback onToggle;
  final VoidCallback onDelete;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final c = context.colors;
    final radius = BorderRadius.circular(tokens.radiusLg);
    final textStyle = context.text.labelLarge?.copyWith(
      color: selected ? tokens.ink : c.onSurfaceVariant,
      decoration: selected ? null : TextDecoration.lineThrough,
    );

    final dot = Container(
      width: tokens.statusDot,
      height: tokens.statusDot,
      decoration: BoxDecoration(
        color: selected ? c.secondaryContainer : c.surface,
        shape: BoxShape.circle,
        border: Border.all(color: selected ? tokens.ink : c.outline),
      ),
      child: Icon(
        selected ? Icons.check : Icons.remove,
        size: tokens.statusDot - tokens.spaceXs,
        color: selected ? tokens.ink : c.outline,
      ),
    );

    final deleteButton = Semantics(
      // 独立的语义节点：不并入外层标签的"选中"节点，读屏可以单独聚焦到删除按钮
      container: true,
      button: true,
      enabled: enabled,
      label: context.l10n.confirmDeleteWord(word),
      excludeSemantics: true,
      child: InkResponse(
        onTap: enabled ? onDelete : null,
        radius: tokens.iconTile / 2,
        child: SizedBox.square(
          dimension: tokens.iconTile,
          child: Icon(
            Icons.close,
            size: tokens.iconSm,
            color: c.onSurfaceVariant,
          ),
        ),
      ),
    );

    Widget chip = InkBox(
      color: selected ? tokens.cardSurface : c.surfaceContainerHigh,
      borderRadius: radius,
      shadow: selected ? tokens.shadowChip : null,
      border: selected
          ? Border.all(color: tokens.ink, width: tokens.chipStrokeWidth)
          : null,
      onTap: enabled ? onToggle : null,
      padding: EdgeInsets.only(left: tokens.spaceMd, right: tokens.spaceXxs),
      child: Semantics(
        selected: selected,
        explicitChildNodes: true,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            dot,
            SizedBox(width: tokens.spaceSm),
            Flexible(child: Text(word, style: textStyle)),
            deleteButton,
          ],
        ),
      ),
    );

    if (!selected) {
      chip = CustomPaint(
        foregroundPainter: DashedBorderPainter(
          color: c.outline,
          strokeWidth: tokens.chipStrokeWidth,
          radius: tokens.radiusLg,
          dashLength: tokens.dashLength,
          gapLength: tokens.dashGap,
        ),
        child: Opacity(opacity: tokens.inactiveChipOpacity, child: chip),
      );
    }

    if (!enabled) {
      chip = Opacity(opacity: tokens.disabledOpacity, child: chip);
    }
    return chip;
  }
}
