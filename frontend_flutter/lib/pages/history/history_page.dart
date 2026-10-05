import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/app_provider.dart';
import '../../models/learning_record.dart';
import '../../widgets/history_list_parts.dart';
import 'history_detail_page.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  static const _searchDebounce = Duration(milliseconds: 400);

  late final TextEditingController _searchController;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    // 搜索词保存在 Provider 中：切换 Tab 回来时保留搜索词，分页从第 1 页重新加载。
    _searchController = TextEditingController(
      text: context.read<AppProvider>().historyQuery,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AppProvider>().loadRecords();
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String text) {
    _debounce?.cancel();
    _debounce = Timer(_searchDebounce, () {
      if (mounted) context.read<AppProvider>().searchRecords(text);
    });
  }

  void _searchNow(String text) {
    _debounce?.cancel();
    context.read<AppProvider>().searchRecords(text);
  }

  void _clearSearch() {
    _searchController.clear();
    _searchNow('');
  }

  void _confirmDelete(BuildContext context, LearningRecord record) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Record'),
        content: Text('Are you sure you want to delete this record${record.words.isNotEmpty ? " (${record.words.join(", ")})" : ""}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              if (record.id != null) {
                context.read<AppProvider>().deleteRecord(record.id!);
              }
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('History')),
      body: Consumer<AppProvider>(
        builder: (context, provider, _) {
          final error = provider.historyError;

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: _buildSearchField(),
              ),
              if (error != null) _HistoryErrorText(message: error),
              Expanded(child: _buildList(context, provider)),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSearchField() {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: _searchController,
      builder: (context, value, _) => TextField(
        controller: _searchController,
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: 'Search words or English story',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: value.text.isEmpty
              ? null
              : IconButton(
                  icon: const Icon(Icons.clear),
                  tooltip: 'Clear search',
                  onPressed: _clearSearch,
                ),
          isDense: true,
          border: const OutlineInputBorder(),
        ),
        onChanged: _onSearchChanged,
        onSubmitted: _searchNow,
      ),
    );
  }

  Widget _buildList(BuildContext context, AppProvider provider) {
    if (provider.isLoadingHistory) {
      return const Center(child: CircularProgressIndicator());
    }

    if (provider.records.isEmpty) {
      return HistoryEmptyState(
        query: provider.historyQuery,
        onClearSearch: _clearSearch,
      );
    }

    final records = provider.records;
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: records.length + 1,
      itemBuilder: (context, index) {
        if (index == records.length) {
          return HistoryListFooter(
            loaded: records.length,
            total: provider.historyTotal,
            isLoadingMore: provider.isLoadingMoreHistory,
            onLoadMore: provider.loadMoreRecords,
          );
        }

        final record = records[index];
        return _RecordCard(
          record: record,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => HistoryDetailPage(record: record),
            ),
          ),
          onDelete: () => _confirmDelete(context, record),
        );
      },
    );
  }
}

class _RecordCard extends StatelessWidget {
  final LearningRecord record;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _RecordCard({
    required this.record,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 4, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      record.createdAt ?? '',
                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, size: 20),
                    onPressed: onDelete,
                    tooltip: 'Delete',
                    color: Colors.red,
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                record.englishStory,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 4,
                children: record.words
                    .map((w) => Chip(
                          label: Text(w, style: const TextStyle(fontSize: 12)),
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          visualDensity: VisualDensity.compact,
                        ))
                    .toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 历史加载 / 删除失败时显示在列表上方。
class _HistoryErrorText extends StatelessWidget {
  const _HistoryErrorText({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      color: scheme.errorContainer,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Text(message, style: TextStyle(color: scheme.onErrorContainer)),
    );
  }
}
