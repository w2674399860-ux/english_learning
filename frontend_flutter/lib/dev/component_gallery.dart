import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../models/learning_record.dart';
import '../pages/ocr/ocr_status_view.dart';
import '../pages/words/confirm_action_bar.dart';
import '../providers/difficulty.dart';
import '../providers/flow_phase.dart';
import '../services/api_response.dart';
import '../theme/theme_x.dart';
import '../widgets/account_menu.dart';
import '../widgets/blank_text.dart';
import '../widgets/confirm_dialog.dart';
import '../widgets/degraded_banner.dart';
import '../widgets/difficulty_selector.dart';
import '../widgets/error_notice.dart';
import '../widgets/hero_action_button.dart';
import '../widgets/history_list_parts.dart';
import '../widgets/history_record_card.dart';
import '../widgets/highlighted_text.dart';
import '../widgets/illustration.dart';
import '../widgets/ink_button.dart';
import '../widgets/ink_card.dart';
import '../widgets/ink_text_field.dart';
import '../widgets/ink_toast.dart';
import '../widgets/page_scaffold.dart';
import '../widgets/phase_indicator.dart';
import '../widgets/save_button.dart';
import '../widgets/section_card.dart';
import '../widgets/state_view.dart';
import '../widgets/tip_card.dart';
import '../widgets/word_chip.dart';
import '../widgets/word_tag.dart';

/// 调试用组件展示页（U-12 第 1 批）：逐个展示公共组件及其状态，供截图与真机检查。
///
/// 只在 `flutter run --dart-define=SHOW_GALLERY=true` 的调试构建中可达（见 main.dart），
/// 不面向用户，分组标题直接写在这里、不进 ARB。示例单词与短文取自 stitch.md 的设计示例。
class ComponentGallery extends StatefulWidget {
  const ComponentGallery({super.key});

  @override
  State<ComponentGallery> createState() => _ComponentGalleryState();
}

const _sampleWords = [
  'harvest',
  'lantern',
  'journey',
  'ancient',
  'courage',
  'whisper',
  'bridge',
  'forest',
  'silver',
  'mountain',
  'window',
  'yellow',
  'river',
  'apple',
  'brave',
  'gentle',
  'valley',
  'promise',
  'page',
  'Unit 3',
];
const _sampleStory =
    'Every autumn, Mia walked through the forest to help her grandmother with '
    'the apple harvest. This year, the journey felt different.';
const _sampleTranslation =
    '每年秋天，米娅都会穿过森林 (forest)，去帮奶奶收获 (harvest) 苹果 (apple)。';

class _ComponentGalleryState extends State<ComponentGallery> {
  final Set<String> _selected = {..._sampleWords}
    ..removeAll(['page', 'Unit 3']);
  final List<String> _words = [..._sampleWords];
  Difficulty _difficulty = Difficulty.defaultValue;
  bool _loading = false;
  final TextEditingController _search = TextEditingController();
  final TextEditingController _addWord = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    _addWord.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final l10n = context.l10n;

    Widget section(String title, List<Widget> children) => Padding(
      padding: EdgeInsets.only(bottom: tokens.spaceXl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: context.text.headlineSmall),
          SizedBox(height: tokens.spaceMd),
          for (final c in children) ...[c, SizedBox(height: tokens.spaceMd)],
        ],
      ),
    );

    return PageScaffold(
      appBar: AppBar(
        title: const Text('组件展示（调试）'),
        actions: [
          AccountMenu(
            username: 'mia_2026',
            onChangePassword: () =>
                showInkToast(context, l10n.accountChangePassword),
            onLogout: () => showConfirmDialog(
              context,
              title: l10n.logoutDialogTitle,
              confirmLabel: l10n.logoutDialogConfirm,
              icon: Icons.logout,
            ),
          ),
        ],
      ),
      banner: const DegradedBanner(reason: 'ai_unavailable'),
      body: ListView(
        padding: EdgeInsets.all(tokens.pageMargin),
        children: [
          section('文字层级', [
            Text('displayMedium AI 英语学习', style: context.text.displayMedium),
            Text('headlineLarge 用 AI 学英语', style: context.text.headlineLarge),
            Text('headlineMedium 识别失败', style: context.text.headlineMedium),
            Text(
              'titleMedium 英文短文 English Story',
              style: context.text.titleMedium,
            ),
            Text('bodyLarge $_sampleStory', style: context.text.bodyLarge),
            Text('bodyMedium 上传一张照片，提取英文单词', style: context.text.bodyMedium),
            Text('bodySmall 只能搜索英文单词或短语', style: context.text.bodySmall),
            Text('labelLarge 添加 Add', style: context.text.labelLarge),
            Text('labelMedium 用户名 Username', style: context.text.labelMedium),
            Text(
              'labelSmall 10月5日 13:28 · 中级 · 18 词',
              style: context.text.labelSmall,
            ),
          ]),
          section('主按钮 InkButton', [
            InkButton(
              label: l10n.loginButton,
              trailingIcon: Icons.arrow_circle_right,
              onPressed: () => showInkToast(context, l10n.saveSuccess),
            ),
            InkButton(
              label: l10n.confirmGenerate,
              leadingIcon: Icons.auto_awesome,
              isLoading: _loading,
              loadingLabel: l10n.confirmGenerating,
              onPressed: () => setState(() => _loading = !_loading),
            ),
            InkButton(label: l10n.confirmGenerate, onPressed: null),
            InkButton(
              label: l10n.exportPdf,
              leadingIcon: Icons.picture_as_pdf,
              isLoading: true,
              loadingLabel: l10n.exportPdfInProgress,
              onPressed: () {},
            ),
          ]),
          section('次级按钮（compact）', [
            Wrap(
              spacing: tokens.spaceMd,
              runSpacing: tokens.spaceMd,
              children: [
                for (final v in InkButtonVariant.values)
                  InkButton(
                    label: v.name,
                    variant: v,
                    compact: true,
                    onPressed: () {},
                  ),
                InkButton(
                  label: l10n.confirmAddButton,
                  leadingIcon: Icons.add,
                  variant: InkButtonVariant.lime,
                  compact: true,
                  onPressed: null,
                ),
              ],
            ),
          ]),
          section('首页入口 HeroActionButton', [
            HeroActionButton(
              icon: Icons.photo_library,
              title: l10n.homeGallery,
              subtitle: l10n.homeGallerySubtitle,
              onPressed: () {},
            ),
            HeroActionButton(
              icon: Icons.photo_camera,
              title: l10n.homeCamera,
              subtitle: l10n.homeCameraSubtitle,
              lime: true,
              onPressed: () {},
            ),
          ]),
          section('可勾选单词 WordChip（点按切换、× 删除）', [
            Wrap(
              spacing: tokens.spaceMd,
              runSpacing: tokens.spaceMd,
              children: [
                for (final w in _words)
                  WordChip(
                    word: w,
                    selected: _selected.contains(w),
                    onToggle: () => setState(() {
                      if (!_selected.remove(w)) _selected.add(w);
                    }),
                    onDelete: () => setState(() {
                      _words.remove(w);
                      _selected.remove(w);
                    }),
                  ),
                WordChip(
                  word: 'disabled',
                  selected: true,
                  enabled: false,
                  onToggle: () {},
                  onDelete: () {},
                ),
              ],
            ),
            Text(l10n.confirmSelectedCount(_selected.length, 20)),
          ]),
          section('只读单词 WordTagWrap（最多显示 5 个）', [
            WordTagWrap(words: _sampleWords, maxVisible: 5),
            const WordTagWrap(words: ['apple', 'river', 'brave']),
          ]),
          section('难度 DifficultySelector', [
            DifficultySelector(
              value: _difficulty,
              onChanged: (d) => setState(() => _difficulty = d),
            ),
            const DifficultySelector(value: Difficulty.beginner),
          ]),
          section('输入框 InkTextField', [
            InkTextField(
              label: l10n.usernameLabel,
              icon: Icons.account_circle,
              hint: l10n.usernameHint,
              helper: l10n.usernameRule,
            ),
            InkTextField(
              label: l10n.passwordLabel,
              icon: Icons.lock,
              hint: l10n.passwordHint,
              isPassword: true,
              errorText: l10n.validationPasswordTooShort,
            ),
            InkTextField(
              label: l10n.currentPasswordLabel,
              icon: Icons.key,
              hint: l10n.currentPasswordHint,
              enabled: false,
            ),
          ]),
          section('提示卡 / 错误条', [
            TipCard(title: l10n.homeTipTitle, body: l10n.homeTipBody),
            TipCard(title: l10n.securityTipTitle, body: l10n.securityTipBody),
            ErrorNotice(
              message: l10n.confirmGenerateFailed(l10n.errorNetwork),
              onRetry: () {},
            ),
            ErrorNotice(message: l10n.loginEmptyFields),
          ]),
          section('卡片 / 分节卡片', [
            InkCard(child: Text(l10n.loginForgotPassword)),
            SectionCard(
              title: l10n.sectionWords,
              icon: Icons.auto_stories,
              iconBackground: context.colors.secondaryContainer,
              badge: '20',
              child: const WordTagWrap(words: _sampleWords),
            ),
            SectionCard(
              title: l10n.sectionEnglishStory,
              child: const HighlightedText.english(
                text: _sampleStory,
                words: _sampleWords,
              ),
            ),
            SectionCard(
              title: l10n.sectionChineseTranslation,
              icon: Icons.translate,
              iconBackground: context.colors.tertiaryFixed,
              child: const HighlightedText.chinese(
                text: _sampleTranslation,
                words: _sampleWords,
              ),
            ),
          ]),
          section('对话框 / Toast', [
            InkButton(
              label: l10n.deleteDialogTitle,
              variant: InkButtonVariant.danger,
              compact: true,
              onPressed: () => showConfirmDialog(
                context,
                title: l10n.deleteDialogTitle,
                message:
                    '${l10n.deleteDialogBody}\n'
                    '${l10n.deleteDialogWords('harvest、lantern、journey', 18)}',
                confirmLabel: l10n.deleteDialogConfirm,
              ),
            ),
            InkButton(
              label: 'Toast（错误）',
              variant: InkButtonVariant.paper,
              compact: true,
              onPressed: () =>
                  showInkToast(context, l10n.exportPdfFailed, isError: true),
            ),
          ]),
          section('插画 Illustration', [
            Wrap(
              spacing: tokens.spaceMd,
              children: [
                for (final k in IllustrationKind.values)
                  Illustration(kind: k, size: tokens.illustrationSizeSm),
              ],
            ),
          ]),
          section('整页状态 StateView / PhaseIndicator', [
            _Framed(child: const PhaseIndicator(phase: FlowPhase.recognizing)),
            _Framed(
              child: StateView(
                illustration: IllustrationKind.sad,
                title: l10n.ocrFailedTitle,
                message: l10n.errorTimeout,
                primaryAction: StateAction(
                  label: l10n.ocrRetry,
                  icon: Icons.refresh,
                  onPressed: () {},
                ),
                secondaryAction: StateAction(
                  label: l10n.ocrBackHome,
                  onPressed: () {},
                ),
              ),
            ),
            _Framed(
              child: StateView(
                illustration: IllustrationKind.sad,
                illustrationBadge: CircleAvatar(
                  backgroundColor: context.colors.errorContainer,
                  child: Icon(
                    Icons.wifi_off,
                    color: context.colors.onErrorContainer,
                  ),
                ),
                title: l10n.ocrNetworkTitle,
                message: l10n.ocrNetworkBody,
              ),
            ),
            _Framed(
              child: StateView(
                illustration: IllustrationKind.mascot,
                title: l10n.historyEmptyTitle,
                message: l10n.historyEmptyBody,
                primaryAction: StateAction(
                  label: l10n.historyEmptyAction,
                  icon: Icons.photo_camera,
                  onPressed: () {},
                ),
              ),
            ),
            FilledButton(
              onPressed: null,
              child: PhaseIndicator(phase: FlowPhase.generating, compact: true),
            ),
          ]),
          section('识别失败 OcrStatusView（可重试 / 次数用完 / 网络）', [
            for (final kind in FlowErrorKind.values)
              _Framed(
                child: OcrStatusView(
                  isRecognizing: false,
                  error: l10n.errorTimeout,
                  errorKind: kind,
                  onRetry: () {},
                  onRepick: () {},
                ),
              ),
          ]),
          section('确认页底部 ConfirmActionBar（默认 / 生成中 / 生成失败）', [
            ConfirmActionBar(
              addController: _addWord,
              onAdd: () {},
              difficulty: _difficulty,
              onDifficultyChanged: (d) => setState(() => _difficulty = d),
              isGenerating: false,
              canGenerate: true,
              hasResult: false,
              onGenerate: () {},
              onRetry: () {},
            ),
            ConfirmActionBar(
              addController: _addWord,
              onAdd: () {},
              difficulty: _difficulty,
              onDifficultyChanged: (_) {},
              isGenerating: true,
              canGenerate: true,
              hasResult: true,
              onGenerate: () {},
              onRetry: () {},
            ),
            ConfirmActionBar(
              addController: _addWord,
              onAdd: () {},
              difficulty: _difficulty,
              onDifficultyChanged: (_) {},
              isGenerating: false,
              canGenerate: true,
              hasResult: true,
              onGenerate: () {},
              onRetry: () {},
              error: l10n.confirmGenerateFailed(l10n.errorTimeout),
              errorKind: FlowErrorKind.retryable,
            ),
          ]),
          section('保存按钮 SaveButton（可保存 / 保存中 / 已保存）', [
            Wrap(
              spacing: tokens.spaceMd,
              runSpacing: tokens.spaceMd,
              children: [
                SaveButton(isSaving: false, isSaved: false, onPressed: () {}),
                SaveButton(isSaving: true, isSaved: false, onPressed: () {}),
                SaveButton(isSaving: false, isSaved: true, onPressed: () {}),
              ],
            ),
          ]),
          section('填空 BlankText', [
            const BlankText(
              text:
                  'Every autumn, Mia walked through the ___ to help her '
                  'grandmother with the ___ ___.',
              english: true,
            ),
            const BlankText(text: '每年秋天，米娅都会穿过___ (___)。', english: false),
          ]),
          section('历史：搜索框、记录卡片、底部', [
            HistorySearchField(
              controller: _search,
              onChanged: (_) {},
              onSubmitted: (_) {},
              onClear: _search.clear,
            ),
            SizedBox(height: tokens.spaceLg),
            for (var i = 0; i < 2; i++) ...[
              HistoryRecordCard(
                record: LearningRecord(
                  words: i == 0 ? _sampleWords : _sampleWords.take(3).toList(),
                  englishStory: _sampleStory,
                  chineseTranslation: _sampleTranslation,
                  englishBlank: '',
                  chineseBlank: '',
                  difficulty: Difficulty.values[i + 1],
                  createdAt: '2026-10-05T05:28:31.384Z',
                ),
                index: i,
                onTap: () {},
                onDelete: () {},
              ),
              SizedBox(height: tokens.spaceXl),
            ],
            HistoryListFooter(
              loaded: 20,
              total: 57,
              isLoadingMore: false,
              onLoadMore: () {},
            ),
            const HistoryListFooter(
              loaded: 20,
              total: 57,
              isLoadingMore: true,
              onLoadMore: null,
            ),
            const HistoryListFooter(
              loaded: 57,
              total: 57,
              isLoadingMore: false,
              onLoadMore: null,
            ),
          ]),
        ],
      ),
    );
  }
}

/// 给整页状态加一个固定高度的框，方便在列表中并排查看。
class _Framed extends StatelessWidget {
  const _Framed({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Container(
      height: tokens.maxContentWidth * 1.3,
      decoration: BoxDecoration(
        border: Border.all(color: context.colors.outlineVariant),
        borderRadius: BorderRadius.circular(tokens.radiusMd),
      ),
      child: child,
    );
  }
}
