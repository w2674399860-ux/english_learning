import 'package:english_learning_app/auth/session.dart';
import 'package:english_learning_app/auth/token_store.dart';
import 'package:english_learning_app/providers/auth_provider.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fake_auth_api.dart';

class _Harness {
  _Harness({StoredCredential? stored}) : store = InMemoryTokenStore(stored) {
    auth = AuthProvider(
      api: api,
      store: store,
      session: session,
      onSignedOut: [() => signedOutCalls++],
    );
  }

  final FakeAuthApi api = FakeAuthApi();
  final InMemoryTokenStore store;
  final AuthSession session = AuthSession();
  late final AuthProvider auth;
  int signedOutCalls = 0;
}

StoredCredential _valid([String token = 'stored']) => StoredCredential(
  token: token,
  expiresAt: DateTime.now().add(const Duration(days: 3)),
);

void main() {
  group('restore', () {
    test('没有凭证：未登录，不请求后端', () async {
      final h = _Harness();
      await h.auth.restore();
      expect(h.auth.status, AuthStatus.unauthenticated);
      expect(h.api.calls, isEmpty);
      expect(h.auth.sessionExpired, isFalse);
    });

    test('凭证已过期：清除并提示登录已失效，不请求后端', () async {
      final h = _Harness(
        stored: StoredCredential(
          token: 'old',
          expiresAt: DateTime.now().subtract(const Duration(minutes: 1)),
        ),
      );
      await h.auth.restore();
      expect(h.auth.status, AuthStatus.unauthenticated);
      expect(h.auth.sessionExpired, isTrue);
      expect(await h.store.read(), isNull);
      expect(h.api.calls, isEmpty);
    });

    test('凭证有效：/me 成功后已登录，会话中有凭证', () async {
      final h = _Harness(stored: _valid());
      await h.auth.restore();
      expect(h.auth.status, AuthStatus.authenticated);
      expect(h.auth.user!.username, 'mia_2026');
      expect(h.session.token, 'stored');
    });

    test('/me 返回 401：清除凭证并提示登录已失效', () async {
      final h = _Harness(stored: _valid());
      h.api.meError = httpError(401, detail: '登录已失效，请重新登录');
      await h.auth.restore();
      expect(h.auth.status, AuthStatus.unauthenticated);
      expect(h.auth.sessionExpired, isTrue);
      expect(h.session.token, isNull);
      expect(await h.store.read(), isNull);
    });

    test('/me 网络错误：进入启动失败页，保留凭证；重试成功后已登录', () async {
      final h = _Harness(stored: _valid());
      h.api.meError = connectionError();
      await h.auth.restore();
      expect(h.auth.status, AuthStatus.startupError);
      expect(await h.store.read(), isNotNull);

      h.api.meError = null;
      await h.auth.restore();
      expect(h.auth.status, AuthStatus.authenticated);
    });
  });

  group('login / register', () {
    test('登录成功：写入存储与会话，用户名去掉首尾空格后提交', () async {
      final h = _Harness();
      await h.auth.restore();
      expect(await h.auth.login('  mia_2026 ', 'river-stone-42'), isTrue);
      expect(h.api.calls.last, 'login:mia_2026');
      expect(h.auth.status, AuthStatus.authenticated);
      expect(h.session.token, isNotNull);
      expect((await h.store.read())!.token, h.session.token);
    });

    test('登录 401 / 403：提示框显示后端文案，不写入凭证', () async {
      final h = _Harness();
      await h.auth.restore();
      h.api.loginError = httpError(401, detail: '用户名或密码错误');
      expect(await h.auth.login('mia', 'wrong-pass'), isFalse);
      expect(h.auth.formError, '用户名或密码错误');
      expect(h.auth.status, AuthStatus.unauthenticated);
      expect(await h.store.read(), isNull);

      h.api.loginError = httpError(403, detail: '账号已停用，请联系管理员');
      await h.auth.login('mia', 'right-pass');
      expect(h.auth.formError, '账号已停用，请联系管理员');
    });

    test('登录成功会清掉"登录已失效"提示', () async {
      final h = _Harness(
        stored: StoredCredential(token: 'old', expiresAt: DateTime(2000)),
      );
      await h.auth.restore();
      expect(h.auth.sessionExpired, isTrue);
      await h.auth.login('mia', 'river-stone-42');
      expect(h.auth.sessionExpired, isFalse);
    });

    test('注册 409：错误显示在用户名字段；422 显示在提示框', () async {
      final h = _Harness();
      await h.auth.restore();
      h.api.registerError = httpError(409, detail: '用户名已被注册');
      expect(await h.auth.register('mia', 'river-stone-42'), isFalse);
      expect(h.auth.fieldErrors[AuthField.username], '用户名已被注册');
      expect(h.auth.formError, isNull);

      h.api.registerError = httpError(422, detail: '密码过于简单，请换一个');
      await h.auth.register('mia', 'password123');
      expect(h.auth.formError, '密码过于简单，请换一个');
      expect(h.auth.fieldErrors, isEmpty);
    });

    test('429：提示框显示后端文案，按 Retry-After 禁用提交，期间再提交直接返回 false', () async {
      final h = _Harness();
      await h.auth.restore();
      h.api.loginError = httpError(
        429,
        detail: '登录尝试过于频繁（每 10 分钟 10 次），请 8 分钟后再试',
        headers: {
          'retry-after': ['480'],
        },
      );
      await h.auth.login('mia', 'x' * 8);
      expect(h.auth.isRateLimited, isTrue);
      expect(h.auth.formError, contains('过于频繁'));
      final wait = h.auth.retryAt!.difference(DateTime.now()).inSeconds;
      expect(wait, inInclusiveRange(470, 480));

      h.api.calls.clear();
      expect(await h.auth.login('mia', 'x' * 8), isFalse);
      expect(h.api.calls, isEmpty);
      h.auth.dispose(); // 取消 Retry-After 计时器
    });
  });

  group('logout / handleUnauthorized', () {
    test('登出：先本地退出（回调一次），再用原凭证通知后端', () async {
      final h = _Harness(stored: _valid('t1'));
      await h.auth.restore();
      await h.auth.logout();
      expect(h.auth.status, AuthStatus.unauthenticated);
      expect(h.auth.sessionExpired, isFalse);
      expect(h.signedOutCalls, 1);
      expect(h.session.token, isNull);
      expect(await h.store.read(), isNull);
      expect(h.api.lastLogoutToken, 't1');
    });

    test('登出接口失败也完成本地退出', () async {
      final h = _Harness(stored: _valid());
      await h.auth.restore();
      h.api.logoutError = connectionError();
      await h.auth.logout();
      expect(h.auth.status, AuthStatus.unauthenticated);
      expect(await h.store.read(), isNull);
    });

    test('凭证失效：提示登录已失效；重复调用只回调一次', () async {
      final h = _Harness(stored: _valid());
      await h.auth.restore();
      h.auth.handleUnauthorized();
      h.auth.handleUnauthorized();
      h.auth.handleUnauthorized();
      expect(h.auth.status, AuthStatus.unauthenticated);
      expect(h.auth.sessionExpired, isTrue);
      expect(h.signedOutCalls, 1);
      expect(h.session.token, isNull);
    });

    test(
      '未登录时 handleUnauthorized 无副作用（启动时 /me 的 401 由 restore 自己处理）',
      () async {
        final h = _Harness();
        await h.auth.restore();
        h.auth.handleUnauthorized();
        expect(h.signedOutCalls, 0);
        expect(h.auth.sessionExpired, isFalse);
      },
    );
  });

  group('changePassword', () {
    test('成功：换上新凭证（会话与存储都更新）', () async {
      final h = _Harness(stored: _valid('old-token'));
      await h.auth.restore();
      expect(await h.auth.changePassword('old-pass-1', 'new-pass-1'), isTrue);
      expect(h.session.token, isNot('old-token'));
      expect((await h.store.read())!.token, h.session.token);
      expect(h.auth.status, AuthStatus.authenticated);
      expect(h.auth.user!.username, 'mia_2026');
    });

    test('400 原密码不正确：显示在当前密码字段，凭证不变', () async {
      final h = _Harness(stored: _valid('old-token'));
      await h.auth.restore();
      h.api.changePasswordError = httpError(400, detail: '当前密码不正确');
      expect(await h.auth.changePassword('wrong', 'new-pass-1'), isFalse);
      expect(h.auth.fieldErrors[AuthField.currentPassword], '当前密码不正确');
      expect(h.session.token, 'old-token');
    });
  });

  test('clearErrors 清掉提示框与字段错误', () async {
    final h = _Harness();
    await h.auth.restore();
    h.api.registerError = httpError(409, detail: '用户名已被注册');
    await h.auth.register('mia', 'river-stone-42');
    h.auth.clearErrors();
    expect(h.auth.fieldErrors, isEmpty);
    expect(h.auth.formError, isNull);
  });
}
