import '../providers/difficulty.dart';

class LearningRecord {
  final int? id;
  final String? imageUrl;
  final List<String> words;
  final String englishStory;
  final String chineseTranslation;
  final String englishBlank;
  final String chineseBlank;

  /// 生成时使用的难度（D-1 新增列；U-12 起保存时发送）。
  final Difficulty difficulty;

  /// 是否为降级返回的示例内容（D-1 新增列；U-12 起保存时发送）。
  final bool isDegraded;
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
    this.difficulty = Difficulty.defaultValue,
    this.isDegraded = false,
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
      difficulty: _parseDifficulty(json['difficulty']),
      isDegraded: json['is_degraded'] == true,
      // 后端兼容层目前输出 0 / 1；以后改为布尔值时这里也能读（Q-F13）
      isFavorite: _parseFlag(json['is_favorite']),
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
    'difficulty': difficulty.apiValue,
    'is_degraded': isDegraded,
  };

  /// 保存时间（本地时区）。后端返回 UTC 的 ISO 字符串；缺失或格式不对时为 null。
  DateTime? get createdAtLocal {
    final raw = createdAt;
    if (raw == null) return null;
    return DateTime.tryParse(raw)?.toLocal();
  }

  static Difficulty _parseDifficulty(Object? raw) {
    for (final d in Difficulty.values) {
      if (d.apiValue == raw) return d;
    }
    return Difficulty.defaultValue;
  }

  static bool _parseFlag(Object? raw) => raw == true || raw == 1;
}
