import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import '../../providers/difficulty.dart';
import '../../services/api_response.dart';
import '../../theme/theme_x.dart';
import '../../widgets/difficulty_selector.dart';
import '../../widgets/error_notice.dart';
import '../../widgets/ink_button.dart';

/// 确认页底部固定的操作区（设计稿 ai_1）。只接收参数，不读 Provider，便于测试。
///
/// 从上到下：生成失败的错误条（放在这里，正在看底部按钮的用户也能注意到）、
/// 添加单词、难度、生成按钮。生成中时添加单词与难度禁用（Q-F11）。
class ConfirmActionBar extends StatelessWidget {
  const ConfirmActionBar({
    super.key,
    required this.addController,
    required this.onAdd,
    required this.difficulty,
    required this.onDifficultyChanged,
    required this.isGenerating,
    required this.canGenerate,
    required this.hasResult,
    required this.onGenerate,
    required this.onRetry,
    this.error,
    this.errorKind,
  });

  final TextEditingController addController;
  final VoidCallback onAdd;
  final Difficulty difficulty;
  final ValueChanged<Difficulty> onDifficultyChanged;
  final bool isGenerating;

  /// 至少选了一个、且不超过上限时为 true。
  final bool canGenerate;

  /// 已经生成过（从结果页返回）：按钮显示"重新生成"。
  final bool hasResult;
  final VoidCallback onGenerate;
  final VoidCallback onRetry;

  /// 生成失败的文案（"生成失败：…"）；null 表示没有失败。
  final String? error;
  final FlowErrorKind? errorKind;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final c = context.colors;
    final l10n = context.l10n;
    // 次数用完（429）、参数错误等重试没有意义，不显示"重试"
    final retryable = errorKind != FlowErrorKind.notRetryable;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: c.surface,
        border: Border(top: BorderSide(color: c.surfaceContainerHigh)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            tokens.pageMargin,
            tokens.spaceMd,
            tokens.pageMargin,
            tokens.spaceLg,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (error != null) ...[
                ErrorNotice(
                  message: error!,
                  onRetry: retryable ? onRetry : null,
                ),
                SizedBox(height: tokens.spaceMd),
              ],
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: addController,
                      enabled: !isGenerating,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => onAdd(),
                      style: context.text.bodyMedium,
                      decoration: InputDecoration(
                        hintText: l10n.confirmAddHint,
                        constraints: BoxConstraints(
                          minHeight: tokens.inlineInputHeight,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: tokens.spaceSm),
                  InkButton(
                    label: l10n.confirmAddButton,
                    leadingIcon: Icons.add,
                    variant: InkButtonVariant.lime,
                    compact: true,
                    onPressed: isGenerating ? null : onAdd,
                  ),
                ],
              ),
              SizedBox(height: tokens.spaceMd),
              DifficultySelector(
                value: difficulty,
                onChanged: isGenerating ? null : onDifficultyChanged,
              ),
              SizedBox(height: tokens.spaceLg),
              InkButton(
                label: hasResult
                    ? l10n.confirmRegenerate
                    : l10n.confirmGenerate,
                leadingIcon: Icons.auto_awesome,
                isLoading: isGenerating,
                loadingLabel: l10n.confirmGenerating,
                onPressed: canGenerate && !isGenerating ? onGenerate : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
