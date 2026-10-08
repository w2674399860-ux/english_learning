import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/l10n.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/illustration.dart';
import '../../widgets/state_view.dart';
import '../main_screen.dart';
import 'login_page.dart';

/// App 的根页面：按登录状态显示启动页、启动失败页、登录页或主框架（A-2 前端方案第 1 项）。
///
/// 登录状态每次变化，都关闭推入的所有页面和对话框（识别、确认、结果、详情、注册、修改密码……），
/// 回到这里重新选择：登录 / 注册成功后进入首页，登出 / 凭证失效后回到登录页。
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  late final AuthProvider _auth;
  late AuthStatus _lastStatus;

  @override
  void initState() {
    super.initState();
    _auth = context.read<AuthProvider>();
    _lastStatus = _auth.status;
    // 直接监听而不是在 build 里比较：本页被其他页面盖住时不一定会重建，
    // 而凭证失效恰恰常发生在识别、确认等推入的页面上
    _auth.addListener(_onAuthChanged);
  }

  void _onAuthChanged() {
    final status = _auth.status;
    if (status == _lastStatus || !mounted) return;
    _lastStatus = status;
    Navigator.of(context).popUntil((route) => route.isFirst);
    if (status == AuthStatus.unauthenticated) {
      ScaffoldMessenger.of(context).clearSnackBars();
    }
  }

  @override
  void dispose() {
    _auth.removeListener(_onAuthChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final l10n = context.l10n;
    switch (auth.status) {
      case AuthStatus.unknown:
        return Scaffold(
          body: StateView(
            illustration: IllustrationKind.mascot,
            title: l10n.appTitle,
            isLoading: true,
          ),
        );
      case AuthStatus.startupError:
        return Scaffold(
          body: StateView(
            illustration: IllustrationKind.sad,
            title: l10n.startupErrorTitle,
            primaryAction: StateAction(
              label: l10n.commonRetry,
              icon: Icons.refresh,
              onPressed: auth.restore,
            ),
            secondaryAction: StateAction(
              label: l10n.startupErrorLogout,
              icon: Icons.logout,
              onPressed: auth.logout,
            ),
          ),
        );
      case AuthStatus.unauthenticated:
        return const LoginPage();
      case AuthStatus.authenticated:
        return const MainScreen();
    }
  }
}
