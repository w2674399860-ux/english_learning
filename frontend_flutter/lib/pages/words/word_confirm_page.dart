import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../l10n/l10n.dart';
import '../../providers/app_provider.dart';
import '../../theme/theme_x.dart';
import '../../widgets/degraded_banner.dart';
import '../../widgets/error_notice.dart';
import '../../widgets/ink_button.dart';
import '../../widgets/ink_toast.dart';
import '../../widgets/page_scaffold.dart';
import '../../widgets/tip_card.dart';
import '../../widgets/word_chip.dart';
import '../story/story_page.dart';
import 'confirm_action_bar.dart';

/// 识别完成后的单词确认页（设计稿 ai_1）：勾选、删除、手动添加，确认后再生成短文。
///
/// 状态：默认（全部选中）；一个都没选或超过 20 个（生成禁用，后者有提示）；
/// 没有识别出单词；生成中（单词、添加、难度都禁用）；生成失败（底部错误条，可重试时带"重试"）；
/// 已生成过（"重新生成"）；OCR 降级（顶部提示条）；添加单词校验失败（Toast）。
class WordConfirmPage extends StatefulWidget {
  const WordConfirmPage({super.key});

  @override
  State<WordConfirmPage> createState() => _WordConfirmPageState();
}

class _WordConfirmPageState extends State<WordConfirmPage> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _addWord() {
    final result = context.read<AppProvider>().addWord(_controller.text);

    if (result == AddWordResult.added) {
      _controller.clear();
      return;
    }

    final l10n = context.l10n;
    final message = switch (result) {
      AddWordResult.empty => l10n.addWordEmpty,
      AddWordResult.noLetter => l10n.addWordNoLetter,
      AddWordResult.tooLong => l10n.addWordTooLong(maxWordLength),
      AddWordResult.duplicate => l10n.addWordDuplicate,
      AddWordResult.added => '',
    };
    showInkToast(context, message, isError: true);
  }

  Future<void> _generate() async {
    final provider = context.read<AppProvider>();
    final navigator = Navigator.of(context);

    await provider.generateFromWords(provider.selectedWordsInOrder);
    if (!mounted) return;

    // 生成失败时留在本页展示错误，用户可直接重试，无需返回。
    if (provider.error != null) return;

    navigator.push(MaterialPageRoute(builder: (_) => const StoryPage()));
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final busy = provider.isBusy;
    final selectedCount = provider.selectedWords.length;
    final tooMany = selectedCount > maxWordsPerCompose;
    final degraded = provider.ocrDegradedReason;

    return PageScaffold(
      appBar: AppBar(title: Text(context.l10n.confirmTitle)),
      banner: degraded == null ? null : DegradedBanner(reason: degraded),
      body: _WordArea(
        provider: provider,
        busy: busy,
        selectedCount: selectedCount,
        tooMany: tooMany,
      ),
      bottom: ConfirmActionBar(
        addController: _controller,
        onAdd: _addWord,
        difficulty: provider.difficulty,
        onDifficultyChanged: provider.setDifficulty,
        isGenerating: busy,
        canGenerate: selectedCount > 0 && !tooMany,
        hasResult: provider.currentRecord != null,
        onGenerate: _generate,
        onRetry: () {
          provider.clearError();
          _generate();
        },
        error: provider.error,
        errorKind: provider.errorKind,
      ),
    );
  }
}

/// 可滚动的单词区：操作说明、"已选 N / 20"与全选 / 清空、单词标签或空状态。
class _WordArea extends StatelessWidget {
  const _WordArea({
    required this.provider,
    required this.busy,
    required this.selectedCount,
    required this.tooMany,
  });

  final AppProvider provider;
  final bool busy;
  final int selectedCount;
  final bool tooMany;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final c = context.colors;
    final l10n = context.l10n;
    final words = provider.recognizedWords;
    final selected = provider.selectedWords;

    return SingleChildScrollView(
      padding: EdgeInsets.all(tokens.pageMargin),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TipCard(title: l10n.confirmTipTitle, body: l10n.confirmTipBody),
          SizedBox(height: tokens.spaceXl),
          Row(
            children: [
              Expanded(
                child: Text(
                  l10n.confirmSelectedCount(selectedCount, maxWordsPerCompose),
                  style: context.text.titleMedium?.copyWith(
                    color: tooMany ? c.error : null,
                  ),
                ),
              ),
              InkButton(
                label: l10n.confirmSelectAll,
                leadingIcon: Icons.check_circle,
                variant: InkButtonVariant.paper,
                compact: true,
                onPressed: busy || words.isEmpty ? null : provider.selectAll,
              ),
              SizedBox(width: tokens.spaceSm),
              InkButton(
                label: l10n.confirmClearSelection,
                leadingIcon: Icons.restart_alt,
                variant: InkButtonVariant.paper,
                compact: true,
                onPressed: busy || selected.isEmpty
                    ? null
                    : provider.clearSelection,
              ),
            ],
          ),
          if (tooMany) ...[
            SizedBox(height: tokens.spaceMd),
            ErrorNotice(message: l10n.confirmTooManyWords(maxWordsPerCompose)),
          ],
          SizedBox(height: tokens.spaceLg),
          if (words.isEmpty)
            Text(
              l10n.confirmEmpty,
              style: context.text.bodyMedium?.copyWith(
                color: c.onSurfaceVariant,
              ),
            )
          else
            Wrap(
              spacing: tokens.spaceMd,
              runSpacing: tokens.spaceMd,
              children: [
                for (final w in words)
                  WordChip(
                    word: w,
                    selected: selected.contains(w),
                    enabled: !busy,
                    onToggle: () => provider.toggleWord(w),
                    onDelete: () => provider.removeWord(w),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}
