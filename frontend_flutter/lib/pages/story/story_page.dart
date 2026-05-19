import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/app_provider.dart';

class StoryPage extends StatelessWidget {
  const StoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Learning Result'),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: () => context.read<AppProvider>().saveCurrentRecord(),
            tooltip: 'Save Record',
          ),
        ],
      ),
      body: Consumer<AppProvider>(
        builder: (context, provider, _) {
          final record = provider.currentRecord;
          if (record == null) {
            return const Center(child: Text('No data'));
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SectionCard(
                  title: 'Recognized Words',
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: record.words
                        .map((w) => Chip(label: Text(w, style: const TextStyle(color: Colors.black87))))
                        .toList(),
                  ),
                ),
                const SizedBox(height: 16),
                _SectionCard(
                  title: 'English Story',
                  child: RichText(
                    text: TextSpan(
                      style: DefaultTextStyle.of(context).style.copyWith(color: Colors.black87),
                      children:
                          _buildEnglishSpans(record.englishStory, record.words),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                _SectionCard(
                  title: 'Chinese Translation',
                  child: RichText(
                    text: TextSpan(
                      style: DefaultTextStyle.of(context).style.copyWith(color: Colors.black87),
                      children: _buildChineseSpans(
                          record.chineseTranslation, record.words),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                _SectionCard(
                  title: 'English Fill-in-the-Blank',
                  child: RichText(
                    text: TextSpan(
                      style: DefaultTextStyle.of(context).style.copyWith(color: Colors.black87),
                      children: [TextSpan(text: record.englishBlank)],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                _SectionCard(
                  title: 'Chinese Fill-in-the-Blank',
                  child: RichText(
                    text: TextSpan(
                      style: DefaultTextStyle.of(context).style.copyWith(color: Colors.black87),
                      children: [TextSpan(text: record.chineseBlank)],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Build underlined TextSpans for English passage.
/// Matching memorized words case-insensitively with word boundaries.
List<TextSpan> _buildEnglishSpans(String text, List<String> words) {
  if (words.isEmpty || text.isEmpty) {
    return [TextSpan(text: text)];
  }

  // Sort by length descending so longer words match before substrings
  final sorted = List<String>.from(words)
    ..sort((a, b) => b.length.compareTo(a.length));

  final escaped = sorted.map((w) => RegExp.escape(w)).join('|');
  final pattern = RegExp('\\b($escaped)\\b', caseSensitive: false);

  final spans = <TextSpan>[];
  int lastEnd = 0;

  for (final m in pattern.allMatches(text)) {
    if (m.start > lastEnd) {
      spans.add(TextSpan(text: text.substring(lastEnd, m.start)));
    }
    spans.add(TextSpan(
      text: m.group(0),
      style: const TextStyle(color: Colors.black87),
    ));
    lastEnd = m.end;
  }

  if (lastEnd < text.length) {
    spans.add(TextSpan(text: text.substring(lastEnd)));
  }

  return spans;
}

/// Build underlined TextSpans for Chinese passage.
/// Matches English words in parentheses: (word) or （word）.
List<TextSpan> _buildChineseSpans(String text, List<String> words) {
  if (words.isEmpty || text.isEmpty) {
    return [TextSpan(text: text)];
  }

  final wordSet = words.map((w) => w.toLowerCase()).toSet();
  // Match both half-width (word) and full-width （word） parentheses
  final pattern = RegExp(r'（([^）]*)）|\(([^)]*)\)');

  final spans = <TextSpan>[];
  int lastEnd = 0;

  for (final m in pattern.allMatches(text)) {
    if (m.start > lastEnd) {
      spans.add(TextSpan(text: text.substring(lastEnd, m.start)));
    }

    final inner = (m.group(1) ?? m.group(2) ?? '').trim();
    spans.add(TextSpan(
      text: m.group(0),
      style: wordSet.contains(inner.toLowerCase())
          ? const TextStyle(color: Colors.black87)
          : null,
    ));
    lastEnd = m.end;
  }

  if (lastEnd < text.length) {
    spans.add(TextSpan(text: text.substring(lastEnd)));
  }

  return spans;
}

class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;

  const _SectionCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.blue,
              ),
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}
