import 'dart:async';

import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import '../../theme/theme_x.dart';
import '../../widgets/ink_button.dart';

/// 倒计时显示为 mm:ss（限流窗口最长 1 小时）。
String formatCountdown(Duration remaining) {
  final total = remaining.inSeconds < 0 ? 0 : remaining.inSeconds;
  final minutes = (total ~/ 60).toString().padLeft(2, '0');
  final seconds = (total % 60).toString().padLeft(2, '0');
  return '$minutes:$seconds';
}

/// 登录、注册、修改密码的提交按钮。
/// - 提交中：按钮内进度圈。
/// - 被限流（429）：禁用到 [retryAt]，按钮上显示"mm:ss 后可再试"，每秒刷新，到时自动恢复。
class AuthSubmitButton extends StatefulWidget {
  const AuthSubmitButton({
    super.key,
    required this.label,
    required this.onPressed,
    required this.isLoading,
    required this.retryAt,
    this.leadingIcon,
    this.trailingIcon,
  });

  final String label;
  final VoidCallback onPressed;
  final bool isLoading;
  final DateTime? retryAt;
  final IconData? leadingIcon;
  final IconData? trailingIcon;

  @override
  State<AuthSubmitButton> createState() => _AuthSubmitButtonState();
}

class _AuthSubmitButtonState extends State<AuthSubmitButton> {
  Timer? _ticker;

  bool get _limited =>
      widget.retryAt != null && DateTime.now().isBefore(widget.retryAt!);

  @override
  void initState() {
    super.initState();
    _syncTicker();
  }

  @override
  void didUpdateWidget(AuthSubmitButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.retryAt != widget.retryAt) _syncTicker();
  }

  void _syncTicker() {
    _ticker?.cancel();
    _ticker = null;
    if (!_limited) return;
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {});
      if (!_limited) {
        _ticker?.cancel();
        _ticker = null;
      }
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final limited = _limited;
    final label = limited
        ? context.l10n.rateLimitedCountdown(
            formatCountdown(widget.retryAt!.difference(DateTime.now())),
          )
        : widget.label;
    return InkButton(
      label: label,
      leadingIcon: limited ? Icons.hourglass_top : widget.leadingIcon,
      trailingIcon: limited ? null : widget.trailingIcon,
      isLoading: widget.isLoading,
      onPressed: limited ? null : widget.onPressed,
    );
  }
}

/// 表单卡片标题：左侧粉色竖条 + 大标题（设计稿 ai_7 / ai_5）。
class AuthCardTitle extends StatelessWidget {
  const AuthCardTitle({super.key, required this.title, this.large = true});

  final String title;
  final bool large;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Row(
      children: [
        Container(
          width: tokens.spaceSm + tokens.spaceXxs,
          height: tokens.iconLg,
          decoration: BoxDecoration(
            color: context.colors.primaryContainer,
            borderRadius: BorderRadius.circular(tokens.radiusSm),
          ),
        ),
        SizedBox(width: tokens.spaceSm),
        Flexible(
          child: Text(
            title,
            style: large
                ? context.text.headlineLarge
                : context.text.titleMedium,
          ),
        ),
      ],
    );
  }
}

/// "还没有账号？注册" 这类一行提示 + 链接。
class AuthSwitchLink extends StatelessWidget {
  const AuthSwitchLink({
    super.key,
    required this.prompt,
    required this.action,
    required this.onPressed,
  });

  final String prompt;
  final String action;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          prompt,
          style: context.text.bodyMedium?.copyWith(color: c.onSurfaceVariant),
        ),
        TextButton(
          onPressed: onPressed,
          child: Text(
            action,
            style: context.text.labelLarge?.copyWith(
              color: c.primary,
              decoration: TextDecoration.underline,
              decorationColor: c.primary,
            ),
          ),
        ),
      ],
    );
  }
}
