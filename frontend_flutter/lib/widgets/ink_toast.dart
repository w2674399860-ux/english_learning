import 'package:flutter/material.dart';

import '../theme/theme_x.dart';

/// 底部 Toast（设计稿 ai_7 / ai_4 的深色胶囊提示）。基于 SnackBar，样式来自 snackBarTheme。
void showInkToast(
  BuildContext context,
  String message, {
  bool isError = false,
}) {
  final tokens = context.tokens;
  final c = context.colors;
  final messenger = ScaffoldMessenger.of(context);
  // 与页面内容一样限宽（Q-V9），桌面宽屏上不横跨整个窗口；窄屏时左右留出页面边距
  final screenWidth = MediaQuery.sizeOf(context).width;
  final width = (screenWidth - tokens.pageMargin * 2).clamp(
    0.0,
    tokens.maxContentWidth,
  );
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        width: width,
        content: Row(
          children: [
            Icon(
              isError ? Icons.error : Icons.check_circle,
              size: tokens.iconMd,
              color: isError ? c.errorContainer : c.secondaryContainer,
            ),
            SizedBox(width: tokens.spaceSm),
            Expanded(child: Text(message)),
          ],
        ),
      ),
    );
}
