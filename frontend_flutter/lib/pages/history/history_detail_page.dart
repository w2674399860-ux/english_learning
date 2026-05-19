import 'package:flutter/material.dart';
import '../../models/learning_record.dart';
import '../../services/pdf_export_service.dart';

class HistoryDetailPage extends StatelessWidget {
  final LearningRecord record;

  const HistoryDetailPage({super.key, required this.record});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Learning Record'),
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            onPressed: () => _exportPdf(context),
            tooltip: 'Export PDF',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (record.createdAt != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  record.createdAt!,
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ),
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
      ),
    );
  }

  Future<void> _exportPdf(BuildContext context) async {
    final service = PdfExportService();
    try {
      await service.sharePdf(record);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to export PDF: $e')),
        );
      }
    }
  }
}

/// Build underlined TextSpans for English passage.
List<TextSpan> _buildEnglishSpans(String text, List<String> words) {
  if (words.isEmpty || text.isEmpty) {
    return [TextSpan(text: text)];
  }

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
List<TextSpan> _buildChineseSpans(String text, List<String> words) {
  if (words.isEmpty || text.isEmpty) {
    return [TextSpan(text: text)];
  }

  final wordSet = words.map((w) => w.toLowerCase()).toSet();
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
