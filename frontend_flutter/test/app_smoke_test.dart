import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:english_learning_app/auth/token_store.dart';
import 'package:english_learning_app/main.dart';
import 'package:english_learning_app/pages/auth/login_page.dart';
import 'package:english_learning_app/pages/home/home_page.dart';

import 'helpers/fake_auth_api.dart';

// 启动冒烟测试：App 能构建出页面且没有异常。账号接口与凭证存储换成假的（A-2）。
// 用类型而不是文案查找主要页面。不切到历史 Tab：HistoryPage 构建时会请求后端。
void main() {
  testWidgets('没有凭证：启动后显示登录页', (tester) async {
    await tester.pumpWidget(
      MyApp(authApi: FakeAuthApi(), tokenStore: InMemoryTokenStore()),
    );
    await tester.pump();

    expect(find.byType(LoginPage), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('已登录：显示首页与底部导航，界面与系统控件为中文', (tester) async {
    await tester.pumpWidget(
      MyApp(
        authApi: FakeAuthApi(),
        tokenStore: InMemoryTokenStore(
          StoredCredential(
            token: 't',
            expiresAt: DateTime.now().add(const Duration(days: 1)),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byType(NavigationDestination), findsNWidgets(2));
    expect(find.byType(HomePage), findsOneWidget);
    // U-10：固定简体中文，系统控件也是中文
    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.locale, const Locale('zh'));
    final context = tester.element(find.byType(HomePage));
    expect(Localizations.localeOf(context), const Locale('zh'));
    expect(MaterialLocalizations.of(context).backButtonTooltip, '返回');
    expect(tester.takeException(), isNull);
  });
}
