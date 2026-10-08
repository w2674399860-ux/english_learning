import 'package:english_learning_app/pages/words/word_confirm_page.dart';
import 'package:english_learning_app/providers/app_provider.dart';
import 'package:english_learning_app/widgets/ink_button.dart';
import 'package:english_learning_app/widgets/word_chip.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import '../helpers/pump_app.dart';

// AppProvider 不能注入假接口（F2）：这里只用不发请求的方法（addWord、toggleWord 等）准备数据，
// 生成中 / 生成失败的界面在 confirm_action_bar_test.dart 中测试。
Future<AppProvider> _pump(
  WidgetTester tester,
  List<String> words, {
  Size size = const Size(400, 1600),
}) async {
  final provider = AppProvider();
  for (final w in words) {
    provider.addWord(w);
  }
  await pumpLocalized(
    tester,
    ChangeNotifierProvider.value(
      value: provider,
      child: const WordConfirmPage(),
    ),
    surfaceSize: size,
  );
  return provider;
}

InkButton _button(WidgetTester tester, String label) =>
    tester.widget<InkButton>(
      find.ancestor(of: find.text(label), matching: find.byType(InkButton)),
    );

Finder _chip(String word) =>
    find.descendant(of: find.byType(WordChip), matching: find.text(word));

Future<void> _addWord(WidgetTester tester, String text) async {
  await tester.enterText(find.byType(TextField), text);
  await tester.tap(find.text('添加'));
  await tester.pump();
}

void main() {
  testWidgets('默认：全部选中，计数、说明、生成可用', (tester) async {
    await _pump(tester, ['harvest', 'lantern', 'journey']);
    expect(find.byType(WordChip), findsNWidgets(3));
    expect(find.text('已选 3 / 20'), findsOneWidget);
    expect(find.text('点击单词可选中或取消'), findsOneWidget);
    expect(_button(tester, '生成').onPressed, isNotNull);
  });

  testWidgets('点单词切换选中、点 × 删除，计数随之变化', (tester) async {
    final provider = await _pump(tester, ['harvest', 'lantern', 'journey']);
    await tester.tap(_chip('lantern'));
    await tester.pump();
    expect(find.text('已选 2 / 20'), findsOneWidget);
    expect(provider.selectedWords, isNot(contains('lantern')));

    await tester.tap(find.bySemanticsLabel('删除 harvest'));
    await tester.pump();
    expect(find.byType(WordChip), findsNWidgets(2));
    expect(find.text('已选 1 / 20'), findsOneWidget);
  });

  testWidgets('清空后生成禁用；全选恢复', (tester) async {
    await _pump(tester, ['harvest', 'lantern']);
    await tester.tap(find.text('清空'));
    await tester.pump();
    expect(find.text('已选 0 / 20'), findsOneWidget);
    expect(_button(tester, '生成').onPressed, isNull);
    expect(_button(tester, '清空').onPressed, isNull);

    await tester.tap(find.text('全选'));
    await tester.pump();
    expect(find.text('已选 2 / 20'), findsOneWidget);
    expect(_button(tester, '生成').onPressed, isNotNull);
  });

  testWidgets('选中超过 20 个：提示并禁用生成；取消一个后恢复', (tester) async {
    final words = [for (var i = 0; i < 21; i++) 'word$i'];
    await _pump(tester, words, size: const Size(400, 2400));
    expect(find.text('已选 21 / 20'), findsOneWidget);
    expect(find.text('一次最多 20 个单词，请取消一些'), findsOneWidget);
    expect(_button(tester, '生成').onPressed, isNull);

    await tester.tap(_chip('word0'));
    await tester.pump();
    expect(find.text('一次最多 20 个单词，请取消一些'), findsNothing);
    expect(_button(tester, '生成').onPressed, isNotNull);
  });

  testWidgets('没有识别出单词：空状态，全选与生成禁用；可以手动添加', (tester) async {
    await _pump(tester, []);
    expect(find.text('没有识别出单词，可以在下方手动添加。'), findsOneWidget);
    expect(_button(tester, '全选').onPressed, isNull);
    expect(_button(tester, '生成').onPressed, isNull);

    await _addWord(tester, '  harvest ');
    expect(find.byType(WordChip), findsOneWidget);
    expect(find.text('已选 1 / 20'), findsOneWidget);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      isEmpty,
    );
  });

  testWidgets('添加单词校验：空、无字母、重复、超长都用 Toast 提示', (tester) async {
    await _pump(tester, ['harvest']);
    final cases = {
      '': '请先输入单词',
      '123': '单词至少要包含一个字母',
      'HARVEST': '这个单词已经在列表里了',
      'a' * 41: '单词不能超过 40 个字符',
    };
    for (final MapEntry(:key, :value) in cases.entries) {
      await _addWord(tester, key);
      expect(find.text(value), findsOneWidget, reason: key);
    }
    expect(find.byType(WordChip), findsOneWidget);
  });

  testWidgets('360 宽、40 个单词：无布局溢出', (tester) async {
    final words = [for (var i = 0; i < 40; i++) 'vocabulary$i'];
    await _pump(tester, words, size: const Size(360, 3000));
    expect(tester.takeException(), isNull);
  });
}
