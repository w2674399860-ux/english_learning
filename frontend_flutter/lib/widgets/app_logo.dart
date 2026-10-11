import 'package:flutter/material.dart';

import '../theme/theme_x.dart';

/// 应用图标前景层（透明背景）。与桌面图标同一张源图，见 assets/branding/。
const String appLogoAsset = 'assets/branding/app_icon_foreground_1024.png';

/// 图形在前景层中占的比例：前景层为 Android 自适应图标留了安全区边距，
/// 图形只占中间约 50%，显示时裁掉四周的透明边。
const double _graphicFraction = 0.52;

/// 应用 Logo（云朵与字母图形）。应用名由调用方用 appTitle 文字另行显示，
/// 所以这里纯装饰，不进语义树。
class AppLogo extends StatelessWidget {
  const AppLogo({super.key, this.size});

  /// 图形的显示边长，默认 tokens.illustrationSizeSm。
  final double? size;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final dimension = size ?? tokens.illustrationSizeSm;

    return ExcludeSemantics(
      child: SizedBox.square(
        dimension: dimension,
        child: ClipRect(
          child: OverflowBox(
            maxWidth: dimension / _graphicFraction,
            maxHeight: dimension / _graphicFraction,
            child: Image.asset(
              appLogoAsset,
              width: dimension / _graphicFraction,
              height: dimension / _graphicFraction,
              fit: BoxFit.contain,
              // 素材缺失时不让页面报错：退回一个图标
              errorBuilder: (_, _, _) => Icon(
                Icons.cloud,
                size: tokens.iconTileLg,
                color: context.colors.primaryContainer,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
