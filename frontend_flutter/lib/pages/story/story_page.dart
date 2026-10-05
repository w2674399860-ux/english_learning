import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/learning_record.dart';
import '../../providers/app_provider.dart';
import '../../widgets/degraded_banner.dart';
import '../../widgets/highlighted_text.dart';
import '../../widgets/save_button.dart';
import '../../widgets/section_card.dart';

class StoryPage extends StatelessWidget {
  const StoryPage({super.key});

  Future<void> _save(BuildContext context) async {
    // 先取出 messenger，避免 await 之后再用 context
    final messenger = ScaffoldMessenger.of(context);
    final provider = context.read<AppProvider>();

    final saved = await provider.saveCurrentRecord();

    messenger.showSnackBar(
      SnackBar(
        content: Text(
          saved
              ? 'Record saved'
              : (provider.saveError ?? 'Failed to save record'),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Learning Result'),
        actions: [
          Consumer<AppProvider>(
            builder: (context, provider, _) => SaveButton(
              isSaving: provider.isSaving,
              isSaved: provider.isSaved,
              onPressed: () => _save(context),
            ),
          ),
        ],
      ),
      body: Consumer<AppProvider>(
        builder: (context, provider, _) {
          final record = provider.currentRecord;
          if (record == null) {
            return const Center(child: Text('No data'));
          }

          final degradedReason = provider.storyDegradedReason;

          return Column(
            children: [
              if (degradedReason != null) DegradedBanner(reason: degradedReason),
              Expanded(
                child: _buildContent(context, record),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildContent(BuildContext context, LearningRecord record) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
    );
  }
}
