import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../theme/theme_x.dart';

/// 表单输入框（设计稿 ai_5 / ai_6 / ai_7）：上方"图标 + 标签"，56 高的浅底输入区，
/// 聚焦时变为卡片底色并加小号硬阴影；下方是辅助说明或错误文字。
///
/// [isPassword] 为 true 时遮挡输入，右侧带"显示或隐藏密码"切换。
class InkTextField extends StatefulWidget {
  const InkTextField({
    super.key,
    required this.label,
    this.controller,
    this.icon,
    this.hint,
    this.helper,
    this.errorText,
    this.isPassword = false,
    this.enabled = true,
    this.keyboardType,
    this.textInputAction,
    this.onSubmitted,
    this.onChanged,
    this.autofillHints,
    this.focusNode,
  });

  final String label;
  final TextEditingController? controller;
  final IconData? icon;
  final String? hint;
  final String? helper;
  final String? errorText;
  final bool isPassword;
  final bool enabled;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;
  final ValueChanged<String>? onChanged;
  final Iterable<String>? autofillHints;
  final FocusNode? focusNode;

  @override
  State<InkTextField> createState() => _InkTextFieldState();
}

class _InkTextFieldState extends State<InkTextField> {
  late FocusNode _focusNode = widget.focusNode ?? FocusNode();
  bool _obscured = true;
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_onFocusChange);
  }

  @override
  void didUpdateWidget(InkTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.focusNode != widget.focusNode) {
      _focusNode.removeListener(_onFocusChange);
      if (oldWidget.focusNode == null) _focusNode.dispose();
      _focusNode = widget.focusNode ?? FocusNode();
      _focusNode.addListener(_onFocusChange);
    }
  }

  void _onFocusChange() => setState(() => _focused = _focusNode.hasFocus);

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    if (widget.focusNode == null) _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final c = context.colors;
    final hasError = widget.errorText != null;

    final field = TextField(
      controller: widget.controller,
      focusNode: _focusNode,
      enabled: widget.enabled,
      obscureText: widget.isPassword && _obscured,
      enableSuggestions: !widget.isPassword,
      autocorrect: !widget.isPassword,
      keyboardType: widget.keyboardType,
      textInputAction: widget.textInputAction,
      onSubmitted: widget.onSubmitted,
      onChanged: widget.onChanged,
      autofillHints: widget.autofillHints,
      style: context.text.bodyMedium,
      decoration: InputDecoration(
        hintText: widget.hint,
        helperText: hasError ? null : widget.helper,
        errorText: widget.errorText,
        fillColor: _focused ? tokens.cardSurface : c.surfaceContainerLow,
        constraints: BoxConstraints(minHeight: tokens.inputHeight),
        // 聚焦靠底色和硬阴影表达，不再画描边（Q-V1）；错误时保留红色描边
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(tokens.radiusMd),
          borderSide: BorderSide.none,
        ),
        suffixIcon: widget.isPassword
            ? IconButton(
                tooltip: context.l10n.passwordVisibilityToggle,
                onPressed: () => setState(() => _obscured = !_obscured),
                icon: Icon(
                  _obscured ? Icons.visibility_off : Icons.visibility,
                  size: tokens.iconMd,
                  color: c.onSurfaceVariant,
                ),
              )
            : null,
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            if (widget.icon != null) ...[
              Icon(widget.icon, size: tokens.iconMd, color: c.primary),
              SizedBox(width: tokens.spaceXs),
            ],
            Text(widget.label, style: context.text.labelMedium),
          ],
        ),
        SizedBox(height: tokens.spaceSm),
        // 只给输入区加阴影（不含下方的辅助文字），所以单独包一层
        _FocusShadow(active: _focused && !hasError, child: field),
      ],
    );
  }
}

/// 聚焦时在输入区背后画小号硬阴影。错误文字在 TextField 内部，阴影只覆盖固定高度的输入区。
///
/// 无论是否聚焦，树结构都保持 Stack 不变、只切换阴影的可见性：
/// 若聚焦时才包一层 Stack，TextField 会被重新挂载，丢失焦点和正在输入的内容。
class _FocusShadow extends StatelessWidget {
  const _FocusShadow({required this.active, required this.child});

  final bool active;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Stack(
      children: [
        Positioned(
          left: tokens.shadowSmall.dx,
          top: tokens.shadowSmall.dy,
          right: -tokens.shadowSmall.dx,
          height: tokens.inputHeight,
          child: Visibility(
            visible: active,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: tokens.ink,
                borderRadius: BorderRadius.circular(tokens.radiusMd),
              ),
            ),
          ),
        ),
        child,
      ],
    );
  }
}
