import 'package:flutter/material.dart';
import '../providers/flow_phase.dart';

/// 识别 / 生成阶段的等待提示。idle 时不渲染任何内容。
/// compact 为 true 时是一行小进度圈 + 文案，用在按钮里。
class PhaseIndicator extends StatelessWidget {
  const PhaseIndicator({super.key, required this.phase, this.compact = false});

  final FlowPhase phase;
  final bool compact;

  static String? messageFor(FlowPhase phase) {
    switch (phase) {
      case FlowPhase.recognizing:
        return 'Recognizing words in your photo...';
      case FlowPhase.generating:
        return 'Writing your story and exercises...';
      case FlowPhase.idle:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final message = messageFor(phase);
    if (message == null) return const SizedBox.shrink();

    if (compact) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 12),
          Flexible(child: Text(message, overflow: TextOverflow.ellipsis)),
        ],
      );
    }

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text(message, textAlign: TextAlign.center),
        ],
      ),
    );
  }
}
