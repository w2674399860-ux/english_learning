import 'package:flutter/material.dart';

import '../theme/theme_x.dart';
import 'ink_card.dart';

/// 学习结果与历史详情页共用的分节卡片：彩色图标块 + 标题（+ 可选数量徽章、右侧操作）。
class SectionCard extends StatelessWidget {
  const SectionCard({
    super.key,
    required this.title,
    required this.child,
    this.icon = Icons.menu_book,
    this.iconBackground,
    this.badge,
    this.trailing,
  });

  final String title;
  final Widget child;
  final IconData icon;

  /// 图标块底色，默认 primaryFixed（浅粉）。
  final Color? iconBackground;

  /// 标题后的小徽章文字，如"18 个"。
  final String? badge;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final c = context.colors;

    return InkCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: tokens.iconTile,
                height: tokens.iconTile,
                decoration: BoxDecoration(
                  color: iconBackground ?? c.primaryFixed,
                  borderRadius: BorderRadius.circular(tokens.radiusSm),
                  boxShadow: tokens.hardShadow(tokens.shadowSmall),
                ),
                child: Icon(icon, size: tokens.iconMd, color: c.onSurface),
              ),
              SizedBox(width: tokens.spaceSm),
              Flexible(child: Text(title, style: context.text.titleMedium)),
              if (badge != null) ...[
                SizedBox(width: tokens.spaceSm),
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: tokens.spaceSm,
                    vertical: tokens.spaceXxs,
                  ),
                  decoration: BoxDecoration(
                    color: c.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(tokens.radiusLg),
                  ),
                  child: Text(
                    badge!,
                    style: context.text.labelSmall?.copyWith(
                      color: c.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
              const Spacer(),
              ?trailing,
            ],
          ),
          SizedBox(height: tokens.spaceMd),
          child,
        ],
      ),
    );
  }
}
