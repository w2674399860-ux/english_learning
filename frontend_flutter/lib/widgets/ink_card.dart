import 'package:flutter/material.dart';

import '../theme/theme_x.dart';
import 'ink/ink_box.dart';

/// 纸片卡片：卡片底色、圆角 16、墨色硬阴影 (3, 3)，不描边（Q-V1）。
class InkCard extends StatelessWidget {
  const InkCard({
    super.key,
    required this.child,
    this.padding,
    this.color,
    this.radius,
    this.shadow,
    this.onTap,
  });

  final Widget child;

  /// 默认 16。
  final EdgeInsetsGeometry? padding;

  /// 默认卡片底色 cardSurface。
  final Color? color;

  /// 默认 radiusLg。
  final double? radius;

  /// 默认 shadowCard。
  final Offset? shadow;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return InkBox(
      color: color ?? tokens.cardSurface,
      borderRadius: BorderRadius.circular(radius ?? tokens.radiusLg),
      shadow: shadow ?? tokens.shadowCard,
      padding: padding ?? EdgeInsets.all(tokens.spaceLg),
      onTap: onTap,
      child: child,
    );
  }
}
