import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../theme/theme_x.dart';

/// 错误条 / 错误卡：errorContainer 底，左侧错误图标，可选右侧"重试"。
/// 用于表单提示框、确认页生成失败、历史页加载 / 删除失败。
class ErrorNotice extends StatelessWidget {
  const ErrorNotice({super.key, required this.message, this.onRetry});

  final String message;

  /// 为 null 时不显示"重试"（如 429 次数用完）。
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final c = context.colors;

    return Semantics(
      liveRegion: true,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: tokens.spaceMd,
          vertical: tokens.spaceSm,
        ),
        decoration: BoxDecoration(
          color: c.errorContainer,
          borderRadius: BorderRadius.circular(tokens.radiusMd),
        ),
        child: Row(
          children: [
            Icon(Icons.error, size: tokens.iconMd, color: c.onErrorContainer),
            SizedBox(width: tokens.spaceSm),
            Expanded(
              child: Text(
                message,
                style: context.text.bodySmall?.copyWith(
                  color: c.onErrorContainer,
                ),
              ),
            ),
            if (onRetry != null)
              TextButton(
                onPressed: onRetry,
                style: TextButton.styleFrom(
                  foregroundColor: c.onErrorContainer,
                ),
                child: Text(context.l10n.commonRetry),
              ),
          ],
        ),
      ),
    );
  }
}
