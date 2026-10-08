import 'package:flutter/material.dart';

import '../theme/theme_x.dart';
import 'ink/ink_box.dart';

/// 首页的两个入口按钮（从相册上传、拍照）：左侧图标块，主标题 + 副标题，右侧圆形箭头。
class HeroActionButton extends StatelessWidget {
  const HeroActionButton({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onPressed,
    this.lime = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onPressed;

  /// false 为粉色（相册），true 为亮绿（拍照），与设计稿 ai_3 一致。
  final bool lime;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final c = context.colors;
    final background = lime ? c.secondaryContainer : c.primaryContainer;
    final foreground = lime ? c.onSecondaryFixed : c.onPrimaryContainer;
    final tileColor = tokens.cardSurface.withValues(
      alpha: tokens.inactiveChipOpacity,
    );

    return InkBox(
      color: background,
      borderRadius: BorderRadius.circular(tokens.radiusLg),
      shadow: tokens.shadowButton,
      onTap: onPressed,
      isButton: true,
      padding: EdgeInsets.symmetric(horizontal: tokens.spaceLg),
      child: SizedBox(
        height: tokens.heroButtonHeight,
        child: Row(
          children: [
            Container(
              width: tokens.iconTileLg,
              height: tokens.iconTileLg,
              decoration: BoxDecoration(
                color: tileColor,
                borderRadius: BorderRadius.circular(tokens.radiusMd),
              ),
              child: Icon(icon, color: foreground, size: tokens.iconLg),
            ),
            SizedBox(width: tokens.spaceLg),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: context.text.titleMedium?.copyWith(
                      color: foreground,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    subtitle,
                    style: context.text.labelSmall?.copyWith(color: foreground),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Container(
              width: tokens.iconTile,
              height: tokens.iconTile,
              decoration: BoxDecoration(
                color: tileColor,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.arrow_forward,
                color: foreground,
                size: tokens.iconMd,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
