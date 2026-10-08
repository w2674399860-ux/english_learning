import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import '../../providers/flow_phase.dart';
import '../../services/api_response.dart';
import '../../theme/theme_x.dart';
import '../../widgets/illustration.dart';
import '../../widgets/phase_indicator.dart';
import '../../widgets/state_view.dart';
import '../../widgets/tip_card.dart';

/// 识别页的三个画面（设计稿 ai_2）。只接收状态参数，不读 Provider，便于测试。
///
/// - 识别中：吉祥物 + 文案 + 不确定进度条（不显示百分比）。
/// - 识别失败：沮丧的铅笔 +"识别失败"+ 原因 + 拍照提示卡；
///   可重试（超时、5xx）时显示"重试"与"重新选图"，否则（429、不是图片、图片太大）只有"重新选图"。
/// - 无法连接服务器：插画加 wifi_off 角标，"重试"与"重新选图"。
class OcrStatusView extends StatelessWidget {
  const OcrStatusView({
    super.key,
    required this.isRecognizing,
    required this.error,
    required this.errorKind,
    required this.onRetry,
    required this.onRepick,
  });

  final bool isRecognizing;

  /// 失败原因（后端 detail 或前端网络文案）；null 表示没有失败。
  final String? error;
  final FlowErrorKind? errorKind;
  final VoidCallback onRetry;
  final VoidCallback onRepick;

  @override
  Widget build(BuildContext context) {
    if (isRecognizing) {
      return const PhaseIndicator(phase: FlowPhase.recognizing);
    }
    final reason = error;
    // 识别成功、跳到确认页之前的一瞬间：什么都不显示（不再闪出"Processing..."）
    if (reason == null) return const SizedBox.shrink();

    final l10n = context.l10n;
    final retry = StateAction(
      label: l10n.ocrRetry,
      icon: Icons.refresh,
      onPressed: onRetry,
    );
    final repick = StateAction(
      label: l10n.ocrRepick,
      icon: Icons.photo_camera,
      onPressed: onRepick,
    );

    if (errorKind == FlowErrorKind.network) {
      return StateView(
        illustration: IllustrationKind.sad,
        illustrationBadge: const _OfflineBadge(),
        title: l10n.ocrNetworkTitle,
        message: l10n.ocrNetworkBody,
        primaryAction: retry,
        secondaryAction: repick,
      );
    }

    final retryable = errorKind != FlowErrorKind.notRetryable;
    return StateView(
      illustration: IllustrationKind.sad,
      title: l10n.ocrFailedTitle,
      message: reason,
      extra: TipCard(body: l10n.ocrFailedTip, icon: Icons.camera_enhance),
      primaryAction: retryable ? retry : repick,
      secondaryAction: retryable ? repick : null,
    );
  }
}

/// 网络错误画面插画右上角的 wifi_off 角标。
class _OfflineBadge extends StatelessWidget {
  const _OfflineBadge();

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final c = context.colors;
    return Container(
      width: tokens.iconTileLg,
      height: tokens.iconTileLg,
      decoration: BoxDecoration(
        color: c.errorContainer,
        shape: BoxShape.circle,
        boxShadow: tokens.hardShadow(tokens.shadowSmall),
      ),
      child: Icon(
        Icons.wifi_off,
        color: c.onErrorContainer,
        size: tokens.iconMd,
      ),
    );
  }
}
