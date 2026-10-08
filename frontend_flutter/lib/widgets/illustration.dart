import 'package:flutter/material.dart';

import '../theme/theme_x.dart';

/// 插画用途。素材均为占位（授权不明），来源见 assets/images/SOURCES.md。
enum IllustrationKind {
  /// 书本吉祥物：登录、启动、识别中、空状态。
  mascot('assets/images/mascot_book.webp'),

  /// 首页插画。
  home('assets/images/illus_home.webp'),

  /// 失败、网络错误。
  sad('assets/images/illus_sad.webp');

  const IllustrationKind(this.asset);

  final String asset;
}

/// 图片占光晕直径的比例，留出一圈光晕。
const double _imageScale = 0.86;

/// 插画 + 背后的浅色圆形光晕（替代设计稿的 blur-2xl，见落地方案第 9 节）。纯装饰，不进语义树。
class Illustration extends StatelessWidget {
  const Illustration({super.key, required this.kind, this.size, this.badge});

  final IllustrationKind kind;

  /// 默认 tokens.illustrationSize。
  final double? size;

  /// 右上角角标，如网络错误的 wifi_off。
  final Widget? badge;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final c = context.colors;
    final dimension = size ?? tokens.illustrationSize;

    return ExcludeSemantics(
      child: SizedBox.square(
        dimension: dimension,
        child: Stack(
          alignment: Alignment.center,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    c.tertiaryFixed.withValues(
                      alpha: tokens.targetWordBackgroundOpacity,
                    ),
                    c.surface.withValues(alpha: 0),
                  ],
                ),
              ),
              child: const SizedBox.expand(),
            ),
            ClipRRect(
              borderRadius: BorderRadius.circular(tokens.radiusXl),
              child: Image.asset(
                kind.asset,
                width: dimension * _imageScale,
                height: dimension * _imageScale,
                fit: BoxFit.contain,
                // 素材缺失时不让页面报错：退回一个图标
                errorBuilder: (_, _, _) => Icon(
                  Icons.menu_book,
                  size: tokens.iconTileLg,
                  color: c.primaryContainer,
                ),
              ),
            ),
            if (badge != null) Positioned(top: 0, right: 0, child: badge!),
          ],
        ),
      ),
    );
  }
}
