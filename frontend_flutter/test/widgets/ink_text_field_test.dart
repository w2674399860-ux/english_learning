import 'package:english_learning_app/widgets/ink_text_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/pump_app.dart';

void main() {
  testWidgets('显示标签、占位与辅助说明', (tester) async {
    await pumpLocalized(
      tester,
      InkTextField(
        label: testL10n.usernameLabel,
        hint: testL10n.usernameHint,
        helper: testL10n.usernameRule,
      ),
    );
    expect(find.text('用户名'), findsOneWidget);
    expect(find.text('请输入用户名'), findsOneWidget);
    expect(find.text('3–20 位字母、数字或下划线'), findsOneWidget);
  });

  testWidgets('有错误时显示错误文字并隐藏辅助说明', (tester) async {
    await pumpLocalized(
      tester,
      InkTextField(
        label: testL10n.passwordLabel,
        helper: testL10n.passwordRule,
        errorText: testL10n.validationPasswordTooShort,
      ),
    );
    expect(find.text('密码至少 8 位'), findsOneWidget);
    expect(find.text(testL10n.passwordRule), findsNothing);
  });

  testWidgets('密码框默认遮挡，点切换后显示明文', (tester) async {
    final controller = TextEditingController(text: 'river-stone-42');
    addTearDown(controller.dispose);
    await pumpLocalized(
      tester,
      InkTextField(
        label: testL10n.passwordLabel,
        controller: controller,
        isPassword: true,
      ),
    );

    TextField field() => tester.widget<TextField>(find.byType(TextField));
    expect(field().obscureText, isTrue);
    expect(find.byTooltip('显示或隐藏密码'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.visibility_off));
    await tester.pump();
    expect(field().obscureText, isFalse);
    expect(find.byIcon(Icons.visibility), findsOneWidget);
  });

  testWidgets('聚焦后继续输入不丢内容（聚焦阴影不会让输入框重新挂载）', (tester) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    await pumpLocalized(
      tester,
      InkTextField(label: testL10n.usernameLabel, controller: controller),
    );
    await tester.tap(find.byType(TextField));
    await tester.pump();
    await tester.enterText(find.byType(TextField), 'mia');
    await tester.pump();
    expect(controller.text, 'mia');
    final editable = tester.widget<EditableText>(find.byType(EditableText));
    expect(editable.focusNode.hasFocus, isTrue);
  });

  testWidgets('普通输入框没有显示 / 隐藏切换', (tester) async {
    await pumpLocalized(tester, InkTextField(label: testL10n.usernameLabel));
    expect(find.byTooltip('显示或隐藏密码'), findsNothing);
    expect(
      tester.widget<TextField>(find.byType(TextField)).obscureText,
      isFalse,
    );
  });

  testWidgets('输入与提交回调', (tester) async {
    String? changed;
    String? submitted;
    await pumpLocalized(
      tester,
      InkTextField(
        label: testL10n.usernameLabel,
        textInputAction: TextInputAction.done,
        onChanged: (v) => changed = v,
        onSubmitted: (v) => submitted = v,
      ),
    );
    await tester.enterText(find.byType(TextField), 'mia_2026');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    expect(changed, 'mia_2026');
    expect(submitted, 'mia_2026');
  });
}
