import 'package:english_learning_app/theme/app_theme.dart';
import 'package:english_learning_app/theme/storybook_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final theme = buildAppTheme();
  final scheme = theme.colorScheme;

  test('色板与设计稿 tailwind.config 一致（含已确认的调整）', () {
    expect(scheme.primary, const Color(0xFFB32053));
    expect(scheme.primaryContainer, const Color(0xFFFF5C8A));
    expect(scheme.secondaryContainer, const Color(0xFFB8F47A));
    expect(scheme.tertiaryFixed, const Color(0xFFFFE083));
    expect(scheme.surface, const Color(0xFFFDF9F2));
    expect(scheme.error, const Color(0xFFBA1A1A));
    // Q-V4：卡片 #FFFDF9；Q-V5：粉色按钮上用墨色字
    expect(scheme.surfaceContainerLowest, const Color(0xFFFFFDF9));
    expect(scheme.onPrimaryContainer, const Color(0xFF2D2926));
    expect(theme.brightness, Brightness.light);
  });

  test('StorybookTokens 已挂载，卡片底色与色板一致', () {
    final tokens = theme.extension<StorybookTokens>();
    expect(tokens, isNotNull);
    expect(tokens!.ink, const Color(0xFF2D2926));
    expect(tokens.cardSurface, scheme.surfaceContainerLowest);
    expect(tokens.maxContentWidth, 480);
    expect(tokens.shadowButton.dy - tokens.shadowPressed.dy, tokens.pressDepth);
  });

  test('所有文字样式不小于 12（Q-V6），且字重与可变字体 wght 轴一致', () {
    final styles = {
      'displayLarge': theme.textTheme.displayLarge,
      'displayMedium': theme.textTheme.displayMedium,
      'headlineLarge': theme.textTheme.headlineLarge,
      'headlineMedium': theme.textTheme.headlineMedium,
      'headlineSmall': theme.textTheme.headlineSmall,
      'titleLarge': theme.textTheme.titleLarge,
      'titleMedium': theme.textTheme.titleMedium,
      'bodyLarge': theme.textTheme.bodyLarge,
      'bodyMedium': theme.textTheme.bodyMedium,
      'bodySmall': theme.textTheme.bodySmall,
      'labelLarge': theme.textTheme.labelLarge,
      'labelMedium': theme.textTheme.labelMedium,
      'labelSmall': theme.textTheme.labelSmall,
    };
    for (final MapEntry(:key, :value) in styles.entries) {
      expect(value, isNotNull, reason: key);
      expect(value!.fontSize, greaterThanOrEqualTo(12), reason: key);
      final wght = value.fontVariations!.firstWhere((v) => v.axis == 'wght');
      expect(wght.value, value.fontWeight!.value.toDouble(), reason: key);
    }
    expect(theme.textTheme.headlineLarge!.fontFamily, headingFontFamily);
    expect(theme.textTheme.bodyMedium!.fontFamily, bodyFontFamily);
  });

  test('withWeight 同时更新 fontWeight 与 wght 轴，保留其他轴', () {
    final heading = theme.textTheme.titleMedium!;
    final lighter = heading.withWeight(FontWeight.w500);
    expect(lighter.fontWeight, FontWeight.w500);
    final axes = {for (final v in lighter.fontVariations!) v.axis: v.value};
    expect(axes['wght'], 500);
    expect(axes['opsz'], 18);
  });

  test('copyWith 与 lerp 不丢字段', () {
    final tokens = StorybookTokens.light;
    final copy = tokens.copyWith(maxContentWidth: 600);
    expect(copy.maxContentWidth, 600);
    expect(copy.radiusLg, tokens.radiusLg);
    expect(tokens.lerp(copy, 1).maxContentWidth, 600);
    expect(tokens.lerp(null, 0.5), same(tokens));
  });
}
