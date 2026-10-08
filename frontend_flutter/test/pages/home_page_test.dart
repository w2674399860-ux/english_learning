import 'package:english_learning_app/auth/session.dart';
import 'package:english_learning_app/auth/token_store.dart';
import 'package:english_learning_app/pages/home/home_page.dart';
import 'package:english_learning_app/providers/app_provider.dart';
import 'package:english_learning_app/providers/auth_provider.dart';
import 'package:english_learning_app/widgets/hero_action_button.dart';
import 'package:english_learning_app/widgets/page_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import '../helpers/fake_auth_api.dart';
import '../helpers/pump_app.dart';

Future<void> _pumpHome(
  WidgetTester tester, {
  Size size = const Size(400, 1400),
}) async {
  final auth = AuthProvider(
    api: FakeAuthApi(),
    store: InMemoryTokenStore(
      StoredCredential(
        token: 't',
        expiresAt: DateTime.now().add(const Duration(days: 1)),
      ),
    ),
    session: AuthSession(),
  );
  await auth.restore();
  await pumpLocalized(
    tester,
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: auth),
        ChangeNotifierProvider(create: (_) => AppProvider()),
      ],
      child: const HomePage(),
    ),
    surfaceSize: size,
  );
}

void main() {
  testWidgets('首页元素：标题、插画、标语、两个入口、小贴士、账户菜单', (tester) async {
    await _pumpHome(tester);
    expect(find.text('AI 英语学习'), findsOneWidget);
    expect(find.text('用 AI 学英语'), findsOneWidget);
    expect(find.text('上传一张照片，提取英文单词，\n并生成学习材料'), findsOneWidget);
    expect(find.byType(HeroActionButton), findsNWidgets(2));
    expect(find.text('从相册上传'), findsOneWidget);
    expect(find.text('选一张课本、单词表或试卷的照片'), findsOneWidget);
    expect(find.text('拍照'), findsOneWidget);
    expect(find.text('学习小贴士'), findsOneWidget);
    expect(find.byTooltip('账户'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('打开相册失败（权限被拒绝）：显示错误 Toast，停在首页', (tester) async {
    const channel = MethodChannel('plugins.flutter.io/image_picker');
    final messenger = tester.binding.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(channel, (call) async {
      throw PlatformException(code: 'photo_access_denied');
    });
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));

    await _pumpHome(tester);
    await tester.tap(find.text('从相册上传'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('出了点问题，请重试。'), findsOneWidget);
    expect(find.byType(HomePage), findsOneWidget);
  });

  testWidgets('宽屏下内容不超过 480', (tester) async {
    await _pumpHome(tester, size: const Size(1400, 1400));
    final content = find
        .descendant(
          of: find.byType(ContentWidth),
          matching: find.byType(Column),
        )
        .first;
    expect(tester.getSize(content).width, lessThanOrEqualTo(480));
  });

  testWidgets('小屏（360 宽）无布局溢出', (tester) async {
    await _pumpHome(tester, size: const Size(360, 1400));
    expect(tester.takeException(), isNull);
  });
}
