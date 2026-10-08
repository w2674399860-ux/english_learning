import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:english_learning_app/widgets/ink_button.dart';
import 'package:english_learning_app/widgets/save_button.dart';

import '../helpers/pump_app.dart';

Future<void> _pump(
  WidgetTester tester, {
  required bool isSaving,
  required bool isSaved,
  VoidCallback? onPressed,
}) {
  return pumpLocalized(
    tester,
    SaveButton(isSaving: isSaving, isSaved: isSaved, onPressed: onPressed),
    inAppBar: true,
  );
}

InkButton _button(WidgetTester tester) =>
    tester.widget<InkButton>(find.byType(InkButton));

void main() {
  testWidgets('未保存：书签图标 +"保存"，可点击', (tester) async {
    var taps = 0;
    await _pump(
      tester,
      isSaving: false,
      isSaved: false,
      onPressed: () => taps++,
    );
    expect(find.text('保存'), findsOneWidget);
    expect(find.byIcon(Icons.bookmark), findsOneWidget);
    await tester.tap(find.text('保存'));
    expect(taps, 1);
  });

  testWidgets('保存中：进度圈 +"保存中"，不可点击', (tester) async {
    var taps = 0;
    await _pump(
      tester,
      isSaving: true,
      isSaved: false,
      onPressed: () => taps++,
    );
    expect(find.text('保存中'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(_button(tester).onPressed, isNull);
    await tester.tap(find.text('保存中'));
    expect(taps, 0);
  });

  testWidgets('已保存：对勾 +"已保存"，不可再点击', (tester) async {
    var taps = 0;
    await _pump(
      tester,
      isSaving: false,
      isSaved: true,
      onPressed: () => taps++,
    );
    expect(find.text('已保存'), findsOneWidget);
    expect(find.byIcon(Icons.check), findsOneWidget);
    expect(find.byIcon(Icons.bookmark), findsNothing);
    expect(_button(tester).onPressed, isNull);
    await tester.tap(find.text('已保存'));
    expect(taps, 0);
  });
}
