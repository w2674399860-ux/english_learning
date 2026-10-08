import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../l10n/l10n.dart';
import '../../models/learning_record.dart';
import '../../providers/app_provider.dart';
import '../../theme/theme_x.dart';
import '../../widgets/confirm_dialog.dart';
import '../../widgets/error_notice.dart';
import '../../widgets/history_list_parts.dart';
import '../../widgets/history_record_card.dart';
import '../../widgets/illustration.dart';
import '../../widgets/ink_toast.dart';
import '../../widgets/page_scaffold.dart';
import '../../widgets/state_view.dart';
import '../auth/account_actions.dart';
import 'history_detail_page.dart';

/// 历史列表主体显示哪一种状态。
enum HistoryBodyState { loading, loadFailed, empty, noMatch, list }

/// 选择历史列表主体的状态（纯函数）。
/// 遗留问题 #12：没有记录且加载失败时是 [HistoryBodyState.loadFailed]，
/// 不再落到"还没有记录"，免得用户误以为真的没有记录。
HistoryBodyState historyBodyState({
  required bool isLoading,
  required bool hasRecords,
  required String? error,
  required String query,
}) {
  if (isLoading) return HistoryBodyState.loading;
  if (hasRecords) return HistoryBodyState.list;
  if (error != null) return HistoryBodyState.loadFailed;
  return query.isEmpty ? HistoryBodyState.empty : HistoryBodyState.noMatch;
}

/// 历史列表（设计稿 ai_4）：搜索、记录卡片、加载更多、删除。
///
/// 状态：首次加载中；没有记录（引导去拍照）；搜索无结果（清空搜索）；
/// 加载失败且没有记录（只显示错误条与"重试"，不再同时显示"还没有记录"——遗留问题 #12）；
/// 加载更多失败 / 删除失败（错误条在列表上方，列表保留）；加载更多中；全部加载完；删除确认。
class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key, this.onGoHome});

  /// 空状态"去拍照"：切到首页 Tab。由 MainScreen 提供。
  final VoidCallback? onGoHome;

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

  Future<void> _confirmDelete(LearningRecord record) async {
    final l10n = context.l10n;
    final provider = context.read<AppProvider>();
    // 只列前 3 个单词（U-10 I-b）
    final words = record.words;
    final message = words.isEmpty
        ? l10n.deleteDialogBody
        : '${l10n.deleteDialogBody}\n'
              '${l10n.deleteDialogWords(words.take(3).join('、'), words.length)}';

    final confirmed = await showConfirmDialog(
      context,
      title: l10n.deleteDialogTitle,
      message: message,
      confirmLabel: l10n.deleteDialogConfirm,
    );
    if (!confirmed || record.id == null || !mounted) return;

    await provider.deleteRecord(record.id!);
    // 删除成功与否由删除后有没有错误判断（AppProvider 不改）；失败时列表上方显示错误条
    if (mounted && provider.historyError == null) {
      showInkToast(context, l10n.historyDeleted);
    }
  }

  void _openDetail(LearningRecord record) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => HistoryDetailPage(record: record)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final c = context.colors;
    final l10n = context.l10n;
    final provider = context.watch<AppProvider>();
    final error = provider.historyError;
    final hasRecords = provider.records.isNotEmpty;

    return PageScaffold(
      appBar: AppBar(
        title: Text(l10n.historyTitle, style: context.text.titleLarge),
        leading: Padding(
          padding: EdgeInsets.all(tokens.spaceSm),
          child: ExcludeSemantics(
            child: Image.asset(
              IllustrationKind.mascot.asset,
              width: tokens.avatarSize,
              height: tokens.avatarSize,
            ),
          ),
        ),
        actions: const [AccountActions()],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(
              tokens.pageMargin,
              tokens.spaceLg,
              tokens.pageMargin,
              0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                HistorySearchField(
                  controller: _searchController,
                  onChanged: _onSearchChanged,
                  onSubmitted: _searchNow,
                  onClear: _clearSearch,
                ),
                SizedBox(height: tokens.spaceMd),
                Row(
                  children: [
                    Icon(
                      Icons.lightbulb,
                      size: tokens.iconSm,
                      color: c.tertiary,
                    ),
                    SizedBox(width: tokens.spaceXs),
                    Expanded(
                      child: Text(
                        l10n.historySearchTip,
                        style: context.text.labelSmall?.copyWith(
                          color: c.onSurfaceVariant,
                        ),
                      ),
                    ),
                    if (hasRecords && !provider.isLoadingHistory)
                      _TotalBadge(total: provider.historyTotal),
                  ],
                ),
                if (error != null && hasRecords) ...[
                  SizedBox(height: tokens.spaceMd),
                  ErrorNotice(message: error),
                ],
              ],
            ),
          ),
          Expanded(child: _buildBody(provider)),
        ],
      ),
    );
  }

  Widget _buildBody(AppProvider provider) {
    final tokens = context.tokens;
    final l10n = context.l10n;

    final records = provider.records;
    final state = historyBodyState(
      isLoading: provider.isLoadingHistory,
      hasRecords: records.isNotEmpty,
      error: provider.historyError,
      query: provider.historyQuery,
    );
    switch (state) {
      case HistoryBodyState.loading:
        return StateView(
          illustration: IllustrationKind.mascot,
          title: l10n.historyLoadingMore,
          isLoading: true,
        );
      case HistoryBodyState.loadFailed:
        return Padding(
          padding: EdgeInsets.all(tokens.pageMargin),
          child: Align(
            alignment: Alignment.topCenter,
            child: ErrorNotice(
              message: provider.historyError!,
              onRetry: provider.loadRecords,
            ),
          ),
        );
      case HistoryBodyState.empty:
      case HistoryBodyState.noMatch:
        return HistoryEmptyState(
          query: provider.historyQuery,
          onClearSearch: _clearSearch,
          onGoHome: widget.onGoHome,
        );
      case HistoryBodyState.list:
        break;
    }

    return ListView.separated(
      padding: EdgeInsets.fromLTRB(
        tokens.pageMargin,
        tokens.spaceXl,
        tokens.pageMargin,
        tokens.pageMargin,
      ),
      itemCount: records.length + 1,
      separatorBuilder: (_, _) => SizedBox(height: tokens.spaceXl),
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
        return HistoryRecordCard(
          record: record,
          index: index,
          onTap: () => _openDetail(record),
          onDelete: () => _confirmDelete(record),
        );
      },
    );
  }
}

/// "共 N 条"小徽章（Q-F8）。
class _TotalBadge extends StatelessWidget {
  const _TotalBadge({required this.total});

  final int total;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final c = context.colors;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: tokens.spaceMd,
        vertical: tokens.spaceXxs,
      ),
      decoration: BoxDecoration(
        color: c.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(tokens.radiusLg),
        boxShadow: tokens.hardShadow(tokens.shadowSmall),
      ),
      child: Text(
        context.l10n.historyTotal(total),
        style: context.text.labelSmall?.copyWith(color: c.onSurfaceVariant),
      ),
    );
  }
}
