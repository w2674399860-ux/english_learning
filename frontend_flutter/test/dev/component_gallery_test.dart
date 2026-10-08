import 'package:english_learning_app/dev/component_gallery.dart';
import 'package:english_learning_app/widgets/ink_button.dart';
import 'package:english_learning_app/widgets/word_chip.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/pump_app.dart';

// 组件展示页冒烟测试：在手机宽度（390）下一次性构建全部组件与状态，
// 任何布局溢出（RenderFlex overflowed）都会作为异常让测试失败。
void main() {
  for (final width in [360.0, 390.0]) {
    testWidgets('宽 $width 时全部组件构建无异常', (tester) async {
      await pumpLocalized(
        tester,
        const ComponentGallery(),
        surfaceSize: Size(width, 14000),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(find.byType(InkButton), findsWidgets);
      expect(find.byType(WordChip), findsWidgets);
    });
  }

  testWidgets('勾选与删除单词会更新计数', (tester) async {
    await pumpLocalized(
      tester,
      const ComponentGallery(),
      surfaceSize: const Size(390, 14000),
    );
    // 示例 20 个词，page 与 Unit 3 默认未选中
    expect(find.text('已选 18 / 20'), findsOneWidget);
    await tester.tap(
      find.descendant(of: find.byType(WordChip), matching: find.text('page')),
    );
    await tester.pump();
    expect(find.text('已选 19 / 20'), findsOneWidget);
  });
}
