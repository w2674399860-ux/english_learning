import 'package:flutter/material.dart';

import '../theme/theme_x.dart';
import 'ink/ink_box.dart';

/// 按钮配色。primary 为粉色主按钮，其余是设计稿中的次级按钮配色。
enum InkButtonVariant { primary, paper, lime, butter, danger }

/// 设计稿的手绘风按钮：纯色填充 + 墨色硬阴影，按下时压进阴影。
///
/// - 默认全宽、高 56、胶囊形（Q-V3）。[compact] 为 true 时按内容宽度、高 48、圆角 16。
/// - [isLoading] 时显示小进度圈和 [loadingLabel]，不可点击但不置灰。
/// - [onPressed] 为 null 时禁用，整体半透明（设计稿生成按钮的 opacity-50）。
class InkButton extends StatelessWidget {
  const InkButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = InkButtonVariant.primary,
    this.leadingIcon,
    this.trailingIcon,
    this.isLoading = false,
    this.loadingLabel,
    this.compact = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final InkButtonVariant variant;
  final IconData? leadingIcon;
  final IconData? trailingIcon;
  final bool isLoading;

  /// 加载中显示的文字；为空时保留 [label]。
  final String? loadingLabel;
  final bool compact;

  bool get _enabled => onPressed != null && !isLoading;

  (Color, Color) _colors(BuildContext context) {
    final c = context.colors;
    switch (variant) {
      case InkButtonVariant.primary:
        return (c.primaryContainer, c.onPrimaryContainer);
      case InkButtonVariant.paper:
        return (context.tokens.cardSurface, c.onSurface);
      case InkButtonVariant.lime:
        return (c.secondaryContainer, c.onSecondaryFixed);
      case InkButtonVariant.butter:
        return (c.tertiaryFixed, c.onTertiaryFixed);
      case InkButtonVariant.danger:
        return (c.error, c.onError);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final (background, foreground) = _colors(context);
    final textStyle =
        (compact ? context.text.labelLarge : context.text.titleMedium)
            ?.copyWith(color: foreground);
    final iconSize = compact ? tokens.iconMd : tokens.iconLg;

    final List<Widget> children;
    if (isLoading) {
      children = [
        SizedBox.square(
          dimension: tokens.progressSize,
          child: CircularProgressIndicator(
            strokeWidth: tokens.progressStroke,
            color: foreground,
          ),
        ),
        SizedBox(width: tokens.spaceMd),
        Flexible(
          child: Text(
            loadingLabel ?? label,
            style: textStyle,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ];
    } else {
      children = [
        if (leadingIcon != null) ...[
          Icon(leadingIcon, size: iconSize, color: foreground),
          SizedBox(width: tokens.spaceSm),
        ],
        Flexible(
          child: Text(label, style: textStyle, overflow: TextOverflow.ellipsis),
        ),
        if (trailingIcon != null) ...[
          SizedBox(width: tokens.spaceSm),
          Icon(trailingIcon, size: iconSize, color: foreground),
        ],
      ];
    }

    final button = InkBox(
      color: background,
      borderRadius: BorderRadius.circular(
        compact ? tokens.radiusLg : tokens.buttonHeight / 2,
      ),
      shadow: tokens.shadowButton,
      onTap: _enabled ? onPressed : null,
      isButton: true,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minHeight: compact ? tokens.minTouchTarget : tokens.buttonHeight,
          minWidth: tokens.minTouchTarget,
        ),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: tokens.spaceLg),
          child: Row(
            mainAxisSize: compact ? MainAxisSize.min : MainAxisSize.max,
            mainAxisAlignment: MainAxisAlignment.center,
            children: children,
          ),
        ),
      ),
    );

    // 加载中保持不透明，只有真正禁用时才半透明
    if (onPressed == null && !isLoading) {
      return Opacity(opacity: tokens.disabledOpacity, child: button);
    }
    return button;
  }
}
