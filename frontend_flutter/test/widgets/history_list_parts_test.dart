import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:english_learning_app/widgets/history_list_parts.dart';

import '../helpers/pump_app.dart';

Future<void> _pump(WidgetTester tester, Widget child) =>
    pumpLocalized(tester, child);

void main() {
  group('HistoryListFooter', () {
    testWidgets('还有更多时显示加载更多按钮与进度，点击回调', (tester) async {
      var tapped = 0;
      await _pump(
        tester,
        HistoryListFooter(
          loaded: 20,
          total: 57,
          isLoadingMore: false,
          onLoadMore: () => tapped++,
        ),
      );
      expect(find.text('加载更多（20 / 57）'), findsOneWidget);
      await tester.tap(find.text('加载更多（20 / 57）'));
      expect(tapped, 1);
    });

    testWidgets('加载中：按钮内进度圈与"正在加载…"，不可再点', (tester) async {
      await _pump(
        tester,
        const HistoryListFooter(
          loaded: 20,
          total: 57,
          isLoadingMore: true,
          onLoadMore: null,
        ),
      );
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('正在加载…'), findsOneWidget);
      expect(find.textContaining('加载更多'), findsNothing);
    });

    testWidgets('全部加载完显示总数，不显示按钮', (tester) async {
      await _pump(
        tester,
        const HistoryListFooter(
          loaded: 25,
          total: 25,
          isLoadingMore: false,
          onLoadMore: null,
        ),
      );
      expect(find.text('已显示全部 25 条记录'), findsOneWidget);
      expect(find.textContaining('加载更多'), findsNothing);
    });
  });

  group('HistoryEmptyState', () {
    testWidgets('没有搜索时显示无记录', (tester) async {
      await _pump(tester, HistoryEmptyState(query: '', onClearSearch: () {}));
      expect(find.text('还没有记录'), findsOneWidget);
      expect(find.text('拍一张照片，开始第一次学习。'), findsOneWidget);
      expect(find.text('清空搜索'), findsNothing);
      // 没有提供切换 Tab 的回调时不显示"去拍照"
      expect(find.text('去拍照'), findsNothing);
    });

    testWidgets('没有记录时"去拍照"回调', (tester) async {
      var goHome = 0;
      await _pump(
        tester,
        HistoryEmptyState(
          query: '',
          onClearSearch: () {},
          onGoHome: () => goHome++,
        ),
      );
      await tester.tap(find.text('去拍照'));
      expect(goHome, 1);
    });

    testWidgets('搜索无结果时显示关键词与清空按钮', (tester) async {
      var cleared = 0;
      await _pump(
        tester,
        HistoryEmptyState(query: 'zebra', onClearSearch: () => cleared++),
      );
      expect(find.text('没有匹配“zebra”的记录'), findsOneWidget);
      await tester.tap(find.text('清空搜索'));
      expect(cleared, 1);
    });
  });
}
