import 'package:english_learning_app/widgets/hero_action_button.dart';
import 'package:english_learning_app/widgets/ink_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/pump_app.dart';

void main() {
  testWidgets('点击触发回调', (tester) async {
    var taps = 0;
    await pumpLocalized(
      tester,
      InkButton(label: '生成', onPressed: () => taps++),
    );
    await tester.tap(find.text('生成'));
    expect(taps, 1);
  });

  testWidgets('禁用时半透明且不响应点击', (tester) async {
    await pumpLocalized(tester, const InkButton(label: '生成', onPressed: null));
    await tester.tap(find.text('生成'));
    expect(find.byType(Opacity), findsOneWidget);
    final semantics = tester.getSemantics(find.text('生成'));
    expect(semantics.flagsCollection.isEnabled, isNot(true));
  });

  testWidgets('加载中：显示进度圈与加载文案，不可点击，也不置灰', (tester) async {
    var taps = 0;
    await pumpLocalized(
      tester,
      InkButton(
        label: '生成',
        loadingLabel: '正在写短文和练习题…',
        isLoading: true,
        onPressed: () => taps++,
      ),
    );
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('正在写短文和练习题…'), findsOneWidget);
    expect(find.text('生成'), findsNothing);
    expect(find.byType(Opacity), findsNothing);
    await tester.tap(find.byType(InkButton));
    expect(taps, 0);
  });

  testWidgets('按下时下移（按压动效），松开后复位', (tester) async {
    await pumpLocalized(tester, InkButton(label: '登录', onPressed: () {}));
    double dy() {
      final container = tester.widget<AnimatedContainer>(
        find.byType(AnimatedContainer),
      );
      return container.transform!.getTranslation().y;
    }

    expect(dy(), 0);
    final gesture = await tester.startGesture(
      tester.getCenter(find.text('登录')),
    );
    await tester.pumpAndSettle();
    expect(dy(), greaterThan(0));
    await gesture.up();
    await tester.pumpAndSettle();
    expect(dy(), 0);
  });

  testWidgets('首页入口按钮显示标题与副标题，点击回调', (tester) async {
    var taps = 0;
    await pumpLocalized(
      tester,
      HeroActionButton(
        icon: Icons.photo_library,
        title: testL10n.homeGallery,
        subtitle: testL10n.homeGallerySubtitle,
        onPressed: () => taps++,
      ),
    );
    expect(find.text('从相册上传'), findsOneWidget);
    expect(find.text(testL10n.homeGallerySubtitle), findsOneWidget);
    await tester.tap(find.text('从相册上传'));
    expect(taps, 1);
  });
}
