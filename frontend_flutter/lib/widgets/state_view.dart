import 'package:flutter/material.dart';

import '../theme/theme_x.dart';
import 'illustration.dart';
import 'ink_button.dart';

/// 一个状态按钮。
class StateAction {
  const StateAction({required this.label, required this.onPressed, this.icon});

  final String label;
  final VoidCallback onPressed;
  final IconData? icon;
}

/// 整页状态：插画 + 标题 + 说明 + 最多两个按钮。
/// 用于识别中 / 识别失败 / 网络错误、历史空状态、启动失败等（设计稿 ai_2）。
class StateView extends StatelessWidget {
  const StateView({
    super.key,
    required this.title,
    this.illustration,
    this.illustrationBadge,
    this.message,
    this.extra,
    this.isLoading = false,
    this.primaryAction,
    this.secondaryAction,
  });

  final String title;
  final IllustrationKind? illustration;
  final Widget? illustrationBadge;
  final String? message;

  /// 说明下方的附加内容，如识别失败时的拍照提示卡。
  final Widget? extra;

  /// 显示不确定进度条（识别中等）。后端没有进度数据，不显示百分比（Q-F0）。
  final bool isLoading;
  final StateAction? primaryAction;
  final StateAction? secondaryAction;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final c = context.colors;

    return Center(
      child: SingleChildScrollView(
        padding: EdgeInsets.all(tokens.pageMargin),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: tokens.maxContentWidth),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (illustration != null) ...[
                Illustration(kind: illustration!, badge: illustrationBadge),
                SizedBox(height: tokens.spaceLg),
              ],
              Text(
                title,
                style: context.text.headlineMedium,
                textAlign: TextAlign.center,
              ),
              if (message != null) ...[
                SizedBox(height: tokens.spaceSm),
                Text(
                  message!,
                  style: context.text.bodyMedium?.copyWith(
                    color: c.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
              if (extra != null) ...[
                SizedBox(height: tokens.spaceXl),
                extra!,
              ],
              if (isLoading) ...[
                SizedBox(height: tokens.spaceXl),
                ClipRRect(
                  borderRadius: BorderRadius.circular(
                    tokens.progressBarHeight / 2,
                  ),
                  child: SizedBox(
                    height: tokens.progressBarHeight,
                    child: const LinearProgressIndicator(),
                  ),
                ),
              ],
              if (primaryAction != null) ...[
                SizedBox(height: tokens.spaceXl),
                InkButton(
                  label: primaryAction!.label,
                  leadingIcon: primaryAction!.icon,
                  onPressed: primaryAction!.onPressed,
                ),
              ],
              if (secondaryAction != null) ...[
                SizedBox(height: tokens.spaceLg),
                InkButton(
                  label: secondaryAction!.label,
                  leadingIcon: secondaryAction!.icon,
                  onPressed: secondaryAction!.onPressed,
                  variant: InkButtonVariant.paper,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
