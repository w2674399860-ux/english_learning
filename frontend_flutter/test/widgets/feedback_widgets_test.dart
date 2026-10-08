import 'package:english_learning_app/widgets/account_menu.dart';
import 'package:english_learning_app/widgets/confirm_dialog.dart';
import 'package:english_learning_app/widgets/error_notice.dart';
import 'package:english_learning_app/widgets/illustration.dart';
import 'package:english_learning_app/widgets/ink_toast.dart';
import 'package:english_learning_app/widgets/page_scaffold.dart';
import 'package:english_learning_app/widgets/state_view.dart';
import 'package:english_learning_app/widgets/tip_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/pump_app.dart';

void main() {
  group('ErrorNotice', () {
    testWidgets('有重试回调时显示"重试"并可点击', (tester) async {
      var retries = 0;
      await pumpLocalized(
        tester,
        ErrorNotice(message: '生成失败：请求超时，请重试。', onRetry: () => retries++),
      );
      expect(find.text('生成失败：请求超时，请重试。'), findsOneWidget);
      await tester.tap(find.text('重试'));
      expect(retries, 1);
    });

    testWidgets('没有重试回调时（如 429）不显示"重试"', (tester) async {
      await pumpLocalized(tester, const ErrorNotice(message: '生成次数已用完'));
      expect(find.text('重试'), findsNothing);
    });
  });

  group('StateView', () {
    testWidgets('标题、说明与两个按钮回调', (tester) async {
      var primary = 0;
      var secondary = 0;
      await pumpLocalized(
        tester,
        StateView(
          illustration: IllustrationKind.sad,
          title: testL10n.ocrFailedTitle,
          message: testL10n.errorTimeout,
          primaryAction: StateAction(
            label: testL10n.ocrRetry,
            onPressed: () => primary++,
          ),
          secondaryAction: StateAction(
            label: testL10n.ocrBackHome,
            onPressed: () => secondary++,
          ),
        ),
      );
      expect(find.text('识别失败'), findsOneWidget);
      expect(find.text('请求超时，请重试。'), findsOneWidget);
      expect(find.byType(Illustration), findsOneWidget);
      await tester.tap(find.text('重试'));
      await tester.tap(find.text('返回首页'));
      expect((primary, secondary), (1, 1));
    });

    testWidgets('加载中显示不确定进度条', (tester) async {
      await pumpLocalized(
        tester,
        const StateView(title: '正在识别', isLoading: true),
      );
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
    });
  });

  group('showConfirmDialog', () {
    /// 打开对话框，返回一个读取结果的函数（对话框关闭后才有值）。
    Future<bool? Function()> open(
      WidgetTester tester, {
      String? message,
    }) async {
      bool? result;
      await pumpLocalized(
        tester,
        Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              result = await showConfirmDialog(
                context,
                title: testL10n.deleteDialogTitle,
                message: message,
                confirmLabel: testL10n.deleteDialogConfirm,
              );
            },
            child: const Text('open'),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      return () => result;
    }

    testWidgets('显示标题与说明，点"删除"返回 true 并关闭', (tester) async {
      final result = await open(tester, message: testL10n.deleteDialogBody);
      expect(find.text('删除这条记录？'), findsOneWidget);
      expect(find.text('删除后无法恢复。'), findsOneWidget);

      await tester.tap(find.text('删除'));
      await tester.pumpAndSettle();
      expect(find.text('删除这条记录？'), findsNothing);
      expect(result(), isTrue);
    });

    testWidgets('点"取消"返回 false', (tester) async {
      final result = await open(tester);
      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();
      expect(result(), isFalse);
    });

    testWidgets('点遮罩关闭也返回 false', (tester) async {
      final result = await open(tester);
      await tester.tapAt(const Offset(4, 4));
      await tester.pumpAndSettle();
      expect(find.text('删除这条记录？'), findsNothing);
      expect(result(), isFalse);
    });
  });

  group('AccountMenu', () {
    testWidgets('展开后显示用户名、修改密码、登出，并回调', (tester) async {
      var change = 0;
      var logout = 0;
      await pumpLocalized(
        tester,
        AccountMenu(
          username: 'mia_2026',
          onChangePassword: () => change++,
          onLogout: () => logout++,
        ),
        inAppBar: true,
      );
      expect(find.byTooltip('账户'), findsOneWidget);

      await tester.tap(find.byTooltip('账户'));
      await tester.pumpAndSettle();
      expect(find.text('mia_2026'), findsOneWidget);
      await tester.tap(find.text('修改密码'));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('账户'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('登出'));
      await tester.pumpAndSettle();
      expect((change, logout), (1, 1));
    });
  });

  testWidgets('TipCard 显示标题与正文', (tester) async {
    await pumpLocalized(
      tester,
      TipCard(title: testL10n.homeTipTitle, body: testL10n.homeTipBody),
    );
    expect(find.text('学习小贴士'), findsOneWidget);
    expect(find.text(testL10n.homeTipBody), findsOneWidget);
  });

  testWidgets('showInkToast 显示文案', (tester) async {
    await pumpLocalized(
      tester,
      Builder(
        builder: (context) => TextButton(
          onPressed: () => showInkToast(context, testL10n.saveSuccess),
          child: const Text('toast'),
        ),
      ),
    );
    await tester.tap(find.text('toast'));
    await tester.pump();
    expect(find.text('已保存。'), findsOneWidget);
    expect(find.byIcon(Icons.check_circle), findsOneWidget);
  });

  testWidgets('ContentWidth 在宽屏下把内容限制在 480 以内', (tester) async {
    await pumpLocalized(
      tester,
      const ContentWidth(
        child: SizedBox(
          key: Key('content'),
          width: double.infinity,
          height: 10,
        ),
      ),
      surfaceSize: const Size(1600, 900),
    );
    expect(tester.getSize(find.byKey(const Key('content'))).width, 480);
  });
}
