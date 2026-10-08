import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../auth/auth_validation.dart';
import '../../l10n/l10n.dart';
import '../../providers/auth_provider.dart';
import '../../theme/theme_x.dart';
import '../../widgets/error_notice.dart';
import '../../widgets/ink_card.dart';
import '../../widgets/ink_text_field.dart';
import '../../widgets/ink_toast.dart';
import '../../widgets/page_scaffold.dart';
import '../../widgets/tip_card.dart';
import 'auth_widgets.dart';

/// 修改密码页（设计稿 ai_5）。从首页 / 历史页的账户菜单进入。
///
/// 状态：默认、字段错误（当前密码为空或不正确、新密码规则、新旧相同、两次不一致）、
/// 提交中、提示框（密码过于简单、网络错误等）、尝试过于频繁（按钮倒计时）、
/// 成功（Toast"密码已修改。"后返回上一页）。
class ChangePasswordPage extends StatefulWidget {
  const ChangePasswordPage({super.key});

  @override
  State<ChangePasswordPage> createState() => _ChangePasswordPageState();
}

class _ChangePasswordPageState extends State<ChangePasswordPage> {
  final _current = TextEditingController();
  final _next = TextEditingController();
  final _confirm = TextEditingController();

  String? _currentError;
  String? _nextError;
  String? _confirmError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<AuthProvider>().clearErrors();
    });
  }

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final l10n = context.l10n;
    final auth = context.read<AuthProvider>();
    final username = auth.user?.username ?? '';
    setState(() {
      _currentError = validateCurrentPassword(l10n, _current.text);
      _nextError =
          validateNewPassword(l10n, _next.text, username: username) ??
          validateNewDiffersFromCurrent(l10n, _current.text, _next.text);
      _confirmError = _nextError == null
          ? validatePasswordConfirmation(l10n, _next.text, _confirm.text)
          : null;
    });
    if (_currentError != null || _nextError != null || _confirmError != null) {
      auth.clearErrors();
      return;
    }
    final ok = await auth.changePassword(_current.text, _next.text);
    if (!ok || !mounted) return;
    showInkToast(context, l10n.changePasswordSuccess);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final c = context.colors;
    final l10n = context.l10n;
    final auth = context.watch<AuthProvider>();
    final busy = auth.isSubmitting;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.changePasswordTitle)),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(tokens.pageMargin),
        child: ContentWidth(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              InkCard(
                child: Row(
                  children: [
                    Container(
                      width: tokens.iconTileLg,
                      height: tokens.iconTileLg,
                      decoration: BoxDecoration(
                        color: c.primaryFixed,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.face_6,
                        color: c.onPrimaryFixed,
                        size: tokens.iconLg,
                      ),
                    ),
                    SizedBox(width: tokens.spaceMd),
                    Expanded(
                      child: Text(
                        l10n.changePasswordAccount(auth.user?.username ?? ''),
                        style: context.text.titleMedium,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: tokens.spaceLg),
              InkCard(
                padding: EdgeInsets.all(tokens.spaceXl),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AuthCardTitle(
                      title: l10n.changePasswordCardTitle,
                      large: false,
                    ),
                    SizedBox(height: tokens.spaceXl),
                    InkTextField(
                      label: l10n.currentPasswordLabel,
                      icon: Icons.key,
                      hint: l10n.currentPasswordHint,
                      errorText:
                          _currentError ??
                          auth.fieldErrors[AuthField.currentPassword],
                      controller: _current,
                      isPassword: true,
                      enabled: !busy,
                      textInputAction: TextInputAction.next,
                      autofillHints: const [AutofillHints.password],
                    ),
                    SizedBox(height: tokens.spaceLg),
                    InkTextField(
                      label: l10n.newPasswordLabel,
                      icon: Icons.lock,
                      hint: l10n.newPasswordHint,
                      helper: l10n.passwordRule,
                      errorText: _nextError,
                      controller: _next,
                      isPassword: true,
                      enabled: !busy,
                      textInputAction: TextInputAction.next,
                      autofillHints: const [AutofillHints.newPassword],
                    ),
                    SizedBox(height: tokens.spaceLg),
                    InkTextField(
                      label: l10n.confirmNewPasswordLabel,
                      icon: Icons.verified,
                      hint: l10n.confirmNewPasswordHint,
                      errorText: _confirmError,
                      controller: _confirm,
                      isPassword: true,
                      enabled: !busy,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _submit(),
                    ),
                    if (auth.formError != null) ...[
                      SizedBox(height: tokens.spaceLg),
                      ErrorNotice(message: auth.formError!),
                    ],
                    SizedBox(height: tokens.spaceXl),
                    AuthSubmitButton(
                      label: l10n.changePasswordSave,
                      leadingIcon: Icons.check_circle,
                      isLoading: busy,
                      retryAt: auth.retryAt,
                      onPressed: _submit,
                    ),
                  ],
                ),
              ),
              SizedBox(height: tokens.spaceLg),
              TipCard(title: l10n.securityTipTitle, body: l10n.securityTipBody),
            ],
          ),
        ),
      ),
    );
  }
}
