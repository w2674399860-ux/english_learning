import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

/// 设计稿（ui设计/stitch_document_driven_ui_design）中 ColorScheme / TextTheme 表达不了的参数：
/// 墨线色、硬阴影、圆角、间距、尺寸、阅读区样式等。
///
/// 页面和组件只从这里与 [ThemeData] 取值，不写字面量（CLAUDE.md U-12 要求）。
/// 数值来源与取舍见 docs/UI设计落地方案.md 第 2、3 节。
@immutable
class StorybookTokens extends ThemeExtension<StorybookTokens> {
  const StorybookTokens({
    required this.ink,
    required this.cardSurface,
    required this.scrim,
    required this.chipStrokeWidth,
    required this.dashLength,
    required this.dashGap,
    required this.shadowSmall,
    required this.shadowChip,
    required this.shadowCard,
    required this.shadowButton,
    required this.shadowPressed,
    required this.shadowDialog,
    required this.pressDepth,
    required this.pressDuration,
    required this.radiusXs,
    required this.radiusSm,
    required this.radiusMd,
    required this.radiusLg,
    required this.radiusXl,
    required this.spaceXxs,
    required this.spaceXs,
    required this.spaceSm,
    required this.spaceMd,
    required this.spaceLg,
    required this.spaceXl,
    required this.spaceXxl,
    required this.pageMargin,
    required this.maxContentWidth,
    required this.buttonHeight,
    required this.heroButtonHeight,
    required this.inputHeight,
    required this.inlineInputHeight,
    required this.minTouchTarget,
    required this.iconSm,
    required this.iconMd,
    required this.iconLg,
    required this.iconTile,
    required this.iconTileLg,
    required this.statusDot,
    required this.tagDot,
    required this.avatarSize,
    required this.progressStroke,
    required this.progressSize,
    required this.progressBarHeight,
    required this.illustrationSize,
    required this.illustrationSizeSm,
    required this.illustrationSizeXs,
    required this.heroIllustrationMax,
    required this.tiltDegrees,
    required this.disabledOpacity,
    required this.inactiveChipOpacity,
    required this.tipBackgroundOpacity,
    required this.targetWordBackgroundOpacity,
    required this.readingLineHeight,
    required this.englishLetterSpacing,
    required this.tapeColors,
  });

  // —— 墨线与纸 ——
  /// 墨线色：硬阴影、描边。设计稿中写死的 #2D2926。
  final Color ink;

  /// 卡片底色（Q-V4：#FFFDF9，"避免纯白"）。
  final Color cardSurface;

  /// 弹层遮罩：ink @ 40%。
  final Color scrim;

  /// 可勾选单词标签的描边宽度（Q-V1：其余组件不描边）。
  final double chipStrokeWidth;
  final double dashLength;
  final double dashGap;

  // —— 硬阴影（无模糊）——
  /// 只读标签、徽章、填空格。
  final Offset shadowSmall;

  /// 可勾选单词标签、确认页小按钮。
  final Offset shadowChip;

  /// 卡片。
  final Offset shadowCard;

  /// 按钮（按下后变为 [shadowPressed]，整体下移 [pressDepth]）。
  final Offset shadowButton;
  final Offset shadowPressed;

  /// 对话框。
  final Offset shadowDialog;
  final double pressDepth;
  final Duration pressDuration;

  // —— 圆角 ——
  /// 填空格。
  final double radiusXs;

  /// 图标底块。
  final double radiusSm;

  /// 输入框、对话框、错误条、小卡片。
  final double radiusMd;

  /// 分节卡片、可勾选单词标签、次级按钮。
  final double radiusLg;

  /// 整页状态卡片、插画框。
  final double radiusXl;

  // —— 间距（4 的倍数）——
  final double spaceXxs; // 2：标签内图标与文字等极小间隔
  final double spaceXs; // 4
  final double spaceSm; // 8
  final double spaceMd; // 12
  final double spaceLg; // 16
  final double spaceXl; // 24
  final double spaceXxl; // 32

  /// 页面左右边距（设计稿 margin 20）。
  final double pageMargin;

  /// 宽屏时内容最大宽度（Q-V9）。
  final double maxContentWidth;

  // —— 尺寸 ——
  final double buttonHeight;
  final double heroButtonHeight;
  final double inputHeight;
  final double inlineInputHeight;
  final double minTouchTarget;
  final double iconSm; // 16
  final double iconMd; // 20
  final double iconLg; // 24
  final double iconTile; // 32：分节标题图标块、提示卡图标
  final double iconTileLg; // 44：首页入口按钮图标块
  final double statusDot; // 可勾选单词标签前的状态圆点
  final double tagDot; // 只读单词标签前的小圆点
  final double avatarSize;
  final double progressStroke;
  final double progressSize; // 按钮内小进度圈
  final double progressBarHeight;
  final double illustrationSize;
  final double illustrationSizeSm;
  final double illustrationSizeXs; // 注册页顶部的小吉祥物
  final double heroIllustrationMax; // 首页插画框的最大边长（设计稿 max-w-[320px]）

  /// 手绘装饰的倾斜角度（度），如首页插画框的两层底衬（设计稿 rotate(±2deg)）。
  final double tiltDegrees;

  // —— 透明度 ——
  final double disabledOpacity;
  final double inactiveChipOpacity;
  final double tipBackgroundOpacity;
  final double targetWordBackgroundOpacity;

  // —— 阅读区 ——
  /// 短文、译文、填空的行高（设计稿 _1：leading-[1.8]）。
  final double readingLineHeight;

  /// 英文字距 0.015em（DESIGN.md），按 17px 计算。
  final double englishLetterSpacing;

  // —— 装饰 ——
  /// 历史卡片胶带颜色（tertiary-fixed-dim@70%、secondary-container@80%、primary-fixed@80%）。
  final List<Color> tapeColors;

  static final StorybookTokens light = StorybookTokens(
    ink: const Color(0xFF2D2926),
    cardSurface: const Color(0xFFFFFDF9),
    scrim: const Color(0x662D2926),
    chipStrokeWidth: 2,
    dashLength: 5,
    dashGap: 4,
    shadowSmall: const Offset(1.5, 1.5),
    shadowChip: const Offset(2, 3),
    shadowCard: const Offset(3, 3),
    shadowButton: const Offset(0, 4),
    shadowPressed: const Offset(0, 1),
    shadowDialog: const Offset(0, 8),
    pressDepth: 3,
    pressDuration: const Duration(milliseconds: 150),
    radiusXs: 4,
    radiusSm: 8,
    radiusMd: 12,
    radiusLg: 16,
    radiusXl: 24,
    spaceXxs: 2,
    spaceXs: 4,
    spaceSm: 8,
    spaceMd: 12,
    spaceLg: 16,
    spaceXl: 24,
    spaceXxl: 32,
    pageMargin: 20,
    maxContentWidth: 480,
    buttonHeight: 56,
    heroButtonHeight: 62,
    inputHeight: 56,
    inlineInputHeight: 48,
    minTouchTarget: 48,
    iconSm: 16,
    iconMd: 20,
    iconLg: 24,
    iconTile: 32,
    iconTileLg: 44,
    statusDot: 14,
    tagDot: 6,
    avatarSize: 32,
    progressStroke: 2,
    progressSize: 18,
    progressBarHeight: 12,
    illustrationSize: 240,
    illustrationSizeSm: 160,
    illustrationSizeXs: 96,
    heroIllustrationMax: 320,
    tiltDegrees: 2,
    disabledOpacity: 0.5,
    inactiveChipOpacity: 0.7,
    tipBackgroundOpacity: 0.3,
    targetWordBackgroundOpacity: 0.6,
    readingLineHeight: 1.8,
    englishLetterSpacing: 0.26,
    tapeColors: const [Color(0xB3E2C469), Color(0xCCB8F47A), Color(0xCCFFD9DF)],
  );

  /// 硬阴影：无模糊，颜色为墨线色。
  List<BoxShadow> hardShadow(Offset offset) => [
    BoxShadow(color: ink, offset: offset, blurRadius: 0),
  ];

  @override
  StorybookTokens copyWith({
    Color? ink,
    Color? cardSurface,
    Color? scrim,
    double? maxContentWidth,
  }) {
    return StorybookTokens(
      ink: ink ?? this.ink,
      cardSurface: cardSurface ?? this.cardSurface,
      scrim: scrim ?? this.scrim,
      chipStrokeWidth: chipStrokeWidth,
      dashLength: dashLength,
      dashGap: dashGap,
      shadowSmall: shadowSmall,
      shadowChip: shadowChip,
      shadowCard: shadowCard,
      shadowButton: shadowButton,
      shadowPressed: shadowPressed,
      shadowDialog: shadowDialog,
      pressDepth: pressDepth,
      pressDuration: pressDuration,
      radiusXs: radiusXs,
      radiusSm: radiusSm,
      radiusMd: radiusMd,
      radiusLg: radiusLg,
      radiusXl: radiusXl,
      spaceXxs: spaceXxs,
      spaceXs: spaceXs,
      spaceSm: spaceSm,
      spaceMd: spaceMd,
      spaceLg: spaceLg,
      spaceXl: spaceXl,
      spaceXxl: spaceXxl,
      pageMargin: pageMargin,
      maxContentWidth: maxContentWidth ?? this.maxContentWidth,
      buttonHeight: buttonHeight,
      heroButtonHeight: heroButtonHeight,
      inputHeight: inputHeight,
      inlineInputHeight: inlineInputHeight,
      minTouchTarget: minTouchTarget,
      iconSm: iconSm,
      iconMd: iconMd,
      iconLg: iconLg,
      iconTile: iconTile,
      iconTileLg: iconTileLg,
      statusDot: statusDot,
      tagDot: tagDot,
      avatarSize: avatarSize,
      progressStroke: progressStroke,
      progressSize: progressSize,
      progressBarHeight: progressBarHeight,
      illustrationSize: illustrationSize,
      illustrationSizeSm: illustrationSizeSm,
      illustrationSizeXs: illustrationSizeXs,
      heroIllustrationMax: heroIllustrationMax,
      tiltDegrees: tiltDegrees,
      disabledOpacity: disabledOpacity,
      inactiveChipOpacity: inactiveChipOpacity,
      tipBackgroundOpacity: tipBackgroundOpacity,
      targetWordBackgroundOpacity: targetWordBackgroundOpacity,
      readingLineHeight: readingLineHeight,
      englishLetterSpacing: englishLetterSpacing,
      tapeColors: tapeColors,
    );
  }

  /// 只有浅色主题（Q-V8），不会在两套令牌之间过渡：颜色插值，其余取目标值。
  @override
  StorybookTokens lerp(ThemeExtension<StorybookTokens>? other, double t) {
    if (other is! StorybookTokens) return this;
    final base = t < 0.5 ? this : other;
    return base.copyWith(
      ink: Color.lerp(ink, other.ink, t),
      cardSurface: Color.lerp(cardSurface, other.cardSurface, t),
      scrim: Color.lerp(scrim, other.scrim, t),
      maxContentWidth: lerpDouble(maxContentWidth, other.maxContentWidth, t),
    );
  }
}
