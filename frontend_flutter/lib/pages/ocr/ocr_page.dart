import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/app_provider.dart';
import '../words/word_confirm_page.dart';

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
  Future<void> _recognize() async {
    final provider = context.read<AppProvider>();
    final navigator = Navigator.of(context);

    await provider.recognizeText();
    if (!mounted) return;

    // 识别失败时留在本页，由下面的错误视图提示并让用户返回重拍。
    if (provider.error != null) return;

    navigator.pushReplacement(
      MaterialPageRoute(builder: (_) => const WordConfirmPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Recognizing Text')),
      body: Consumer<AppProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Analyzing image...'),
                ],
              ),
            );
          }

          if (provider.error != null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  Text(provider.error!, textAlign: TextAlign.center),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Go Back'),
                  ),
                ],
              ),
            );
          }

          return const Center(child: Text('Processing...'));
        },
      ),
    );
  }
}
