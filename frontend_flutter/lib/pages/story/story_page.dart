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
                        .map((w) => Chip(label: Text(w)))
                        .toList(),
                  ),
                ),
                const SizedBox(height: 16),
                _SectionCard(
                  title: 'English Story',
                  child: Text(record.englishStory),
                ),
                const SizedBox(height: 16),
                _SectionCard(
                  title: 'Chinese Translation',
                  child: Text(record.chineseTranslation),
                ),
                const SizedBox(height: 16),
                _SectionCard(
                  title: 'English Fill-in-the-Blank',
                  child: Text(record.englishBlank),
                ),
                const SizedBox(height: 16),
                _SectionCard(
                  title: 'Chinese Fill-in-the-Blank',
                  child: Text(record.chineseBlank),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
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
