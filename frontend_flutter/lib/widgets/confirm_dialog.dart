import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../theme/theme_x.dart';
import 'ink_button.dart';

/// 确认对话框（删除记录、登出）：顶部圆形图标块、标题、说明，左"取消"右危险按钮。
/// 点"确认"返回 true；点"取消"、点遮罩或按返回键返回 false。
Future<bool> showConfirmDialog(
  BuildContext context, {
  required String title,
  required String confirmLabel,
  String? message,
  IconData icon = Icons.delete_forever,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => _ConfirmDialog(
      title: title,
      message: message,
      confirmLabel: confirmLabel,
      icon: icon,
    ),
  );
  return result ?? false;
}

class _ConfirmDialog extends StatelessWidget {
  const _ConfirmDialog({
    required this.title,
    required this.message,
    required this.confirmLabel,
    required this.icon,
  });

  final String title;
  final String? message;
  final String confirmLabel;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final c = context.colors;

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: EdgeInsets.all(tokens.pageMargin),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: tokens.maxContentWidth),
        child: Container(
          padding: EdgeInsets.all(tokens.spaceLg),
          decoration: BoxDecoration(
            color: tokens.cardSurface,
            borderRadius: BorderRadius.circular(tokens.radiusMd),
            boxShadow: tokens.hardShadow(tokens.shadowDialog),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: tokens.iconTileLg,
                height: tokens.iconTileLg,
                decoration: BoxDecoration(
                  color: c.errorContainer,
                  shape: BoxShape.circle,
                  boxShadow: tokens.hardShadow(tokens.shadowSmall),
                ),
                child: Icon(icon, color: c.error, size: tokens.iconLg),
              ),
              SizedBox(height: tokens.spaceMd),
              Text(
                title,
                style: context.text.titleMedium,
                textAlign: TextAlign.center,
              ),
              if (message != null) ...[
                SizedBox(height: tokens.spaceSm),
                Text(
                  message!,
                  style: context.text.bodySmall?.copyWith(
                    color: c.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
              SizedBox(height: tokens.spaceLg),
              Row(
                children: [
                  Expanded(
                    child: InkButton(
                      label: context.l10n.commonCancel,
                      variant: InkButtonVariant.paper,
                      compact: true,
                      onPressed: () => Navigator.of(context).pop(false),
                    ),
                  ),
                  SizedBox(width: tokens.spaceMd),
                  Expanded(
                    child: InkButton(
                      label: confirmLabel,
                      variant: InkButtonVariant.danger,
                      compact: true,
                      onPressed: () => Navigator.of(context).pop(true),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
