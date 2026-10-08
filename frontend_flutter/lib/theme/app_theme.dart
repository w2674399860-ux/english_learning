import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import 'storybook_tokens.dart';

/// 标题字体（可变字体：wght 200–800，opsz 12–96）。
const String headingFontFamily = 'BricolageGrotesque';

/// 正文字体（可变字体：wght 200–800）。
const String bodyFontFamily = 'PlusJakartaSans';

/// 中文后备字体：只在 Web 上使用打包的思源黑体，移动端走系统中文字体（U-10 I-d）。
/// Web 不打包时，Flutter 会从 fonts.gstatic.com 下载缺字字体，大陆访问可能失败。
const String _webChineseFallback = 'NotoSansSC';

List<String>? get chineseFontFallback =>
    kIsWeb ? const [_webChineseFallback] : null;

/// 设计稿色板（9 份 HTML 的 tailwind.config.colors 完全一致）。
const ColorScheme storybookColorScheme = ColorScheme(
  brightness: Brightness.light,
  primary: Color(0xFFB32053),
  onPrimary: Color(0xFFFFFFFF),
  primaryContainer: Color(0xFFFF5C8A),
  // Q-V5：粉色主按钮上的文字用墨色（对比度约 4.9:1），而不是设计稿的白字（约 2.9:1）
  onPrimaryContainer: Color(0xFF2D2926),
  primaryFixed: Color(0xFFFFD9DF),
  primaryFixedDim: Color(0xFFFFB1C0),
  onPrimaryFixed: Color(0xFF3F0017),
  onPrimaryFixedVariant: Color(0xFF90003D),
  secondary: Color(0xFF3C6A00),
  onSecondary: Color(0xFFFFFFFF),
  secondaryContainer: Color(0xFFB8F47A),
  onSecondaryContainer: Color(0xFF407100),
  secondaryFixed: Color(0xFFB8F47A),
  secondaryFixedDim: Color(0xFF9DD761),
  onSecondaryFixed: Color(0xFF0E2000),
  onSecondaryFixedVariant: Color(0xFF2C5000),
  tertiary: Color(0xFF725C06),
  onTertiary: Color(0xFFFFFFFF),
  tertiaryContainer: Color(0xFFC5A951),
  onTertiaryContainer: Color(0xFF4E3E00),
  tertiaryFixed: Color(0xFFFFE083),
  tertiaryFixedDim: Color(0xFFE2C469),
  onTertiaryFixed: Color(0xFF231B00),
  onTertiaryFixedVariant: Color(0xFF564500),
  error: Color(0xFFBA1A1A),
  onError: Color(0xFFFFFFFF),
  errorContainer: Color(0xFFFFDAD6),
  onErrorContainer: Color(0xFF93000A),
  surface: Color(0xFFFDF9F2),
  onSurface: Color(0xFF1C1C18),
  onSurfaceVariant: Color(0xFF584045),
  surfaceDim: Color(0xFFDDDAD3),
  surfaceBright: Color(0xFFFDF9F2),
  // Q-V4：卡片用 #FFFDF9（DESIGN.md "避免纯白"），与 StorybookTokens.cardSurface 一致
  surfaceContainerLowest: Color(0xFFFFFDF9),
  surfaceContainerLow: Color(0xFFF7F3EC),
  surfaceContainer: Color(0xFFF1EDE6),
  surfaceContainerHigh: Color(0xFFEBE8E1),
  surfaceContainerHighest: Color(0xFFE6E2DB),
  outline: Color(0xFF8C7075),
  outlineVariant: Color(0xFFE0BEC3),
  inverseSurface: Color(0xFF31302C),
  onInverseSurface: Color(0xFFF4F0E9),
  inversePrimary: Color(0xFFFFB1C0),
  // M3 的 elevation 着色会让米白纸色发粉，关掉
  surfaceTint: Colors.transparent,
  shadow: Color(0xFF2D2926),
  scrim: Color(0xFF2D2926),
);

/// 可变字体需要同时设置 fontWeight 与 wght 轴：Flutter 不会自动把 fontWeight 映射到 wght。
List<FontVariation> _variations(
  String family,
  FontWeight weight,
  double size,
) => [
  FontVariation('wght', weight.value.toDouble()),
  if (family == headingFontFamily)
    // 浏览器的 font-optical-sizing: auto 按字号取 opsz，这里做同样的事
    FontVariation('opsz', size.clamp(12, 96).toDouble()),
];

TextStyle _style(
  String family,
  double size,
  double lineHeight,
  FontWeight weight,
) {
  return TextStyle(
    fontFamily: family,
    fontFamilyFallback: chineseFontFallback,
    fontSize: size,
    height: lineHeight / size,
    fontWeight: weight,
    fontVariations: _variations(family, weight, size),
    letterSpacing: 0,
  );
}

/// 设计稿字号层级（字号 / 行高 px）。label-sm 11/14 按 Q-V6 提到 12/16。
TextTheme buildTextTheme(ColorScheme scheme) {
  const h = headingFontFamily;
  const b = bodyFontFamily;
  final theme = TextTheme(
    displayLarge: _style(h, 38, 46, FontWeight.w800),
    displayMedium: _style(h, 30, 38, FontWeight.w800),
    displaySmall: _style(h, 26, 34, FontWeight.w800),
    headlineLarge: _style(h, 26, 34, FontWeight.w700),
    headlineMedium: _style(h, 22, 30, FontWeight.w700),
    headlineSmall: _style(h, 18, 26, FontWeight.w700),
    titleLarge: _style(h, 22, 30, FontWeight.w700),
    titleMedium: _style(h, 18, 26, FontWeight.w700),
    titleSmall: _style(b, 16, 22, FontWeight.w700),
    bodyLarge: _style(b, 17, 26, FontWeight.w500),
    bodyMedium: _style(b, 15, 22, FontWeight.w500),
    bodySmall: _style(b, 13, 18, FontWeight.w500),
    labelLarge: _style(b, 16, 22, FontWeight.w700),
    labelMedium: _style(b, 14, 18, FontWeight.w700),
    labelSmall: _style(b, 12, 16, FontWeight.w700),
  );
  return theme.apply(
    bodyColor: scheme.onSurface,
    displayColor: scheme.onSurface,
  );
}

extension TextStyleWeight on TextStyle {
  /// 改字重时同步更新可变字体的 wght 轴；直接 copyWith(fontWeight:) 在拉丁字母上看不出变化。
  TextStyle withWeight(FontWeight weight) {
    final kept = (fontVariations ?? const <FontVariation>[]).where(
      (v) => v.axis != 'wght',
    );
    return copyWith(
      fontWeight: weight,
      fontVariations: [...kept, FontVariation('wght', weight.value.toDouble())],
    );
  }
}

ThemeData buildAppTheme() {
  const scheme = storybookColorScheme;
  final tokens = StorybookTokens.light;
  final text = buildTextTheme(scheme);

  RoundedRectangleBorder rounded(double r) =>
      RoundedRectangleBorder(borderRadius: BorderRadius.circular(r));

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    textTheme: text,
    fontFamily: bodyFontFamily,
    fontFamilyFallback: chineseFontFallback,
    scaffoldBackgroundColor: scheme.surface,
    canvasColor: scheme.surface,
    // 只有浅色主题（Q-V8）
    brightness: Brightness.light,
    extensions: [tokens],
    appBarTheme: AppBarTheme(
      backgroundColor: scheme.surface,
      foregroundColor: scheme.onSurface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: true,
      titleTextStyle: text.titleMedium,
      shape: Border(bottom: BorderSide(color: scheme.surfaceContainerHigh)),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: scheme.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      height: 64,
      indicatorColor: Colors.transparent,
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return text.labelSmall?.copyWith(
          color: selected ? scheme.primaryContainer : scheme.onSurfaceVariant,
        );
      }),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return IconThemeData(
          size: tokens.iconLg,
          color: selected ? scheme.primaryContainer : scheme.onSurfaceVariant,
        );
      }),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: scheme.surfaceContainerLow,
      hintStyle: text.bodyMedium?.copyWith(color: scheme.outline),
      labelStyle: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
      helperStyle: text.labelSmall?.copyWith(color: scheme.onSurfaceVariant),
      errorStyle: text.labelSmall?.copyWith(color: scheme.error),
      contentPadding: EdgeInsets.symmetric(
        horizontal: tokens.spaceLg,
        vertical: tokens.spaceMd,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(tokens.radiusMd),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(tokens.radiusMd),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(tokens.radiusMd),
        borderSide: BorderSide(
          color: tokens.ink,
          width: tokens.chipStrokeWidth,
        ),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(tokens.radiusMd),
        borderSide: BorderSide(
          color: scheme.error,
          width: tokens.chipStrokeWidth,
        ),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(tokens.radiusMd),
        borderSide: BorderSide(
          color: scheme.error,
          width: tokens.chipStrokeWidth,
        ),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: scheme.inverseSurface,
      contentTextStyle: text.labelMedium?.copyWith(
        color: scheme.onInverseSurface,
      ),
      shape: const StadiumBorder(),
      elevation: 0,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: tokens.cardSurface,
      surfaceTintColor: Colors.transparent,
      shape: rounded(tokens.radiusMd),
      titleTextStyle: text.titleMedium,
      contentTextStyle: text.bodyMedium?.copyWith(
        color: scheme.onSurfaceVariant,
      ),
      barrierColor: tokens.scrim,
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: tokens.cardSurface,
      surfaceTintColor: Colors.transparent,
      shape: rounded(tokens.radiusMd),
      textStyle: text.labelMedium,
      // 设计稿的账户下拉菜单本身就是柔和阴影（0 8px 20px），是唯一保留的模糊阴影
      elevation: 3,
      shadowColor: tokens.ink,
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: scheme.primaryContainer,
      linearTrackColor: scheme.surfaceContainerHighest,
      circularTrackColor: Colors.transparent,
    ),
    cardTheme: CardThemeData(
      color: tokens.cardSurface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: rounded(tokens.radiusLg),
    ),
    dividerTheme: DividerThemeData(
      color: scheme.surfaceContainerHigh,
      thickness: 1,
      space: 1,
    ),
    // 以下按钮与标签主题只是兜底：主要按钮和单词标签用自定义组件（硬阴影无法用 elevation 表达）
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: scheme.primaryContainer,
        foregroundColor: scheme.onPrimaryContainer,
        textStyle: text.labelLarge,
        minimumSize: Size(tokens.minTouchTarget, tokens.minTouchTarget),
        shape: const StadiumBorder(),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: scheme.onSurface,
        textStyle: text.labelLarge,
        minimumSize: Size(tokens.minTouchTarget, tokens.minTouchTarget),
        side: BorderSide(color: tokens.ink),
        shape: const StadiumBorder(),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: scheme.primary,
        textStyle: text.labelLarge,
        minimumSize: Size(tokens.minTouchTarget, tokens.minTouchTarget),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: scheme.primaryContainer,
        foregroundColor: scheme.onPrimaryContainer,
        textStyle: text.labelLarge,
        elevation: 0,
        minimumSize: Size(tokens.minTouchTarget, tokens.minTouchTarget),
        shape: rounded(tokens.radiusLg),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: scheme.surfaceContainerLow,
      selectedColor: scheme.secondaryContainer,
      labelStyle: text.labelMedium,
      side: BorderSide.none,
      shape: const StadiumBorder(),
      checkmarkColor: scheme.onSecondaryFixed,
    ),
    iconTheme: IconThemeData(color: scheme.onSurface, size: tokens.iconLg),
    tooltipTheme: TooltipThemeData(
      textStyle: text.labelSmall?.copyWith(color: scheme.onInverseSurface),
      decoration: BoxDecoration(
        color: scheme.inverseSurface,
        borderRadius: BorderRadius.circular(tokens.radiusSm),
      ),
    ),
  );
}
