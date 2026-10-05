import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/app_provider.dart';
import '../../widgets/degraded_banner.dart';
import '../../widgets/difficulty_selector.dart';
import '../../widgets/phase_indicator.dart';
import '../story/story_page.dart';

/// 识别完成后的单词确认页：勾选、删除、手动添加，确认后再生成短文。
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

    final message = switch (result) {
      AddWordResult.empty => 'Enter a word first',
      AddWordResult.noLetter => 'A word must contain at least one letter',
      AddWordResult.duplicate => 'That word is already in the list',
      AddWordResult.added => '',
    };
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
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
    return Scaffold(
      appBar: AppBar(title: const Text('Confirm Words')),
      body: Consumer<AppProvider>(
        builder: (context, provider, _) {
          final words = provider.recognizedWords;
          final selected = provider.selectedWords;

          return Column(
            children: [
              if (provider.ocrDegradedReason != null)
                DegradedBanner(reason: provider.ocrDegradedReason!),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Tap a word to include or exclude it. '
                        'Only the selected words are used to write the story.',
                        style: TextStyle(color: Colors.grey[700]),
                      ),
                      const SizedBox(height: 16),
                      if (words.isEmpty)
                        const Text('No words were recognized.')
                      else
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          children: words
                              .map((w) => FilterChip(
                                    label: Text(w),
                                    selected: selected.contains(w),
                                    onSelected: (_) => provider.toggleWord(w),
                                    onDeleted: () => provider.removeWord(w),
                                  ))
                              .toList(),
                        ),
                      if (provider.error != null) ...[
                        const SizedBox(height: 16),
                        _ErrorBanner(
                          message: provider.error!,
                          onRetry: () {
                            provider.clearError();
                            _generate();
                          },
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _controller,
                            decoration: const InputDecoration(
                              labelText: 'Add a word',
                              isDense: true,
                              border: OutlineInputBorder(),
                            ),
                            onSubmitted: (_) => _addWord(),
                          ),
                        ),
                        const SizedBox(width: 8),
                        FilledButton.tonal(
                          onPressed: _addWord,
                          child: const Text('Add'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    DifficultySelector(
                      value: provider.difficulty,
                      onChanged:
                          provider.isBusy ? null : provider.setDifficulty,
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: provider.isBusy || selected.isEmpty
                            ? null
                            : _generate,
                        child: provider.isBusy
                            ? PhaseIndicator(
                                phase: provider.phase,
                                compact: true,
                              )
                            : Text(
                                provider.currentRecord == null
                                    ? 'Generate'
                                    : 'Regenerate',
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Theme.of(context).colorScheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Expanded(
              child: Text(
                message,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onErrorContainer,
                ),
              ),
            ),
            TextButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}
