import 'package:flutter/widgets.dart';

import '../providers/difficulty.dart';
import 'app_localizations.dart';

export 'app_localizations.dart';

/// App 唯一的语言（CLAUDE.md 第 9 节 I1）。MaterialApp 固定使用它，系统语言是英文时界面也是中文。
const Locale appLocale = Locale('zh');

/// 不在 Widget 树中时取文案（如 errorMessage()、AppProvider 的错误前缀）。
/// 只有一种语言，结果与 context.l10n 相同；以后支持多语言时这里要改为跟随当前 locale。
final AppLocalizations appL10n = lookupAppLocalizations(appLocale);

extension L10nX on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}

/// 难度的界面文字。传给后端的值仍是 Difficulty.apiValue（I-4）。
String difficultyLabel(AppLocalizations l10n, Difficulty difficulty) {
  switch (difficulty) {
    case Difficulty.beginner:
      return l10n.difficultyBeginner;
    case Difficulty.intermediate:
      return l10n.difficultyIntermediate;
    case Difficulty.advanced:
      return l10n.difficultyAdvanced;
  }
}
