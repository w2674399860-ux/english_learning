import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:english_learning_app/widgets/save_button.dart';

Future<void> _pump(
  WidgetTester tester, {
  required bool isSaving,
  required bool isSaved,
  VoidCallback? onPressed,
}) {
  return tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(colorSchemeSeed: Colors.blue, useMaterial3: true),
      home: Scaffold(
        appBar: AppBar(
          actions: [
            SaveButton(
              isSaving: isSaving,
              isSaved: isSaved,
              onPressed: onPressed,
            ),
          ],
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('未保存时显示保存图标且可点击', (tester) async {
    await _pump(tester, isSaving: false, isSaved: false, onPressed: () {});

    expect(find.byIcon(Icons.save), findsOneWidget);
    final button = tester.widget<IconButton>(find.byType(IconButton));
    expect(button.onPressed, isNotNull);
  });

  testWidgets('保存中不可点击', (tester) async {
    await _pump(tester, isSaving: true, isSaved: false, onPressed: () {});

    final button = tester.widget<IconButton>(find.byType(IconButton));
    expect(button.onPressed, isNull);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('已保存时切换为对勾且不可再点击', (tester) async {
    await _pump(tester, isSaving: false, isSaved: true, onPressed: () {});

    expect(find.byIcon(Icons.check), findsOneWidget);
    expect(find.byIcon(Icons.save), findsNothing);
    final button = tester.widget<IconButton>(find.byType(IconButton));
    expect(button.onPressed, isNull);
  });
}
