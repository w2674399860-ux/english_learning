import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../auth/auth_validation.dart';
import '../../l10n/l10n.dart';
import '../../providers/auth_provider.dart';
import '../../theme/theme_x.dart';
import '../../widgets/error_notice.dart';
import '../../widgets/illustration.dart';
import '../../widgets/ink_card.dart';
import '../../widgets/ink_text_field.dart';
import '../../widgets/page_scaffold.dart';
import 'auth_widgets.dart';

/// 注册页（设计稿 ai_6）。注册即登录：成功后 AuthGate 切到首页并关闭本页。
///
/// 状态：默认、字段错误（用户名格式 / 已被注册、密码规则、两次不一致）、
/// 提交中、提示框（密码过于简单、网络错误等）、注册过于频繁（按钮倒计时）。
class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _username = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();

  String? _usernameError;
  String? _passwordError;
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
    _username.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final l10n = context.l10n;
    final auth = context.read<AuthProvider>();
    setState(() {
      _usernameError = validateUsername(l10n, _username.text);
      _passwordError = validateNewPassword(
        l10n,
        _password.text,
        username: _username.text,
      );
      _confirmError = _passwordError == null
          ? validatePasswordConfirmation(l10n, _password.text, _confirm.text)
          : null;
    });
    if (_usernameError != null ||
        _passwordError != null ||
        _confirmError != null) {
      auth.clearErrors();
      return;
    }
    final ok = await auth.register(_username.text, _password.text);
    if (ok) TextInput.finishAutofillContext();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final l10n = context.l10n;
    final auth = context.watch<AuthProvider>();
    final busy = auth.isSubmitting;

    return Scaffold(
      appBar: AppBar(),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(tokens.pageMargin),
        child: ContentWidth(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Illustration(
                    kind: IllustrationKind.mascot,
                    size: tokens.illustrationSizeXs,
                  ),
                  SizedBox(width: tokens.spaceMd),
                  Expanded(
                    child: Text(
                      l10n.registerTitle,
                      style: context.text.headlineLarge,
                    ),
                  ),
                ],
              ),
              SizedBox(height: tokens.spaceLg),
              InkCard(
                padding: EdgeInsets.all(tokens.spaceXl),
                child: AutofillGroup(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      InkTextField(
                        label: l10n.usernameLabel,
                        icon: Icons.face,
                        hint: l10n.usernameHint,
                        helper: l10n.usernameRule,
                        errorText:
                            _usernameError ??
                            auth.fieldErrors[AuthField.username],
                        controller: _username,
                        enabled: !busy,
                        textInputAction: TextInputAction.next,
                        autofillHints: const [AutofillHints.newUsername],
                      ),
                      SizedBox(height: tokens.spaceLg),
                      InkTextField(
                        label: l10n.passwordLabel,
                        icon: Icons.lock,
                        hint: l10n.passwordHint,
                        helper: l10n.passwordRule,
                        errorText: _passwordError,
                        controller: _password,
                        isPassword: true,
                        enabled: !busy,
                        textInputAction: TextInputAction.next,
                        autofillHints: const [AutofillHints.newPassword],
                      ),
                      SizedBox(height: tokens.spaceLg),
                      InkTextField(
                        label: l10n.confirmPasswordLabel,
                        icon: Icons.verified_user,
                        hint: l10n.confirmPasswordHint,
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
                        label: l10n.registerButton,
                        leadingIcon: Icons.menu_book,
                        isLoading: busy,
                        retryAt: auth.retryAt,
                        onPressed: _submit,
                      ),
                      SizedBox(height: tokens.spaceSm),
                      AuthSwitchLink(
                        prompt: l10n.registerHaveAccount,
                        action: l10n.registerGoLogin,
                        onPressed: busy
                            ? null
                            : () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
