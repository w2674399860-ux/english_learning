import 'package:english_learning_app/models/learning_record.dart';
import 'package:english_learning_app/pages/story/story_page.dart';
import 'package:english_learning_app/providers/app_provider.dart';
import 'package:english_learning_app/providers/difficulty.dart';
import 'package:english_learning_app/widgets/blank_text.dart';
import 'package:english_learning_app/widgets/highlighted_text.dart';
import 'package:english_learning_app/widgets/section_card.dart';
import 'package:english_learning_app/widgets/word_tag.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import '../helpers/pump_app.dart';

// AppProvider 不能注入假接口（F2），无法让 currentRecord 有值，
// 所以阅读区拆成 StoryContent 单独测试；保存按钮三态在 save_button_test.dart 中测试。
final _record = LearningRecord(
  words: const ['forest', 'harvest', 'apple'],
  englishStory: 'Mia walked through the forest to help with the apple harvest.',
  chineseTranslation: '米娅穿过森林 (forest)，去帮忙收获 (harvest) 苹果 (apple)。',
  englishBlank: 'Mia walked through the ___ to help with the ___ ___.',
  chineseBlank: '米娅穿过___ (___)，去帮忙___ (___) ___ (___)。',
  difficulty: Difficulty.advanced,
);

void main() {
  testWidgets('阅读区：元信息、五个分节、两段说明、可选中复制', (tester) async {
    await pumpLocalized(
      tester,
      StoryContent(record: _record),
      surfaceSize: const Size(400, 2000),
    );
    expect(find.text('3 个单词 · 高级'), findsOneWidget);
    expect(find.byType(SectionCard), findsNWidgets(5));
    for (final title in ['本次单词', '英文短文', '中文翻译', '英文填空', '中文填空']) {
      expect(find.text(title), findsOneWidget, reason: title);
    }
    expect(find.byType(WordTag), findsNWidgets(3));
    expect(find.byType(HighlightedText), findsNWidgets(2));
    expect(find.byType(BlankText), findsNWidgets(2));
    expect(find.text('根据记忆填出横线处的单词。'), findsOneWidget);
    expect(find.byType(SelectionArea), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('页脚（返回修改单词）显示在最后', (tester) async {
    var taps = 0;
    await pumpLocalized(
      tester,
      StoryContent(
        record: _record,
        footer: TextButton(
          onPressed: () => taps++,
          child: const Text('返回修改单词'),
        ),
      ),
      surfaceSize: const Size(400, 2400),
    );
    await tester.tap(find.text('返回修改单词'));
    expect(taps, 1);
  });

  testWidgets('360 宽、长单词与长文本：无布局溢出', (tester) async {
    final long = LearningRecord(
      words: [for (var i = 0; i < 20; i++) 'extraordinarily$i'],
      englishStory: 'word ' * 170,
      chineseTranslation: '汉字' * 200,
      englishBlank: '___ ' * 100,
      chineseBlank: '___ (___) ' * 60,
    );
    await pumpLocalized(
      tester,
      StoryContent(record: long),
      surfaceSize: const Size(360, 6000),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('学习结果页没有结果时显示"暂无数据"，不显示保存按钮', (tester) async {
    await pumpLocalized(
      tester,
      ChangeNotifierProvider(
        create: (_) => AppProvider(),
        child: const StoryPage(),
      ),
    );
    expect(find.text('暂无数据'), findsOneWidget);
    expect(find.text('保存'), findsNothing);
    expect(find.text('学习结果'), findsOneWidget);
  });
}
