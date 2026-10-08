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
import '../../widgets/tip_card.dart';
import 'auth_widgets.dart';
import 'register_page.dart';

/// 登录页（设计稿 ai_7）。未登录时由 AuthGate 显示，没有底部导航栏。
///
/// 状态：默认、必填项为空、提交中、登录失败 / 账号停用 / 网络错误（提示框）、
/// 登录过于频繁（按钮倒计时）、登录已失效（顶部提示）。
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _username = TextEditingController();
  final _password = TextEditingController();

  /// 本地校验的错误（必填项为空）；后端错误在 AuthProvider.formError。
  String? _localError;

  @override
  void initState() {
    super.initState();
    // 从注册页返回等情况：清掉上一页留下的错误
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<AuthProvider>().clearErrors();
    });
  }

  @override
  void dispose() {
    _username.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final auth = context.read<AuthProvider>();
    final error = validateLoginFields(
      context.l10n,
      _username.text,
      _password.text,
    );
    setState(() => _localError = error);
    if (error != null) {
      auth.clearErrors();
      return;
    }
    final ok = await auth.login(_username.text, _password.text);
    // 让系统密码管理器保存这次成功的登录；之后 AuthGate 切换到首页
    if (ok) TextInput.finishAutofillContext();
  }

  void _openRegister() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const RegisterPage()));
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final c = context.colors;
    final l10n = context.l10n;
    final auth = context.watch<AuthProvider>();
    final busy = auth.isSubmitting;
    final error = _localError ?? auth.formError;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(tokens.pageMargin),
          child: ContentWidth(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (auth.sessionExpired) ...[
                  TipCard(body: l10n.loginSessionExpired, icon: Icons.info),
                  SizedBox(height: tokens.spaceLg),
                ],
                Center(
                  child: Illustration(
                    kind: IllustrationKind.mascot,
                    size: tokens.illustrationSizeSm,
                  ),
                ),
                SizedBox(height: tokens.spaceSm),
                Text(
                  l10n.appTitle,
                  textAlign: TextAlign.center,
                  style: context.text.displayMedium?.copyWith(color: c.primary),
                ),
                SizedBox(height: tokens.spaceXl),
                InkCard(
                  padding: EdgeInsets.all(tokens.spaceXl),
                  child: AutofillGroup(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        AuthCardTitle(title: l10n.loginTitle),
                        SizedBox(height: tokens.spaceXl),
                        InkTextField(
                          label: l10n.usernameLabel,
                          icon: Icons.account_circle,
                          hint: l10n.usernameHint,
                          controller: _username,
                          enabled: !busy,
                          textInputAction: TextInputAction.next,
                          autofillHints: const [AutofillHints.username],
                        ),
                        SizedBox(height: tokens.spaceLg),
                        InkTextField(
                          label: l10n.passwordLabel,
                          icon: Icons.lock,
                          hint: l10n.passwordHint,
                          controller: _password,
                          isPassword: true,
                          enabled: !busy,
                          textInputAction: TextInputAction.done,
                          autofillHints: const [AutofillHints.password],
                          onSubmitted: (_) => _submit(),
                        ),
                        if (error != null) ...[
                          SizedBox(height: tokens.spaceLg),
                          ErrorNotice(message: error),
                        ],
                        SizedBox(height: tokens.spaceXl),
                        AuthSubmitButton(
                          label: l10n.loginButton,
                          trailingIcon: Icons.arrow_circle_right,
                          isLoading: busy,
                          retryAt: auth.retryAt,
                          onPressed: _submit,
                        ),
                        SizedBox(height: tokens.spaceSm),
                        AuthSwitchLink(
                          prompt: l10n.loginNoAccount,
                          action: l10n.loginGoRegister,
                          onPressed: busy ? null : _openRegister,
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: tokens.spaceXl),
                Center(
                  child: _ForgotPasswordHint(text: l10n.loginForgotPassword),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// "忘记密码？请联系管理员重置。"——只是提示，不是可点击的找回流程（A1）。
class _ForgotPasswordHint extends StatelessWidget {
  const _ForgotPasswordHint({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final c = context.colors;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: tokens.spaceLg,
        vertical: tokens.spaceSm,
      ),
      decoration: BoxDecoration(
        color: c.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(tokens.radiusLg),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.vpn_key, size: tokens.iconSm, color: c.tertiary),
          SizedBox(width: tokens.spaceSm),
          Flexible(
            child: Text(
              text,
              style: context.text.bodySmall?.copyWith(
                color: c.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
