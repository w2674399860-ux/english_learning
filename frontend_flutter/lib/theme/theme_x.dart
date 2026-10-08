import 'package:flutter/material.dart';

import 'storybook_tokens.dart';

/// 组件与页面取主题值的快捷方式。
extension ThemeX on BuildContext {
  StorybookTokens get tokens => Theme.of(this).extension<StorybookTokens>()!;
  ColorScheme get colors => Theme.of(this).colorScheme;
  TextTheme get text => Theme.of(this).textTheme;
}
