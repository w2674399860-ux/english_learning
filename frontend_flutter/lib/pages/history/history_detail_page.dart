import 'package:flutter/material.dart';
import '../../models/learning_record.dart';
import '../../services/pdf_export_service.dart';
import '../../widgets/highlighted_text.dart';
import '../../widgets/section_card.dart';

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
            SectionCard(
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
            SectionCard(
              title: 'English Story',
              child: HighlightedText.english(
                text: record.englishStory,
                words: record.words,
              ),
            ),
            const SizedBox(height: 16),
            SectionCard(
              title: 'Chinese Translation',
              child: HighlightedText.chinese(
                text: record.chineseTranslation,
                words: record.words,
              ),
            ),
            const SizedBox(height: 16),
            SectionCard(
              title: 'English Fill-in-the-Blank',
              child: RichText(
                text: TextSpan(
                  style: DefaultTextStyle.of(context).style.copyWith(color: Colors.black87),
                  children: [TextSpan(text: record.englishBlank)],
                ),
              ),
            ),
            const SizedBox(height: 16),
            SectionCard(
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
