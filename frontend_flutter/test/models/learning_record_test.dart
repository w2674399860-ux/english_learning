import 'package:english_learning_app/models/learning_record.dart';
import 'package:english_learning_app/providers/difficulty.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _json(Map<String, dynamic> extra) => {
  'id': 12,
  'image_url': 'a.png',
  'words': ['cat'],
  'english_story': 'The cat.',
  'chinese_translation': '猫 (cat)。',
  'english_blank': 'The ___.',
  'chinese_blank': '___ (___)。',
  'created_at': '2026-10-07T03:47:00.123Z',
  ...extra,
};

void main() {
  test('保存时发送 difficulty（后端取值）与 is_degraded（D-1 / U-12）', () {
    final record = LearningRecord(
      words: ['cat'],
      englishStory: 'e',
      chineseTranslation: 'c',
      englishBlank: 'eb',
      chineseBlank: 'cb',
      difficulty: Difficulty.advanced,
      isDegraded: true,
    );
    final json = record.toJson();
    expect(json['difficulty'], 'advanced');
    expect(json['is_degraded'], isTrue);
  });

  test('默认难度为中级、未降级', () {
    final json = LearningRecord(
      words: const [],
      englishStory: '',
      chineseTranslation: '',
      englishBlank: '',
      chineseBlank: '',
    ).toJson();
    expect(json['difficulty'], 'intermediate');
    expect(json['is_degraded'], isFalse);
  });

  test('读取 difficulty、is_degraded；未知或缺失的难度按默认值', () {
    final r = LearningRecord.fromJson(
      _json({'difficulty': 'beginner', 'is_degraded': true}),
    );
    expect(r.difficulty, Difficulty.beginner);
    expect(r.isDegraded, isTrue);

    expect(
      LearningRecord.fromJson(_json({})).difficulty,
      Difficulty.intermediate,
    );
    expect(
      LearningRecord.fromJson(_json({'difficulty': 'expert'})).difficulty,
      Difficulty.intermediate,
    );
    expect(LearningRecord.fromJson(_json({})).isDegraded, isFalse);
  });

  test('is_favorite 兼容 0 / 1 与布尔值（Q-F13）', () {
    expect(
      LearningRecord.fromJson(_json({'is_favorite': 1})).isFavorite,
      isTrue,
    );
    expect(
      LearningRecord.fromJson(_json({'is_favorite': 0})).isFavorite,
      isFalse,
    );
    expect(
      LearningRecord.fromJson(_json({'is_favorite': true})).isFavorite,
      isTrue,
    );
    expect(
      LearningRecord.fromJson(_json({'is_favorite': false})).isFavorite,
      isFalse,
    );
    expect(LearningRecord.fromJson(_json({})).isFavorite, isFalse);
  });
}
