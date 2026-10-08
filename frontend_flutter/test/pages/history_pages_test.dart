import 'package:english_learning_app/auth/session.dart';
import 'package:english_learning_app/auth/token_store.dart';
import 'package:english_learning_app/l10n/l10n.dart';
import 'package:english_learning_app/models/learning_record.dart';
import 'package:english_learning_app/pages/history/history_detail_page.dart';
import 'package:english_learning_app/pages/history/history_page.dart';
import 'package:english_learning_app/providers/app_provider.dart';
import 'package:english_learning_app/providers/auth_provider.dart';
import 'package:english_learning_app/widgets/degraded_banner.dart';
import 'package:english_learning_app/widgets/section_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import '../helpers/fake_auth_api.dart';
import '../helpers/pump_app.dart';

LearningRecord _record({bool degraded = false, String? createdAt}) =>
    LearningRecord(
      id: 7,
      words: const ['forest', 'harvest'],
      englishStory: 'Mia walked through the forest at harvest.',
      chineseTranslation: '米娅在收获 (harvest) 时节穿过森林 (forest)。',
      englishBlank: 'Mia walked through the ___ at ___.',
      chineseBlank: '米娅在___ (___) 时节穿过___ (___)。',
      isDegraded: degraded,
      createdAt: createdAt,
    );

void main() {
  group('历史列表状态选择 historyBodyState', () {
    HistoryBodyState pick({
      bool isLoading = false,
      bool hasRecords = false,
      String? error,
      String query = '',
    }) => historyBodyState(
      isLoading: isLoading,
      hasRecords: hasRecords,
      error: error,
      query: query,
    );

    test('遗留问题 #12：没有记录且加载失败 → 加载失败，而不是"还没有记录"', () {
      expect(pick(error: '加载记录失败：x'), HistoryBodyState.loadFailed);
      expect(
        pick(error: '加载记录失败：x', query: 'zebra'),
        HistoryBodyState.loadFailed,
      );
    });

    test('加载中优先；有记录时显示列表（错误条另外显示在列表上方）', () {
      expect(pick(isLoading: true, error: 'x'), HistoryBodyState.loading);
      expect(pick(hasRecords: true, error: '删除记录失败：x'), HistoryBodyState.list);
      expect(pick(hasRecords: true), HistoryBodyState.list);
    });

    test('没有记录、没有错误：按有无搜索词区分空状态', () {
      expect(pick(), HistoryBodyState.empty);
      expect(pick(query: 'zebra'), HistoryBodyState.noMatch);
    });
  });

  // 页面级回归 #12：Flutter 测试环境会让真实 HTTP 请求返回 400，loadRecords 稳定失败。
  // AppProvider 由测试持有（不随页面卸载而释放），迟到的响应不会触碰已释放的对象。
  testWidgets('历史列表：先显示加载中，加载失败后只有错误条与"重试"，没有"还没有记录"', (tester) async {
    final auth = AuthProvider(
      api: FakeAuthApi(),
      store: InMemoryTokenStore(),
      session: AuthSession(),
    );
    final app = AppProvider();
    await pumpLocalized(
      tester,
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: auth),
          ChangeNotifierProvider.value(value: app),
        ],
        child: const HistoryPage(),
      ),
      surfaceSize: const Size(400, 900),
    );
    await tester.pump();
    expect(find.text('历史记录'), findsOneWidget);
    expect(find.text('搜索单词或英文短文'), findsOneWidget);
    expect(find.text('只能搜索英文单词或短语'), findsOneWidget);
    expect(find.text('正在加载…'), findsOneWidget);

    for (var i = 0; i < 50 && app.isLoadingHistory; i++) {
      await tester.pump(Duration.zero);
    }
    expect(app.historyError, isNotNull, reason: '测试环境中的请求应当失败');
    await tester.pump();

    expect(find.textContaining('加载记录失败'), findsOneWidget);
    expect(find.text('重试'), findsOneWidget);
    expect(find.text('还没有记录'), findsNothing);
    expect(find.text('正在加载…'), findsNothing);
  });

  group('历史详情', () {
    testWidgets('保存时间（本地时间）、五个分节、底部导出按钮，没有保存按钮', (tester) async {
      final record = _record(createdAt: '2026-10-05T05:28:31.384Z');
      await pumpLocalized(
        tester,
        HistoryDetailPage(record: record),
        surfaceSize: const Size(400, 2400),
      );
      final l10n = AppLocalizations.of(
        tester.element(find.byType(HistoryDetailPage)),
      );
      expect(
        find.text(l10n.detailTime(record.createdAtLocal!)),
        findsOneWidget,
      );
      expect(find.text('学习记录'), findsOneWidget);
      expect(find.byType(SectionCard), findsNWidgets(5));
      expect(find.text('导出 PDF'), findsOneWidget);
      expect(find.text('保存'), findsNothing);
      expect(find.byType(DegradedBanner), findsNothing);
      expect(find.textContaining('2026-10-05T'), findsNothing);
    });

    testWidgets('示例内容：顶部提示，不显示原因行', (tester) async {
      await pumpLocalized(
        tester,
        HistoryDetailPage(record: _record(degraded: true)),
        surfaceSize: const Size(400, 2400),
      );
      expect(find.text('这是一篇示例短文，不是根据你的单词写的。'), findsOneWidget);
      expect(find.textContaining('原因：'), findsNothing);
    });

    testWidgets('没有保存时间：不显示时间行；360 宽无溢出', (tester) async {
      await pumpLocalized(
        tester,
        HistoryDetailPage(record: _record()),
        surfaceSize: const Size(360, 2400),
      );
      expect(find.byIcon(Icons.calendar_month), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('点"导出 PDF"：按钮立即变为"正在导出…"', (tester) async {
      await pumpLocalized(
        tester,
        HistoryDetailPage(record: _record()),
        surfaceSize: const Size(400, 2400),
      );
      await tester.tap(find.text('导出 PDF'));
      await tester.pump();
      expect(find.text('正在导出…'), findsOneWidget);
      // 导出本身（加载 10.5 MB 字体、调用打印插件）不在测试中完成，卸载页面结束测试
      await tester.pumpWidget(const SizedBox());
    });
  });
}
