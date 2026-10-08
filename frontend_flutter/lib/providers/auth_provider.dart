import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../auth/auth_api.dart';
import '../auth/auth_validation.dart';
import '../auth/session.dart';
import '../auth/token_store.dart';
import '../services/api_response.dart';

/// 登录状态。AuthGate 按它决定显示启动页、启动失败页、登录页或首页。
enum AuthStatus { unknown, unauthenticated, authenticated, startupError }

/// 可以显示字段级错误的输入框。
enum AuthField { username, password, currentPassword }

enum _AuthAction { login, register, changePassword }

/// 后端没有给 Retry-After 时，429 后按钮禁用的时长。
const Duration _defaultRetryAfter = Duration(minutes: 1);

/// 账号状态（A-2 前端方案第 2 项）。依赖全部从构造函数注入，便于单元测试。
///
/// 登出、凭证失效时先同步清空内存会话，再依次调用 [onSignedOut]（清空 AppProvider 等），
/// 最后删除持久化的凭证。
class AuthProvider extends ChangeNotifier {
  AuthProvider({
    required AuthApi api,
    required TokenStore store,
    required AuthSession session,
    List<VoidCallback> onSignedOut = const [],
    DateTime Function()? clock,
  }) : _api = api,
       _store = store,
       _session = session,
       _onSignedOut = onSignedOut,
       _now = clock ?? DateTime.now;

  final AuthApi _api;
  final TokenStore _store;
  final AuthSession _session;
  final List<VoidCallback> _onSignedOut;
  final DateTime Function() _now;

  AuthStatus _status = AuthStatus.unknown;
  AuthUser? _user;
  bool _isSubmitting = false;
  String? _formError;
  Map<AuthField, String> _fieldErrors = const {};
  bool _sessionExpired = false;
  DateTime? _retryAt;
  Timer? _retryTimer;

  AuthStatus get status => _status;
  AuthUser? get user => _user;
  bool get isSubmitting => _isSubmitting;

  /// 表单顶部提示框的文案（后端 detail 或网络错误）。
  String? get formError => _formError;
  Map<AuthField, String> get fieldErrors => _fieldErrors;

  /// 是否因凭证失效被退回登录页（登录页顶部显示"登录已失效"）。
  bool get sessionExpired => _sessionExpired;

  /// 429 后在此时间之前禁用提交按钮。
  DateTime? get retryAt => _retryAt;
  bool get isRateLimited => _retryAt != null && _now().isBefore(_retryAt!);

  /// 启动时恢复登录状态。
  Future<void> restore() async {
    _setStatus(AuthStatus.unknown);

    StoredCredential? credential;
    try {
      credential = await _store.read();
    } catch (e) {
      // 存储读不出来（例如系统密钥变化）：当作未登录，不让 App 卡在启动页
      debugPrint('read credential failed: ${e.runtimeType}');
    }

    if (credential == null) {
      _setStatus(AuthStatus.unauthenticated);
      return;
    }
    if (!credential.expiresAt.isAfter(_now())) {
      await _clearStoredCredential();
      _sessionExpired = true;
      _setStatus(AuthStatus.unauthenticated);
      return;
    }

    _session.set(credential.token, credential.expiresAt);
    try {
      _user = await _api.me();
      _setStatus(AuthStatus.authenticated);
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        _session.clear();
        await _clearStoredCredential();
        _sessionExpired = true;
        _setStatus(AuthStatus.unauthenticated);
      } else {
        // 网络错误、超时、5xx：保留凭证，显示启动失败页（重试 / 退出登录）
        _setStatus(AuthStatus.startupError);
      }
    } catch (e) {
      debugPrint('restore failed: ${e.runtimeType}');
      _setStatus(AuthStatus.startupError);
    }
  }

  Future<bool> login(String username, String password) {
    return _submit(_AuthAction.login, () async {
      final result = await _api.login(normalizeUsername(username), password);
      await _establish(result);
    });
  }

  Future<bool> register(String username, String password) {
    return _submit(_AuthAction.register, () async {
      final result = await _api.register(normalizeUsername(username), password);
      await _establish(result);
    });
  }

  /// 修改密码。成功后后端让所有旧凭证失效，这里换上响应中的新凭证。
  Future<bool> changePassword(String oldPassword, String newPassword) {
    return _submit(_AuthAction.changePassword, () async {
      final result = await _api.changePassword(oldPassword, newPassword);
      _session.set(result.token, result.expiresAt);
      await _writeStoredCredential(result);
    });
  }

  /// 主动登出：先在本地退出（界面立刻回到登录页），再尽力通知后端让凭证失效，失败忽略。
  Future<void> logout() async {
    final token = _session.token;
    await _signOutLocally(expired: false);
    if (token == null) return;
    try {
      await _api.logout(token);
    } catch (e) {
      debugPrint('logout request failed: ${e.runtimeType}');
    }
  }

  /// 拦截器发现当前凭证失效（任一请求返回 401）时调用。重复调用无副作用。
  void handleUnauthorized() {
    if (_status != AuthStatus.authenticated) return;
    _signOutLocally(expired: true);
  }

  /// 切换登录 / 注册 / 修改密码页面时清掉上一页留下的错误。
  void clearErrors() {
    if (_formError == null && _fieldErrors.isEmpty) return;
    _formError = null;
    _fieldErrors = const {};
    notifyListeners();
  }

  Future<bool> _submit(_AuthAction action, Future<void> Function() run) async {
    if (_isSubmitting || isRateLimited) return false;
    _isSubmitting = true;
    _formError = null;
    _fieldErrors = const {};
    notifyListeners();

    try {
      await run();
      return true;
    } catch (e) {
      _applyError(action, e);
      return false;
    } finally {
      _isSubmitting = false;
      notifyListeners();
    }
  }

  void _applyError(_AuthAction action, Object e) {
    final status = e is DioException ? e.response?.statusCode : null;
    final message = errorMessage(e);
    if (status == 429) {
      _startRetryCountdown(retryAfterOf(e) ?? _defaultRetryAfter);
      _formError = message;
    } else if (status == 409 && action == _AuthAction.register) {
      _fieldErrors = {AuthField.username: message};
    } else if (status == 400 && action == _AuthAction.changePassword) {
      _fieldErrors = {AuthField.currentPassword: message};
    } else {
      // 登录 401（用户名或密码错误）、403（账号已停用）、422 规则错误、网络错误等
      _formError = message;
    }
  }

  void _startRetryCountdown(Duration wait) {
    _retryTimer?.cancel();
    _retryAt = _now().add(wait);
    _retryTimer = Timer(wait, () {
      _retryAt = null;
      notifyListeners();
    });
  }

  Future<void> _establish(AuthResult result) async {
    _session.set(result.token, result.expiresAt);
    await _writeStoredCredential(result);
    _user = result.user;
    _sessionExpired = false;
    _setStatus(AuthStatus.authenticated);
  }

  Future<void> _signOutLocally({required bool expired}) async {
    // 先同步清空内存会话：之后并发返回的 401 不再匹配当前凭证，不会重复触发
    _session.clear();
    _user = null;
    _sessionExpired = expired;
    _formError = null;
    _fieldErrors = const {};
    _status = AuthStatus.unauthenticated;
    for (final callback in _onSignedOut) {
      callback();
    }
    notifyListeners();
    await _clearStoredCredential();
  }

  Future<void> _writeStoredCredential(AuthResult result) async {
    try {
      await _store.write(
        StoredCredential(token: result.token, expiresAt: result.expiresAt),
      );
    } catch (e) {
      // 写不进存储只影响下次启动是否需要重新登录，本次照常使用
      debugPrint('write credential failed: ${e.runtimeType}');
    }
  }

  Future<void> _clearStoredCredential() async {
    try {
      await _store.clear();
    } catch (e) {
      debugPrint('clear credential failed: ${e.runtimeType}');
    }
  }

  void _setStatus(AuthStatus status) {
    _status = status;
    notifyListeners();
  }

  @override
  void dispose() {
    _retryTimer?.cancel();
    super.dispose();
  }
}
