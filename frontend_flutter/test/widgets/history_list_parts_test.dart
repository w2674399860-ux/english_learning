import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:english_learning_app/widgets/history_list_parts.dart';

Future<void> _pump(WidgetTester tester, Widget child) {
  return tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(colorSchemeSeed: Colors.blue, useMaterial3: true),
      home: Scaffold(body: child),
    ),
  );
}

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
      expect(find.text('Load more (20 of 57)'), findsOneWidget);
      await tester.tap(find.text('Load more (20 of 57)'));
      expect(tapped, 1);
    });

    testWidgets('加载中显示进度圈，不显示按钮', (tester) async {
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
      expect(find.textContaining('Load more'), findsNothing);
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
      expect(find.text('Showing all 25 records'), findsOneWidget);
      expect(find.textContaining('Load more'), findsNothing);
    });
  });

  group('HistoryEmptyState', () {
    testWidgets('没有搜索时显示无记录', (tester) async {
      await _pump(tester, HistoryEmptyState(query: '', onClearSearch: () {}));
      expect(find.text('No records yet'), findsOneWidget);
      expect(find.text('Clear search'), findsNothing);
    });

    testWidgets('搜索无结果时显示关键词与清空按钮', (tester) async {
      var cleared = 0;
      await _pump(
        tester,
        HistoryEmptyState(query: 'zebra', onClearSearch: () => cleared++),
      );
      expect(find.text('No records match "zebra"'), findsOneWidget);
      await tester.tap(find.text('Clear search'));
      expect(cleared, 1);
    });
  });
}
