import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../providers/flow_phase.dart';
import '../theme/theme_x.dart';
import 'illustration.dart';
import 'state_view.dart';

/// 识别 / 生成阶段的等待提示。idle 时不渲染任何内容。
/// - 默认：吉祥物 + 标题 + 说明 + 不确定进度条（设计稿 ai_2 画面一，去掉了虚假的百分比）。
/// - compact：一行小进度圈 + 文案，用在按钮里。
class PhaseIndicator extends StatelessWidget {
  const PhaseIndicator({super.key, required this.phase, this.compact = false});

  final FlowPhase phase;
  final bool compact;

  static String? messageFor(AppLocalizations l10n, FlowPhase phase) {
    switch (phase) {
      case FlowPhase.recognizing:
        return l10n.ocrRecognizing;
      case FlowPhase.generating:
        return l10n.confirmGenerating;
      case FlowPhase.idle:
        return null;
    }
  }

  static String? hintFor(AppLocalizations l10n, FlowPhase phase) =>
      phase == FlowPhase.recognizing ? l10n.ocrRecognizingHint : null;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final message = messageFor(l10n, phase);
    if (message == null) return const SizedBox.shrink();

    if (compact) {
      final tokens = context.tokens;
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox.square(
            dimension: tokens.progressSize,
            child: CircularProgressIndicator(
              strokeWidth: tokens.progressStroke,
            ),
          ),
          SizedBox(width: tokens.spaceMd),
          Flexible(child: Text(message, overflow: TextOverflow.ellipsis)),
        ],
      );
    }

    return StateView(
      illustration: IllustrationKind.mascot,
      title: message,
      message: hintFor(l10n, phase),
      isLoading: true,
    );
  }
}
