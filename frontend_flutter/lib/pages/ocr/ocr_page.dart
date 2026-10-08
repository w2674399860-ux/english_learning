import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../l10n/l10n.dart';
import '../../providers/app_provider.dart';
import '../words/word_confirm_page.dart';
import 'ocr_status_view.dart';

/// 识别页（设计稿 ai_2）：进入即开始识别，成功后替换为确认页；失败停在本页。
class OcrPage extends StatefulWidget {
  const OcrPage({super.key});

  @override
  State<OcrPage> createState() => _OcrPageState();
}

class _OcrPageState extends State<OcrPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _recognize());
  }

  /// 导航由识别流程结束这一个时刻触发，只会发生一次；
  /// 且用 pushReplacement 把本页移出栈，从确认页返回时直接回到 Home。
  /// 失败后点"重试"会用同一张图再次调用（Q-F7）。
  Future<void> _recognize() async {
    final provider = context.read<AppProvider>();
    final navigator = Navigator.of(context);

    await provider.recognizeText();
    if (!mounted) return;

    // 识别失败时留在本页，由错误画面提示，并让用户重试或返回重新选图。
    if (provider.error != null) return;

    navigator.pushReplacement(
      MaterialPageRoute(builder: (_) => const WordConfirmPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.ocrTitle)),
      body: Consumer<AppProvider>(
        builder: (context, provider, _) {
          final error = provider.error;
          return OcrStatusView(
            // 没有失败就一直显示"识别中"：包括识别开始前的第一帧和成功后跳转前的一瞬间，
            // 避免闪出空白或"Processing..."
            isRecognizing: error == null,
            error: error,
            errorKind: provider.errorKind,
            onRetry: _recognize,
            onRepick: () => Navigator.pop(context),
          );
        },
      ),
    );
  }
}
