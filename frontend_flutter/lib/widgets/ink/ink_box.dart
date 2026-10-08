import 'package:flutter/material.dart';

import '../../theme/theme_x.dart';

/// 设计稿的"纸片"外壳：底色 + 圆角 + 无模糊的墨色硬阴影。
///
/// 有 [onTap] 时可点击：按下时整体下移 pressDepth、阴影变为 shadowPressed，
/// 模拟 DESIGN.md 中"压进阴影里"的橡皮章手感。位移只影响绘制，不影响布局。
class InkBox extends StatefulWidget {
  const InkBox({
    super.key,
    required this.child,
    required this.color,
    required this.borderRadius,
    this.shadow,
    this.onTap,
    this.padding,
    this.border,
    this.semanticLabel,
    this.isButton = false,
  });

  final Widget child;
  final Color color;
  final BorderRadius borderRadius;

  /// 阴影偏移；null 表示无阴影。
  final Offset? shadow;

  /// null 时不可点击（静态卡片或禁用的按钮）。
  final VoidCallback? onTap;
  final EdgeInsetsGeometry? padding;
  final BoxBorder? border;
  final String? semanticLabel;

  /// 在语义树中标记为按钮（禁用的按钮也应标记）。
  final bool isButton;

  @override
  State<InkBox> createState() => _InkBoxState();
}

class _InkBoxState extends State<InkBox> {
  bool _pressed = false;

  @override
  void didUpdateWidget(InkBox oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 按下过程中变为禁用（如开始加载）时，复位按压状态
    if (widget.onTap == null && _pressed) _pressed = false;
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final pressed = _pressed && widget.onTap != null;
    final shadow = widget.shadow;
    final shownShadow = shadow == null
        ? null
        : (pressed ? tokens.shadowPressed : shadow);

    Widget content = AnimatedContainer(
      duration: tokens.pressDuration,
      curve: Curves.easeOut,
      transform: Matrix4.translationValues(
        0,
        pressed && shadow != null ? shadow.dy - tokens.shadowPressed.dy : 0,
        0,
      ),
      padding: widget.padding,
      decoration: BoxDecoration(
        color: widget.color,
        borderRadius: widget.borderRadius,
        border: widget.border,
        boxShadow: shownShadow == null ? null : tokens.hardShadow(shownShadow),
      ),
      child: widget.child,
    );

    if (widget.onTap != null) {
      content = Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: widget.onTap,
          onHighlightChanged: (v) => setState(() => _pressed = v),
          borderRadius: widget.borderRadius,
          splashFactory: NoSplash.splashFactory,
          highlightColor: Colors.transparent,
          hoverColor: Colors.transparent,
          focusColor: context.colors.primaryContainer.withValues(
            alpha: tokens.tipBackgroundOpacity,
          ),
          child: content,
        ),
      );
    }

    if (widget.isButton || widget.semanticLabel != null) {
      content = Semantics(
        button: widget.isButton,
        enabled: widget.isButton ? widget.onTap != null : null,
        label: widget.semanticLabel,
        child: content,
      );
    }
    return content;
  }
}
