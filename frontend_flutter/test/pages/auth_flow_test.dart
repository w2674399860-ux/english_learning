import 'dart:async';

import 'package:english_learning_app/auth/token_store.dart';
import 'package:english_learning_app/main.dart';
import 'package:english_learning_app/pages/auth/auth_gate.dart';
import 'package:english_learning_app/pages/auth/change_password_page.dart';
import 'package:english_learning_app/pages/auth/login_page.dart';
import 'package:english_learning_app/pages/auth/register_page.dart';
import 'package:english_learning_app/pages/home/home_page.dart';
import 'package:english_learning_app/providers/auth_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import '../helpers/fake_auth_api.dart';

/// 启动整个 App（真实的 AuthGate、页面与 AuthProvider），只把账号接口和存储换成假的。
/// 不切到历史 Tab：HistoryPage 会请求真实后端。
Future<FakeAuthApi> _pumpApp(
  WidgetTester tester, {
  StoredCredential? stored,
  FakeAuthApi? api,
}) async {
  await tester.binding.setSurfaceSize(const Size(420, 1400));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final fake = api ?? FakeAuthApi();
  await tester.pumpWidget(
    MyApp(authApi: fake, tokenStore: InMemoryTokenStore(stored)),
  );
  await tester.pump();
  await tester.pump();
  return fake;
}

StoredCredential _valid() => StoredCredential(
  token: 'stored',
  expiresAt: DateTime.now().add(const Duration(days: 3)),
);

AuthProvider _auth(WidgetTester tester) => Provider.of<AuthProvider>(
  tester.element(find.byType(AuthGate)),
  listen: false,
);

/// 按占位文字找输入框；注册页压在登录页之上时两页都有"请输入用户名"，取最上层的。
Finder _field(String hint) => find.widgetWithText(TextField, hint).last;

/// 输入框下方显示的错误文字（错误文字可能与占位文字相同，所以从 decoration 读取）。
String? _errorOf(WidgetTester tester, String hint) =>
    tester.widget<TextField>(_field(hint)).decoration!.errorText;

/// 等待页面切换动画（约 300ms）完成，并让被关闭的页面从树中移除。
Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pump(const Duration(milliseconds: 400));
}

Future<void> _tapText(WidgetTester tester, String text) async {
  await tester.tap(find.text(text).last);
  await _settle(tester);
}

Future<void> _login(WidgetTester tester) async {
  await tester.enterText(_field('请输入用户名'), 'mia_2026');
  await tester.enterText(_field('请输入密码'), 'river-stone-42');
  await tester.tap(find.widgetWithText(InkWell, '登录').last);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  group('启动', () {
    testWidgets('没有凭证：显示登录页与"忘记密码"提示', (tester) async {
      await _pumpApp(tester);
      expect(find.byType(LoginPage), findsOneWidget);
      expect(find.text('忘记密码？请联系管理员重置。'), findsOneWidget);
      expect(find.text('登录已失效，请重新登录。'), findsNothing);
    });

    testWidgets('凭证有效：直接进入首页，顶栏有账户菜单', (tester) async {
      await _pumpApp(tester, stored: _valid());
      expect(find.byType(HomePage), findsOneWidget);
      expect(find.byTooltip('账户'), findsOneWidget);
    });

    testWidgets('凭证已过期：登录页顶部提示登录已失效', (tester) async {
      await _pumpApp(
        tester,
        stored: StoredCredential(token: 'old', expiresAt: DateTime(2000)),
      );
      expect(find.byType(LoginPage), findsOneWidget);
      expect(find.text('登录已失效，请重新登录。'), findsOneWidget);
    });

    testWidgets('启动时连不上服务器：启动失败页，重试成功后进入首页', (tester) async {
      final api = FakeAuthApi()..meError = connectionError();
      await _pumpApp(tester, stored: _valid(), api: api);
      expect(find.text('无法连接服务器，请检查网络。'), findsOneWidget);
      expect(find.text('退出登录'), findsOneWidget);

      api.meError = null;
      await _tapText(tester, '重试');
      expect(find.byType(HomePage), findsOneWidget);
    });

    testWidgets('启动失败页点"退出登录"：回到登录页', (tester) async {
      final api = FakeAuthApi()..meError = connectionError();
      await _pumpApp(tester, stored: _valid(), api: api);
      await _tapText(tester, '退出登录');
      expect(find.byType(LoginPage), findsOneWidget);
      expect(api.calls, contains('logout'));
    });
  });

  group('登录页', () {
    testWidgets('必填项为空：提示框，不请求后端', (tester) async {
      final api = await _pumpApp(tester);
      await tester.tap(find.widgetWithText(InkWell, '登录').last);
      await tester.pump();
      expect(find.text('请输入用户名和密码'), findsOneWidget);
      expect(api.calls, isEmpty);
    });

    testWidgets('用户名或密码错误：提示框，输入框保留内容', (tester) async {
      final api = FakeAuthApi()
        ..loginError = httpError(401, detail: '用户名或密码错误');
      await _pumpApp(tester, api: api);
      await _login(tester);
      expect(find.text('用户名或密码错误'), findsOneWidget);
      expect(find.text('mia_2026'), findsOneWidget);
      expect(find.byType(LoginPage), findsOneWidget);
    });

    testWidgets('提交中：按钮内进度圈，输入框禁用；完成后进入首页', (tester) async {
      final api = FakeAuthApi()..loginGate = Completer();
      await _pumpApp(tester, api: api);
      await _login(tester);
      expect(
        find.descendant(
          of: find.byType(LoginPage),
          matching: find.byType(CircularProgressIndicator),
        ),
        findsOneWidget,
      );
      expect(tester.widget<TextField>(_field('请输入用户名')).enabled, isFalse);

      api.loginGate!.complete();
      await _settle(tester);
      expect(find.byType(HomePage), findsOneWidget);
    });

    testWidgets('登录过于频繁：显示后端文案，按钮显示倒计时且不可点', (tester) async {
      final api = FakeAuthApi()
        ..loginError = httpError(
          429,
          detail: '登录尝试过于频繁（每 10 分钟 10 次），请 8 分钟后再试',
          headers: {
            'retry-after': ['480'],
          },
        );
      await _pumpApp(tester, api: api);
      await _login(tester);
      expect(find.textContaining('过于频繁'), findsOneWidget);
      expect(find.textContaining('后可再试'), findsOneWidget);

      api.calls.clear();
      await tester.tap(find.textContaining('后可再试'));
      await tester.pump();
      expect(api.calls, isEmpty);
      // 卸载 App：AuthProvider 与按钮的倒计时计时器随之取消，测试结束时没有挂起的 Timer
      await tester.pumpWidget(const SizedBox());
    });
  });

  group('注册页', () {
    testWidgets('字段校验：用户名格式、密码太短、两次不一致', (tester) async {
      final api = await _pumpApp(tester);
      await _tapText(tester, '注册');
      expect(find.byType(RegisterPage), findsOneWidget);

      await tester.enterText(_field('请输入用户名'), 'ab');
      await tester.enterText(_field('请输入密码'), 'short');
      await tester.tap(find.widgetWithText(InkWell, '注册').last);
      await tester.pump();
      expect(_errorOf(tester, '请输入用户名'), '用户名需为 3–20 位字母、数字或下划线');
      expect(_errorOf(tester, '请输入密码'), '密码至少 8 位');
      expect(api.calls, isEmpty);

      await tester.enterText(_field('请输入用户名'), 'mia_2026');
      await tester.enterText(_field('请输入密码'), 'river-stone-42');
      await tester.enterText(_field('请再次输入密码'), 'river-stone-4');
      await tester.tap(find.widgetWithText(InkWell, '注册').last);
      await tester.pump();
      expect(_errorOf(tester, '请再次输入密码'), '两次输入的密码不一致');
      expect(api.calls, isEmpty);
    });

    testWidgets('用户名已被注册：显示在用户名下方；成功后关闭注册页进入首页', (tester) async {
      final api = FakeAuthApi()
        ..registerError = httpError(409, detail: '用户名已被注册');
      await _pumpApp(tester, api: api);
      await _tapText(tester, '注册');
      await tester.enterText(_field('请输入用户名'), 'mia_2026');
      await tester.enterText(_field('请输入密码'), 'river-stone-42');
      await tester.enterText(_field('请再次输入密码'), 'river-stone-42');
      await tester.tap(find.widgetWithText(InkWell, '注册').last);
      await tester.pump();
      expect(_errorOf(tester, '请输入用户名'), '用户名已被注册');

      api.registerError = null;
      await tester.tap(find.widgetWithText(InkWell, '注册').last);
      await _settle(tester);
      expect(find.byType(RegisterPage), findsNothing);
      expect(find.byType(HomePage), findsOneWidget);
    });
  });

  group('已登录', () {
    Future<void> openMenuItem(WidgetTester tester, String item) async {
      await tester.tap(find.byTooltip('账户'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(find.text(item).last);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
    }

    testWidgets('登出：确认后回到登录页，并通知后端', (tester) async {
      final api = await _pumpApp(tester, stored: _valid());
      await openMenuItem(tester, '登出');
      expect(find.text('确定要登出吗？'), findsOneWidget);
      await _tapText(tester, '登出');
      expect(find.byType(LoginPage), findsOneWidget);
      expect(find.text('登录已失效，请重新登录。'), findsNothing);
      expect(api.lastLogoutToken, 'stored');
    });

    testWidgets('登出确认框点"取消"：仍在首页', (tester) async {
      await _pumpApp(tester, stored: _valid());
      await openMenuItem(tester, '登出');
      await _tapText(tester, '取消');
      expect(find.byType(HomePage), findsOneWidget);
    });

    testWidgets('修改密码：校验、当前密码不正确、成功后 Toast 并返回', (tester) async {
      final api = await _pumpApp(tester, stored: _valid());
      await openMenuItem(tester, '修改密码');
      expect(find.byType(ChangePasswordPage), findsOneWidget);
      expect(find.text('当前账号：mia_2026'), findsOneWidget);

      await tester.tap(find.widgetWithText(InkWell, '保存'));
      await tester.pump();
      expect(_errorOf(tester, '请输入当前密码'), '请输入当前密码');
      expect(api.calls.where((c) => c == 'changePassword'), isEmpty);

      await tester.enterText(_field('请输入当前密码'), 'old-pass-1');
      await tester.enterText(_field('请输入新密码'), 'old-pass-1');
      await tester.tap(find.widgetWithText(InkWell, '保存'));
      await tester.pump();
      expect(_errorOf(tester, '请输入新密码'), '新密码不能与当前密码相同');

      api.changePasswordError = httpError(400, detail: '当前密码不正确');
      await tester.enterText(_field('请输入新密码'), 'new-pass-1');
      await tester.enterText(_field('请再次输入新密码'), 'new-pass-1');
      await tester.tap(find.widgetWithText(InkWell, '保存'));
      await tester.pump();
      expect(_errorOf(tester, '请输入当前密码'), '当前密码不正确');

      api.changePasswordError = null;
      await tester.tap(find.widgetWithText(InkWell, '保存'));
      await _settle(tester);
      expect(find.byType(ChangePasswordPage), findsNothing);
      expect(find.text('密码已修改。'), findsOneWidget);
      expect(find.byType(HomePage), findsOneWidget);
    });

    testWidgets('在推入的页面上凭证失效：关闭页面，回到登录页并提示', (tester) async {
      await _pumpApp(tester, stored: _valid());
      await openMenuItem(tester, '修改密码');
      expect(find.byType(ChangePasswordPage), findsOneWidget);

      _auth(tester).handleUnauthorized();
      await _settle(tester);
      expect(find.byType(ChangePasswordPage), findsNothing);
      expect(find.byType(LoginPage), findsOneWidget);
      expect(find.text('登录已失效，请重新登录。'), findsOneWidget);
    });
  });
}
