import 'package:dio/dio.dart';

import 'session.dart';

/// 请求 extra 中设为 true：不附加凭证，401 也不触发登出（登录、注册、登出）。
const String skipAuthKey = 'skipAuth';

/// 记录这次请求实际使用的凭证，用于判断 401 是否针对当前会话。
const String _usedTokenKey = 'authToken';

/// 统一附加凭证、统一处理 401（A-2 前端方案第 5 项）。
///
/// 只有同时满足以下条件的 401 才回调 [onUnauthorized]：
/// 不是登录等公开接口；请求带了凭证；该凭证等于当前会话的凭证。
/// 第一个 401 进来时会话立刻被清空，之后并发返回的 401 不再满足最后一条，
/// 所以多个请求同时 401 只会跳转一次；重新登录后旧凭证的 401 也不会把新会话踢掉。
/// 错误本身照常往下传。凭证只放在请求头里，不写日志。
class AuthInterceptor extends Interceptor {
  AuthInterceptor({required this.session, required this.onUnauthorized});

  final AuthSession session;
  final void Function() onUnauthorized;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (options.extra[skipAuthKey] != true) {
      final token = session.token;
      if (token != null) {
        options.headers['Authorization'] = 'Bearer $token';
        options.extra[_usedTokenKey] = token;
      }
    }
    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final options = err.requestOptions;
    final usedToken = options.extra[_usedTokenKey];
    if (err.response?.statusCode == 401 &&
        options.extra[skipAuthKey] != true &&
        usedToken != null &&
        usedToken == session.token) {
      onUnauthorized();
    }
    handler.next(err);
  }
}
