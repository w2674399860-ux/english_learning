import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:english_learning_app/auth/auth_api.dart';
import 'package:english_learning_app/auth/auth_interceptor.dart';
import 'package:english_learning_app/auth/session.dart';
import 'package:flutter_test/flutter_test.dart';

/// 替换 Dio 的底层适配器：记录请求，按路径返回预设状态码；可以让响应等待，模拟并发。
class _FakeAdapter implements HttpClientAdapter {
  final List<RequestOptions> requests = [];
  final Map<String, int> statusByPath = {};
  Completer<void>? gate;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    if (gate != null) await gate!.future;
    final status = statusByPath[options.path] ?? 200;
    return ResponseBody.fromString(
      jsonEncode({'detail': 'x'}),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

/// 等到适配器收到 [count] 个请求（Dio 的拦截器链是异步的，一个微任务不够）。
Future<void> _waitForRequests(_FakeAdapter adapter, int count) async {
  for (var i = 0; i < 100 && adapter.requests.length < count; i++) {
    await Future<void>.delayed(const Duration(milliseconds: 1));
  }
}

void main() {
  late AuthSession session;
  late _FakeAdapter adapter;
  late Dio dio;
  late int unauthorizedCalls;

  setUp(() {
    session = AuthSession()
      ..set('t1', DateTime.now().add(const Duration(days: 1)));
    adapter = _FakeAdapter();
    unauthorizedCalls = 0;
    dio = Dio()..httpClientAdapter = adapter;
    dio.interceptors.add(
      AuthInterceptor(
        session: session,
        onUnauthorized: () {
          unauthorizedCalls++;
          // 与 AuthProvider.handleUnauthorized 一样：先同步清空会话
          session.clear();
        },
      ),
    );
  });

  test('附加 Authorization 头；凭证不出现在 URL 中', () async {
    await dio.get('/api/v1/history/records', queryParameters: {'page': 1});
    final request = adapter.requests.single;
    expect(request.headers['Authorization'], 'Bearer t1');
    expect(request.uri.toString(), isNot(contains('t1')));
  });

  test('没有凭证时不附加', () async {
    session.clear();
    await dio.get('/api/v1/history/records');
    expect(
      adapter.requests.single.headers.containsKey('Authorization'),
      isFalse,
    );
  });

  test('登录、注册（skipAuth）不附加凭证', () async {
    await dio.post(
      '/api/v1/auth/login',
      options: Options(extra: {skipAuthKey: true}),
    );
    expect(
      adapter.requests.single.headers.containsKey('Authorization'),
      isFalse,
    );
  });

  test('业务请求 401：回调一次，错误照常抛出', () async {
    adapter.statusByPath['/api/v1/learn/compose'] = 401;
    await expectLater(
      dio.post('/api/v1/learn/compose'),
      throwsA(isA<DioException>()),
    );
    expect(unauthorizedCalls, 1);
  });

  test('3 个并发请求同时 401：只回调一次', () async {
    adapter.statusByPath
      ..['/a'] = 401
      ..['/b'] = 401
      ..['/c'] = 401;
    adapter.gate = Completer<void>();
    final futures = [
      for (final path in ['/a', '/b', '/c'])
        dio.get(path).then((_) => null, onError: (_) => null),
    ];
    // 三个请求都已带着 t1 发出，再一起返回 401
    await _waitForRequests(adapter, 3);
    expect(adapter.requests, hasLength(3));
    adapter.gate!.complete();
    await Future.wait(futures);
    expect(unauthorizedCalls, 1);
  });

  test('登录接口的 401（用户名或密码错误）不触发', () async {
    adapter.statusByPath['/api/v1/auth/login'] = 401;
    await expectLater(
      dio.post(
        '/api/v1/auth/login',
        options: Options(extra: {skipAuthKey: true}),
      ),
      throwsA(isA<DioException>()),
    );
    expect(unauthorizedCalls, 0);
  });

  test('重新登录后，旧凭证请求晚到的 401 不会踢掉新会话', () async {
    adapter.statusByPath['/slow'] = 401;
    adapter.gate = Completer<void>();
    final old = dio.get('/slow').then((_) => null, onError: (_) => null);
    await _waitForRequests(adapter, 1);
    expect(adapter.requests.single.headers['Authorization'], 'Bearer t1');
    // 期间重新登录，换了新凭证
    session.set('t2', DateTime.now().add(const Duration(days: 1)));
    adapter.gate!.complete();
    await old;
    expect(unauthorizedCalls, 0);
    expect(session.token, 't2');
  });

  test('DioAuthApi.logout 显式携带传入的凭证且不触发回调', () async {
    session.clear();
    adapter.statusByPath['/api/v1/auth/logout'] = 401;
    final api = DioAuthApi(dio);
    await expectLater(api.logout('old-token'), throwsA(isA<DioException>()));
    expect(
      adapter.requests.single.headers['Authorization'],
      'Bearer old-token',
    );
    expect(unauthorizedCalls, 0);
  });
}
