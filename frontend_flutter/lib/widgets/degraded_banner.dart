import 'package:flutter/material.dart';

/// 降级提示条：后端服务不可用、返回了示例数据时固定显示在页面顶部。
/// 只在开发环境出现（生产环境降级关闭，失败直接报错）。
class DegradedBanner extends StatelessWidget {
  const DegradedBanner({super.key, required this.reason});

  final String reason;

  static String messageFor(String reason) {
    switch (reason) {
      case 'ocr_unavailable':
        return 'OCR service unavailable. '
            'These are sample words, not words from your photo.';
      case 'ocr_mock':
        return 'OCR is in mock mode. '
            'These are sample words, not words from your photo.';
      case 'ai_not_configured':
        return 'AI service is not configured. '
            'This is a sample story, not one written from your words.';
    }
    if (reason.startsWith('ai_')) {
      return 'AI service unavailable. '
          'This is a sample story, not one written from your words.';
    }
    return 'Some results are sample data, not generated from your input.';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Material(
      color: scheme.tertiaryContainer,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.info_outline, color: scheme.onTertiaryContainer),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    messageFor(reason),
                    style: textTheme.bodyMedium
                        ?.copyWith(color: scheme.onTertiaryContainer),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Reason: $reason',
                    style: textTheme.bodySmall
                        ?.copyWith(color: scheme.onTertiaryContainer),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
