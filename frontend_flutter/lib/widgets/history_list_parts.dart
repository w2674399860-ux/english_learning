import 'package:flutter/material.dart';

/// 历史列表底部：还有更多时显示"加载更多"，加载中显示进度圈，全部加载完显示总数。
class HistoryListFooter extends StatelessWidget {
  const HistoryListFooter({
    super.key,
    required this.loaded,
    required this.total,
    required this.isLoadingMore,
    required this.onLoadMore,
  });

  final int loaded;
  final int total;
  final bool isLoadingMore;
  final VoidCallback? onLoadMore;

  @override
  Widget build(BuildContext context) {
    final Widget child;
    if (isLoadingMore) {
      child = const SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    } else if (loaded < total) {
      child = OutlinedButton(
        onPressed: onLoadMore,
        child: Text('Load more ($loaded of $total)'),
      );
    } else {
      child = Text(
        'Showing all $total records',
        style: TextStyle(color: Theme.of(context).colorScheme.outline),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Center(child: child),
    );
  }
}

/// 历史列表为空时的提示。有搜索词时说明没有匹配，并提供清空搜索。
class HistoryEmptyState extends StatelessWidget {
  const HistoryEmptyState({
    super.key,
    required this.query,
    required this.onClearSearch,
  });

  final String query;
  final VoidCallback onClearSearch;

  @override
  Widget build(BuildContext context) {
    if (query.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('No records yet'),
          ],
        ),
      );
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.search_off, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          Text('No records match "$query"', textAlign: TextAlign.center),
          const SizedBox(height: 8),
          TextButton(onPressed: onClearSearch, child: const Text('Clear search')),
        ],
      ),
    );
  }
}
