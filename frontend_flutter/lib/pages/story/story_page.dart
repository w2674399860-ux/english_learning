import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../l10n/l10n.dart';
import '../../models/learning_record.dart';
import '../../providers/app_provider.dart';
import '../../theme/theme_x.dart';
import '../../widgets/blank_text.dart';
import '../../widgets/degraded_banner.dart';
import '../../widgets/highlighted_text.dart';
import '../../widgets/ink_button.dart';
import '../../widgets/ink_toast.dart';
import '../../widgets/page_scaffold.dart';
import '../../widgets/save_button.dart';
import '../../widgets/section_card.dart';
import '../../widgets/word_tag.dart';

/// 学习结果页（设计稿 _1）：本次单词、英文短文、中文翻译、两份填空；右上角保存。
///
/// 状态：未保存 / 保存中 / 已保存（不可再点）/ 保存失败（错误 Toast，按钮恢复）；
/// AI 降级（顶部提示条）；没有结果（"暂无数据"，正常流程到不了）。
class StoryPage extends StatelessWidget {
  const StoryPage({super.key});

  Future<void> _save(BuildContext context) async {
    final provider = context.read<AppProvider>();
    final l10n = context.l10n;

    final saved = await provider.saveCurrentRecord();
    if (!context.mounted) return;

    if (saved) {
      showInkToast(context, l10n.saveSuccess);
    } else if (provider.saveError != null) {
      showInkToast(context, provider.saveError!, isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final tokens = context.tokens;
    final record = provider.currentRecord;
    final degradedReason = provider.storyDegradedReason;

    return PageScaffold(
      appBar: AppBar(
        title: Text(context.l10n.storyTitle),
        actions: [
          if (record != null)
            Padding(
              padding: EdgeInsets.only(right: tokens.spaceMd),
              child: Center(
                child: SaveButton(
                  isSaving: provider.isSaving,
                  isSaved: provider.isSaved,
                  onPressed: () => _save(context),
                ),
              ),
            ),
        ],
      ),
      banner: degradedReason == null
          ? null
          : DegradedBanner(reason: degradedReason),
      body: record == null
          ? Center(child: Text(context.l10n.storyNoData))
          : StoryContent(
              record: record,
              footer: InkButton(
                label: context.l10n.storyBackToEdit,
                leadingIcon: Icons.arrow_back,
                variant: InkButtonVariant.paper,
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
    );
  }
}

/// 一条学习内容的阅读区：元信息条与五个分节卡片。学习结果页与历史详情页共用。
/// 正文可以选中复制。
class StoryContent extends StatelessWidget {
  const StoryContent({
    super.key,
    required this.record,
    this.header,
    this.footer,
  });

  final LearningRecord record;

  /// 元信息条上方的附加内容（历史详情页的保存时间等）。
  final Widget? header;

  /// 最后一张卡片下方的附加内容（"返回修改单词"等）。
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final c = context.colors;
    final l10n = context.l10n;
    final gap = SizedBox(height: tokens.spaceLg);
    final hintStyle = context.text.bodySmall?.copyWith(
      color: c.onSurfaceVariant,
    );

    return SelectionArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.all(tokens.pageMargin),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (header != null) ...[header!, gap],
            _RecordMeta(record: record),
            gap,
            SectionCard(
              title: l10n.sectionWords,
              icon: Icons.auto_stories,
              iconBackground: c.secondaryContainer,
              child: WordTagWrap(words: record.words),
            ),
            gap,
            SectionCard(
              title: l10n.sectionEnglishStory,
              icon: Icons.menu_book,
              iconBackground: c.primaryFixed,
              child: HighlightedText.english(
                text: record.englishStory,
                words: record.words,
              ),
            ),
            gap,
            SectionCard(
              title: l10n.sectionChineseTranslation,
              icon: Icons.translate,
              iconBackground: c.tertiaryFixed,
              child: HighlightedText.chinese(
                text: record.chineseTranslation,
                words: record.words,
              ),
            ),
            gap,
            SectionCard(
              title: l10n.sectionEnglishBlank,
              icon: Icons.edit_note,
              iconBackground: c.primaryContainer,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l10n.englishBlankHint, style: hintStyle),
                  SizedBox(height: tokens.spaceSm),
                  BlankText(text: record.englishBlank, english: true),
                ],
              ),
            ),
            gap,
            SectionCard(
              title: l10n.sectionChineseBlank,
              icon: Icons.quiz,
              iconBackground: c.secondaryFixed,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l10n.chineseBlankHint, style: hintStyle),
                  SizedBox(height: tokens.spaceSm),
                  BlankText(text: record.chineseBlank, english: false),
                ],
              ),
            ),
            if (footer != null) ...[SizedBox(height: tokens.spaceXl), footer!],
          ],
        ),
      ),
    );
  }
}

/// 元信息条："18 个单词 · 中级"（Q-F3）。
class _RecordMeta extends StatelessWidget {
  const _RecordMeta({required this.record});

  final LearningRecord record;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final c = context.colors;
    final l10n = context.l10n;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: tokens.spaceLg,
        vertical: tokens.spaceMd,
      ),
      decoration: BoxDecoration(
        color: c.surfaceContainerLow,
        borderRadius: BorderRadius.circular(tokens.radiusMd),
        boxShadow: tokens.hardShadow(tokens.shadowSmall),
      ),
      child: Row(
        children: [
          Icon(Icons.stars, size: tokens.iconMd, color: c.tertiaryContainer),
          SizedBox(width: tokens.spaceSm),
          Expanded(
            child: Text(
              l10n.recordMeta(
                record.words.length,
                difficultyLabel(l10n, record.difficulty),
              ),
              style: context.text.labelMedium,
            ),
          ),
        ],
      ),
    );
  }
}
