import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:english_learning_app/main.dart';
import 'package:english_learning_app/pages/home/home_page.dart';

// 启动冒烟测试：App 能构建出首页与底部导航，且没有异常。
// 用类型而不是文案查找，U-10 中文化时不必改。
// 不切到历史 Tab：HistoryPage 构建时会请求后端。
void main() {
  testWidgets('App 启动后显示首页与底部导航', (tester) async {
    await tester.pumpWidget(const MyApp());

    expect(find.byType(MaterialApp), findsOneWidget);
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byType(NavigationDestination), findsNWidgets(2));
    expect(find.byType(HomePage), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
