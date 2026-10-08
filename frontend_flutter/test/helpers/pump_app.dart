import 'package:english_learning_app/l10n/l10n.dart';
import 'package:english_learning_app/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// 测试中取文案：与正式 App 相同的简体中文 AppLocalizations。
final AppLocalizations testL10n = lookupAppLocalizations(appLocale);

/// 用与正式 App 相同的主题、locale 与本地化代理包装 [child]，放进一个 Scaffold。
/// [inAppBar] 为 true 时把 child 放在 AppBar 的 actions 里（顶栏按钮类组件）。
Future<void> pumpLocalized(
  WidgetTester tester,
  Widget child, {
  bool inAppBar = false,
  Size? surfaceSize,
}) async {
  if (surfaceSize != null) {
    await tester.binding.setSurfaceSize(surfaceSize);
    addTearDown(() => tester.binding.setSurfaceSize(null));
  }
  await tester.pumpWidget(
    MaterialApp(
      theme: buildAppTheme(),
      locale: appLocale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: inAppBar
          ? Scaffold(appBar: AppBar(actions: [child]))
          : Scaffold(body: child),
    ),
  );
}
