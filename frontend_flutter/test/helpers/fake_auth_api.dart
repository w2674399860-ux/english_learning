import 'dart:async';

import 'package:dio/dio.dart';
import 'package:english_learning_app/auth/auth_api.dart';

/// 构造一个带状态码与 detail 的 DioException（模拟后端错误响应）。
DioException httpError(
  int status, {
  Object? detail,
  Map<String, List<String>>? headers,
}) {
  final options = RequestOptions(path: '/x');
  return DioException(
    requestOptions: options,
    type: DioExceptionType.badResponse,
    response: Response(
      requestOptions: options,
      statusCode: status,
      data: detail == null ? null : {'detail': detail},
      headers: Headers.fromMap(headers ?? const {}),
    ),
  );
}

DioException connectionError() => DioException(
  requestOptions: RequestOptions(path: '/x'),
  type: DioExceptionType.connectionError,
);

/// 手写的假 AuthApi：每个方法的结果可以预先设置，并记录调用。不引入 mockito。
class FakeAuthApi implements AuthApi {
  FakeAuthApi({this.user = const AuthUser(id: 1, username: 'mia_2026')});

  AuthUser user;

  /// 设置后，对应方法抛出该异常。
  Object? loginError;
  Object? registerError;
  Object? meError;
  Object? logoutError;
  Object? changePasswordError;

  /// 设置后，login 会等待它完成（用于测试"提交中"状态）。
  Completer<void>? loginGate;

  final List<String> calls = [];
  String? lastLogoutToken;
  int _tokenSeq = 0;

  AuthResult _issue({bool withUser = true}) => AuthResult(
    token: 'token-${++_tokenSeq}',
    expiresAt: DateTime.now().add(const Duration(days: 30)),
    user: withUser ? user : null,
  );

  @override
  Future<AuthResult> login(String username, String password) async {
    calls.add('login:$username');
    if (loginGate != null) await loginGate!.future;
    if (loginError != null) throw loginError!;
    return _issue();
  }

  @override
  Future<AuthResult> register(String username, String password) async {
    calls.add('register:$username');
    if (registerError != null) throw registerError!;
    return _issue();
  }

  @override
  Future<void> logout(String token) async {
    calls.add('logout');
    lastLogoutToken = token;
    if (logoutError != null) throw logoutError!;
  }

  @override
  Future<AuthUser> me() async {
    calls.add('me');
    if (meError != null) throw meError!;
    return user;
  }

  @override
  Future<AuthResult> changePassword(
    String oldPassword,
    String newPassword,
  ) async {
    calls.add('changePassword');
    if (changePasswordError != null) throw changePasswordError!;
    return _issue(withUser: false);
  }
}
