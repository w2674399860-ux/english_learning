class LearningRecord {
  final int? id;
  final String? imageUrl;
  final List<String> words;
  final String englishStory;
  final String chineseTranslation;
  final String englishBlank;
  final String chineseBlank;
  final bool isFavorite;
  final String? notes;
  final String? createdAt;

  LearningRecord({
    this.id,
    this.imageUrl,
    required this.words,
    required this.englishStory,
    required this.chineseTranslation,
    required this.englishBlank,
    required this.chineseBlank,
    this.isFavorite = false,
    this.notes,
    this.createdAt,
  });

  factory LearningRecord.fromJson(Map<String, dynamic> json) {
    return LearningRecord(
      id: json['id'] as int?,
      imageUrl: json['image_url'] as String?,
      words: List<String>.from(json['words'] ?? []),
      englishStory: json['english_story'] as String? ?? '',
      chineseTranslation: json['chinese_translation'] as String? ?? '',
      englishBlank: json['english_blank'] as String? ?? '',
      chineseBlank: json['chinese_blank'] as String? ?? '',
      isFavorite: (json['is_favorite'] as int? ?? 0) == 1,
      notes: json['notes'] as String?,
      createdAt: json['created_at'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'image_url': imageUrl,
        'words': words,
        'english_story': englishStory,
        'chinese_translation': chineseTranslation,
        'english_blank': englishBlank,
        'chinese_blank': chineseBlank,
      };
}
