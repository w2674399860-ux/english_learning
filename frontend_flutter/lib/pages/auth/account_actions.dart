import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/l10n.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/account_menu.dart';
import '../../widgets/confirm_dialog.dart';
import 'change_password_page.dart';

/// 顶栏右侧的账户入口：只放在首页和历史两个 Tab 页（Q-F14）。
/// 修改密码进入 ChangePasswordPage；登出前弹确认框。
class AccountActions extends StatelessWidget {
  const AccountActions({super.key});

  Future<void> _confirmLogout(BuildContext context) async {
    final l10n = context.l10n;
    final auth = context.read<AuthProvider>();
    final confirmed = await showConfirmDialog(
      context,
      title: l10n.logoutDialogTitle,
      confirmLabel: l10n.logoutDialogConfirm,
      icon: Icons.logout,
    );
    if (confirmed) await auth.logout();
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    if (user == null) return const SizedBox.shrink();
    return AccountMenu(
      username: user.username,
      onChangePassword: () => Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => const ChangePasswordPage())),
      onLogout: () => _confirmLogout(context),
    );
  }
}
