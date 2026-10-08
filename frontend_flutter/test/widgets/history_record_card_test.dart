import 'package:english_learning_app/l10n/l10n.dart';
import 'package:english_learning_app/models/learning_record.dart';
import 'package:english_learning_app/providers/difficulty.dart';
import 'package:english_learning_app/widgets/history_record_card.dart';
import 'package:english_learning_app/widgets/word_tag.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/pump_app.dart';

LearningRecord _record({
  List<String>? words,
  String? createdAt = '2026-10-05T05:28:31.384Z',
  Difficulty difficulty = Difficulty.advanced,
}) => LearningRecord(
  id: 1,
  words: words ?? [for (var i = 0; i < 18; i++) 'word$i'],
  englishStory: 'Every autumn, Mia walked through the forest. ' * 6,
  chineseTranslation: '',
  englishBlank: '',
  chineseBlank: '',
  difficulty: difficulty,
  createdAt: createdAt,
);

class _Calls {
  int tap = 0;
  int delete = 0;
}

Future<_Calls> _pump(WidgetTester tester, LearningRecord record) async {
  final calls = _Calls();
  await pumpLocalized(
    tester,
    Padding(
      padding: const EdgeInsets.all(24),
      child: HistoryRecordCard(
        record: record,
        index: 0,
        onTap: () => calls.tap++,
        onDelete: () => calls.delete++,
      ),
    ),
    surfaceSize: const Size(400, 800),
  );
  return calls;
}

void main() {
  testWidgets('时间按本地时区显示为"M月d日 HH:mm"，并显示难度 · 词数', (tester) async {
    final record = _record();
    await _pump(tester, record);
    final l10n = AppLocalizations.of(
      tester.element(find.byType(HistoryRecordCard)),
    );
    final expected = l10n.historyCardTime(
      DateTime.parse(record.createdAt!).toLocal(),
    );
    expect(find.text(expected), findsOneWidget);
    expect(find.text('高级 · 18 词'), findsOneWidget);
    // 不再直接显示 ISO 字符串
    expect(find.textContaining('2026-10-05T'), findsNothing);
  });

  testWidgets('单词超过 5 个时只显示前 5 个，其余折叠为 +N', (tester) async {
    await _pump(tester, _record());
    expect(find.byType(WordTag), findsNWidgets(5));
    expect(find.text('+13'), findsOneWidget);
  });

  testWidgets('短文最多 3 行', (tester) async {
    await _pump(tester, _record());
    final story = tester.widget<Text>(find.textContaining('Every autumn'));
    expect(story.maxLines, 3);
    expect(story.overflow, TextOverflow.ellipsis);
  });

  testWidgets('点卡片进入详情，点删除按钮只触发删除', (tester) async {
    final calls = await _pump(tester, _record());
    await tester.tap(find.text('查看详情'));
    expect(calls.tap, 1);

    await tester.tap(find.byTooltip('删除记录'));
    expect(calls.delete, 1);
    expect(calls.tap, 1);
  });

  testWidgets('时间缺失或格式不对：不显示时间，不报错', (tester) async {
    await _pump(tester, _record(createdAt: null));
    expect(tester.takeException(), isNull);
    await _pump(tester, _record(createdAt: 'not-a-date'));
    expect(tester.takeException(), isNull);
    expect(find.text('not-a-date'), findsNothing);
  });

  testWidgets('360 宽、长单词：无布局溢出', (tester) async {
    await pumpLocalized(
      tester,
      HistoryRecordCard(
        record: _record(
          words: [for (var i = 0; i < 43; i++) 'extraordinary$i'],
        ),
        index: 1,
        onTap: () {},
        onDelete: () {},
      ),
      surfaceSize: const Size(360, 800),
    );
    expect(tester.takeException(), isNull);
  });
}
