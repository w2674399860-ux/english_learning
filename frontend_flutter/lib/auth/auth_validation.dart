import '../l10n/app_localizations.dart';

/// 账号表单校验（纯函数）。规则与后端 app/auth/passwords.py 一致；常见弱密码表只在后端判断。
/// 返回 null 表示通过，否则返回要显示在字段下方的文案。

/// 用户名只允许 ASCII 字母、数字、下划线（显式列出，排除 Unicode 形近字，与后端相同）。
final RegExp _usernamePattern = RegExp(r'^[A-Za-z0-9_]{3,20}$');

const int passwordMinLength = 8;
const int passwordMaxLength = 128;

/// 用户名去掉首尾空格后提交；后端统一存小写。密码不做任何处理。
String normalizeUsername(String raw) => raw.trim();

/// 长度按 Unicode 码点计算，与后端 Python 的 len() 一致（Dart 的 String.length 按 UTF-16 计算）。
int _codePoints(String s) => s.runes.length;

String? validateUsername(AppLocalizations l10n, String raw) {
  final username = normalizeUsername(raw);
  if (username.isEmpty) return l10n.validationUsernameRequired;
  if (!_usernamePattern.hasMatch(username)) {
    return l10n.validationUsernameInvalid;
  }
  return null;
}

/// 注册、修改密码时的新密码。[username] 为当前（或将要注册的）用户名。
String? validateNewPassword(
  AppLocalizations l10n,
  String password, {
  required String username,
}) {
  if (password.isEmpty) return l10n.validationPasswordRequired;
  final length = _codePoints(password);
  if (length < passwordMinLength) return l10n.validationPasswordTooShort;
  if (length > passwordMaxLength) return l10n.validationPasswordTooLong;
  final name = normalizeUsername(username);
  if (name.isNotEmpty && password.toLowerCase() == name.toLowerCase()) {
    return l10n.validationPasswordSameAsUsername;
  }
  return null;
}

String? validatePasswordConfirmation(
  AppLocalizations l10n,
  String password,
  String confirmation,
) {
  return password == confirmation ? null : l10n.validationPasswordMismatch;
}

/// 修改密码时的当前密码：只检查非空。
String? validateCurrentPassword(AppLocalizations l10n, String password) {
  return password.isEmpty ? l10n.validationCurrentPasswordRequired : null;
}

/// 新密码不能与当前密码相同（后端同样判断）。
String? validateNewDiffersFromCurrent(
  AppLocalizations l10n,
  String current,
  String next,
) {
  return current.isNotEmpty && current == next
      ? l10n.validationNewPasswordSameAsCurrent
      : null;
}

/// 登录只检查非空，不检查格式：后端对格式不合法的用户名同样返回"用户名或密码错误"。
String? validateLoginFields(
  AppLocalizations l10n,
  String username,
  String password,
) {
  if (normalizeUsername(username).isEmpty || password.isEmpty) {
    return l10n.loginEmptyFields;
  }
  return null;
}
