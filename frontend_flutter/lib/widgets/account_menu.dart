import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../theme/theme_x.dart';

enum _AccountAction { changePassword, logout }

/// 顶栏右侧的账户菜单（设计稿 ai_3 / ai_4）：圆形头像，展开后显示用户名、修改密码、登出。
/// 只放在首页和历史两个 Tab 页（Q-F14）。登出的确认对话框由调用方负责。
class AccountMenu extends StatelessWidget {
  const AccountMenu({
    super.key,
    required this.username,
    required this.onChangePassword,
    required this.onLogout,
  });

  final String username;
  final VoidCallback onChangePassword;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final c = context.colors;
    final l10n = context.l10n;

    PopupMenuItem<_AccountAction> item(
      _AccountAction value,
      IconData icon,
      String label,
      Color color,
    ) {
      return PopupMenuItem(
        value: value,
        child: Row(
          children: [
            Icon(icon, size: tokens.iconMd, color: color),
            SizedBox(width: tokens.spaceSm),
            Text(
              label,
              style: context.text.labelMedium?.copyWith(color: color),
            ),
          ],
        ),
      );
    }

    return PopupMenuButton<_AccountAction>(
      tooltip: l10n.accountMenu,
      position: PopupMenuPosition.under,
      onSelected: (action) {
        switch (action) {
          case _AccountAction.changePassword:
            onChangePassword();
          case _AccountAction.logout:
            onLogout();
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem<_AccountAction>(
          enabled: false,
          child: Row(
            children: [
              Icon(Icons.auto_stories, size: tokens.iconMd, color: c.secondary),
              SizedBox(width: tokens.spaceSm),
              Flexible(
                child: Text(
                  username,
                  style: context.text.labelMedium?.copyWith(color: c.onSurface),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        const PopupMenuDivider(),
        item(
          _AccountAction.changePassword,
          Icons.lock_reset,
          l10n.accountChangePassword,
          c.onSurfaceVariant,
        ),
        item(_AccountAction.logout, Icons.logout, l10n.accountLogout, c.error),
      ],
      child: SizedBox.square(
        dimension: tokens.minTouchTarget,
        child: Center(
          child: Container(
            width: tokens.avatarSize,
            height: tokens.avatarSize,
            decoration: BoxDecoration(color: c.primary, shape: BoxShape.circle),
            child: Icon(Icons.person, size: tokens.iconMd, color: c.onPrimary),
          ),
        ),
      ),
    );
  }
}
