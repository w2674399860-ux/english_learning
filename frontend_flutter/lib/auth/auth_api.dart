import 'package:dio/dio.dart';

import '../config/api_config.dart';
import 'auth_interceptor.dart';

/// 当前用户（GET /auth/me、登录注册响应中的 user）。
class AuthUser {
  const AuthUser({required this.id, required this.username});

  final int id;

  /// 后端统一存小写。
  final String username;

  factory AuthUser.fromJson(Map<String, dynamic> json) =>
      AuthUser(id: json['id'] as int, username: json['username'] as String);
}

/// 登录、注册、修改密码返回的凭证。修改密码的响应没有 user。
class AuthResult {
  const AuthResult({required this.token, required this.expiresAt, this.user});

  final String token;
  final DateTime expiresAt;
  final AuthUser? user;

  factory AuthResult.fromJson(Map<String, dynamic> json) {
    final user = json['user'];
    return AuthResult(
      token: json['token'] as String,
      expiresAt: DateTime.parse(json['expires_at'] as String),
      user: user is Map<String, dynamic> ? AuthUser.fromJson(user) : null,
    );
  }
}

/// 账号接口。AuthProvider 只依赖这个抽象，测试时注入假实现。
abstract class AuthApi {
  Future<AuthResult> register(String username, String password);
  Future<AuthResult> login(String username, String password);

  /// 让 [token] 失效。显式传入凭证：调用时本地会话已经清空（先退出、再通知后端）。
  Future<void> logout(String token);
  Future<AuthUser> me();
  Future<AuthResult> changePassword(String oldPassword, String newPassword);
}

/// 启动时检查凭证、登出都不应让用户等太久（A-2 前端方案第 2 项）。
const Duration meTimeout = Duration(seconds: 10);
const Duration logoutTimeout = Duration(seconds: 5);

class DioAuthApi implements AuthApi {
  DioAuthApi(this._dio);

  final Dio _dio;

  /// 登录、注册不附加凭证；其 401 也不触发全局"登录已失效"。
  static final Options _public = Options(extra: {skipAuthKey: true});

  @override
  Future<AuthResult> register(String username, String password) async {
    final response = await _dio.post(
      ApiConfig.authRegister,
      data: {'username': username, 'password': password},
      options: _public,
    );
    return AuthResult.fromJson(response.data as Map<String, dynamic>);
  }

  @override
  Future<AuthResult> login(String username, String password) async {
    final response = await _dio.post(
      ApiConfig.authLogin,
      data: {'username': username, 'password': password},
      options: _public,
    );
    return AuthResult.fromJson(response.data as Map<String, dynamic>);
  }

  @override
  Future<void> logout(String token) async {
    await _dio.post(
      ApiConfig.authLogout,
      options: Options(
        extra: {skipAuthKey: true},
        headers: {'Authorization': 'Bearer $token'},
        sendTimeout: logoutTimeout,
        receiveTimeout: logoutTimeout,
      ),
    );
  }

  @override
  Future<AuthUser> me() async {
    final response = await _dio.get(
      ApiConfig.authMe,
      options: Options(sendTimeout: meTimeout, receiveTimeout: meTimeout),
    );
    return AuthUser.fromJson(response.data as Map<String, dynamic>);
  }

  @override
  Future<AuthResult> changePassword(
    String oldPassword,
    String newPassword,
  ) async {
    final response = await _dio.post(
      ApiConfig.authChangePassword,
      data: {'old_password': oldPassword, 'new_password': newPassword},
    );
    return AuthResult.fromJson(response.data as Map<String, dynamic>);
  }
}
