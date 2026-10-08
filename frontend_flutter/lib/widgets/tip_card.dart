import 'package:flutter/material.dart';

import '../theme/theme_x.dart';

/// 奶油黄提示卡（首页"学习小贴士"、确认页操作说明、修改密码"安全小贴士"）。
class TipCard extends StatelessWidget {
  const TipCard({
    super.key,
    required this.body,
    this.title,
    this.icon = Icons.lightbulb,
  });

  final String body;
  final String? title;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final c = context.colors;

    return Container(
      padding: EdgeInsets.all(tokens.spaceLg),
      decoration: BoxDecoration(
        // 半透明奶油黄叠在纸色上，用 alphaBlend 得到不透明色，避免硬阴影透出来
        color: Color.alphaBlend(
          c.tertiaryFixed.withValues(alpha: tokens.tipBackgroundOpacity),
          c.surface,
        ),
        borderRadius: BorderRadius.circular(tokens.radiusLg),
        boxShadow: tokens.hardShadow(tokens.shadowSmall),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: tokens.iconTile,
            height: tokens.iconTile,
            decoration: BoxDecoration(
              color: c.tertiaryFixed,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: tokens.iconMd, color: c.onTertiaryFixed),
          ),
          SizedBox(width: tokens.spaceMd),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (title != null) ...[
                  Text(title!, style: context.text.labelMedium),
                  SizedBox(height: tokens.spaceXs),
                ],
                Text(
                  body,
                  style: context.text.bodySmall?.copyWith(
                    color: c.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
