import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../theme/theme_x.dart';

/// 降级提示条：后端服务不可用、返回了示例数据时固定显示在页面顶部。
/// 只在开发环境出现（生产环境降级关闭，失败直接报错）。设计稿没有，按提示卡风格补出。
class DegradedBanner extends StatelessWidget {
  const DegradedBanner({
    super.key,
    required this.reason,
    this.showReason = true,
    this.message,
  });

  final String reason;

  /// 自定义主文案；为 null 时按 [reason] 选择（详情页的已保存记录用固定文案，Q-F12）。
  final String? message;

  /// 是否显示第二行"原因：xxx"（详情页的已保存记录没有原因，Q-F12）。
  final bool showReason;

  static String messageFor(AppLocalizations l10n, String reason) {
    switch (reason) {
      case 'ocr_unavailable':
        return l10n.degradedOcrUnavailable;
      case 'ocr_mock':
        return l10n.degradedOcrMock;
      case 'ai_not_configured':
        return l10n.degradedAiNotConfigured;
    }
    if (reason.startsWith('ai_')) return l10n.degradedAi;
    return l10n.degradedOther;
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final c = context.colors;
    final l10n = context.l10n;

    return Semantics(
      liveRegion: true,
      child: Container(
        width: double.infinity,
        color: c.tertiaryFixed,
        padding: EdgeInsets.symmetric(
          horizontal: tokens.pageMargin,
          vertical: tokens.spaceMd,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.info, size: tokens.iconMd, color: c.onTertiaryFixed),
            SizedBox(width: tokens.spaceMd),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    message ?? messageFor(l10n, reason),
                    style: context.text.bodySmall?.copyWith(
                      color: c.onTertiaryFixed,
                    ),
                  ),
                  if (showReason) ...[
                    SizedBox(height: tokens.spaceXs),
                    Text(
                      l10n.degradedReason(reason),
                      style: context.text.labelSmall?.copyWith(
                        color: c.onTertiaryFixedVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
