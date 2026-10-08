import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'auth/auth_api.dart';
import 'auth/auth_interceptor.dart';
import 'auth/session.dart';
import 'auth/token_store.dart';
import 'dev/component_gallery.dart';
import 'l10n/l10n.dart';
import 'pages/auth/auth_gate.dart';
import 'providers/app_provider.dart';
import 'providers/auth_provider.dart';
import 'services/api_service.dart';
import 'theme/app_theme.dart';

/// 调试用组件展示页：flutter run --dart-define=SHOW_GALLERY=true。
/// 只在调试构建中生效，release 构建里这个分支恒为 false。
const bool _showGallery = bool.fromEnvironment('SHOW_GALLERY');

final ThemeData _appTheme = buildAppTheme();

void main() {
  _registerFontLicenses();
  runApp(const MyApp());
}

/// 打包的字体都是 SIL OFL 1.1，许可证要求随字体分发许可证文本。
void _registerFontLicenses() {
  const licenses = {
    'Bricolage Grotesque': 'assets/fonts/bricolage_grotesque/OFL.txt',
    'Plus Jakarta Sans': 'assets/fonts/plus_jakarta_sans/OFL.txt',
    'Noto Sans SC': 'assets/fonts/noto_sans_sc/OFL.txt',
  };
  LicenseRegistry.addLicense(() async* {
    for (final entry in licenses.entries) {
      final text = await rootBundle.loadString(entry.value);
      yield LicenseEntryWithLineBreaks([entry.key], text);
    }
  });
}

/// 根组件：组装账号相关的依赖（A-2 前端方案第 2 项）。
/// [authApi]、[tokenStore] 只在测试中注入；正式运行时使用 Dio 实现与平台存储。
class MyApp extends StatefulWidget {
  const MyApp({super.key, this.authApi, this.tokenStore});

  final AuthApi? authApi;
  final TokenStore? tokenStore;

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final AuthSession _session = AuthSession();
  final AppProvider _app = AppProvider();
  late final AuthProvider _auth;

  @override
  void initState() {
    super.initState();
    final api = ApiService();
    api.setAuthInterceptor(
      AuthInterceptor(
        session: _session,
        onUnauthorized: () => _auth.handleUnauthorized(),
      ),
    );
    _auth = AuthProvider(
      api: widget.authApi ?? DioAuthApi(api.dio),
      store: widget.tokenStore ?? createPlatformTokenStore(),
      session: _session,
      // 登出与凭证失效都会清空 AppProvider 中全部用户相关状态
      onSignedOut: [_app.resetForSignOut],
    );
    _auth.restore();
  }

  @override
  void dispose() {
    _auth.dispose();
    _app.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: _auth),
        ChangeNotifierProvider.value(value: _app),
      ],
      child: MaterialApp(
        onGenerateTitle: (context) => context.l10n.appTitle,
        debugShowCheckedModeBanner: false,
        theme: _appTheme,
        // 只有浅色主题（Q-V8）
        themeMode: ThemeMode.light,
        // 只提供简体中文（I1）。固定 locale：系统语言是英文时，界面与系统控件也显示中文
        locale: appLocale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: kDebugMode && _showGallery
            ? const ComponentGallery()
            : const AuthGate(),
      ),
    );
  }
}
