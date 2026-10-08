import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../theme/theme_x.dart';
import 'illustration.dart';
import 'ink_button.dart';
import 'state_view.dart';

/// 历史列表底部（设计稿 ai_4）：还有更多时是"加载更多（20 / 57）"按钮，
/// 加载中按钮内显示进度圈与"正在加载…"，全部加载完显示"已显示全部 N 条记录"。
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
    final tokens = context.tokens;
    final l10n = context.l10n;
    final Widget child;
    if (isLoadingMore || loaded < total) {
      child = InkButton(
        label: l10n.historyLoadMore(loaded, total),
        leadingIcon: Icons.expand_more,
        variant: InkButtonVariant.paper,
        isLoading: isLoadingMore,
        loadingLabel: l10n.historyLoadingMore,
        onPressed: isLoadingMore ? null : onLoadMore,
      );
    } else {
      child = Center(
        child: Text(
          l10n.historyAllLoaded(total),
          style: context.text.bodySmall?.copyWith(
            color: context.colors.outline,
          ),
        ),
      );
    }

    return Padding(
      padding: EdgeInsets.symmetric(vertical: tokens.spaceLg),
      child: child,
    );
  }
}

/// 历史列表为空：没有记录时引导去拍照；有搜索词时说明没有匹配，并提供清空搜索。
class HistoryEmptyState extends StatelessWidget {
  const HistoryEmptyState({
    super.key,
    required this.query,
    required this.onClearSearch,
    this.onGoHome,
  });

  final String query;
  final VoidCallback onClearSearch;

  /// 切到首页 Tab（"去拍照"）；为 null 时不显示按钮。
  final VoidCallback? onGoHome;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    if (query.isEmpty) {
      return StateView(
        illustration: IllustrationKind.mascot,
        title: l10n.historyEmptyTitle,
        message: l10n.historyEmptyBody,
        primaryAction: onGoHome == null
            ? null
            : StateAction(
                label: l10n.historyEmptyAction,
                icon: Icons.photo_camera,
                onPressed: onGoHome!,
              ),
      );
    }

    return StateView(
      illustration: IllustrationKind.sad,
      title: l10n.historyNoMatch(query),
      primaryAction: StateAction(
        label: l10n.historySearchClear,
        icon: Icons.search_off,
        onPressed: onClearSearch,
      ),
    );
  }
}

/// 历史搜索框（设计稿 ai_4）：白底、硬阴影、左侧放大镜，有内容时右侧出现清空按钮。
class HistorySearchField extends StatelessWidget {
  const HistorySearchField({
    super.key,
    required this.controller,
    required this.onChanged,
    required this.onSubmitted,
    required this.onClear,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onSubmitted;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final c = context.colors;
    final l10n = context.l10n;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: tokens.cardSurface,
        borderRadius: BorderRadius.circular(tokens.radiusMd),
        boxShadow: tokens.hardShadow(tokens.shadowButton),
      ),
      child: ValueListenableBuilder<TextEditingValue>(
        valueListenable: controller,
        builder: (context, value, _) => TextField(
          controller: controller,
          textInputAction: TextInputAction.search,
          style: context.text.bodyMedium,
          decoration: InputDecoration(
            hintText: l10n.historySearchHint,
            fillColor: tokens.cardSurface,
            prefixIcon: Icon(Icons.search, color: c.onSurfaceVariant),
            suffixIcon: value.text.isEmpty
                ? null
                : IconButton(
                    icon: Icon(Icons.cancel, color: c.onSurfaceVariant),
                    tooltip: l10n.historySearchClear,
                    onPressed: onClear,
                  ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(tokens.radiusMd),
              borderSide: BorderSide.none,
            ),
          ),
          onChanged: onChanged,
          onSubmitted: onSubmitted,
        ),
      ),
    );
  }
}
