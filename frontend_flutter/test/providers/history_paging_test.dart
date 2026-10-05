import 'package:flutter_test/flutter_test.dart';

import 'package:english_learning_app/models/learning_record.dart';
import 'package:english_learning_app/providers/history_paging.dart';

LearningRecord _r(int id) => LearningRecord(
      id: id,
      words: const ['w'],
      englishStory: 's$id',
      chineseTranslation: '',
      englishBlank: '',
      chineseBlank: '',
    );

void main() {
  group('nextHistoryPage', () {
    test('整页加载后请求下一页', () {
      expect(nextHistoryPage(0, pageSize: 20), 1);
      expect(nextHistoryPage(20, pageSize: 20), 2);
      expect(nextHistoryPage(40, pageSize: 20), 3);
    });

    test('删除 k 条后重新请求当前页，补齐前移进来的记录', () {
      // 已加载 2 页共 40 条，删掉 3 条剩 37 条：后端第 2 页整体前移，重新取第 2 页
      expect(nextHistoryPage(37, pageSize: 20), 2);
    });
  });

  group('mergeRecordsById', () {
    test('追加新记录并保持顺序', () {
      final merged = mergeRecordsById([_r(5), _r(4)], [_r(3), _r(2)]);
      expect(merged.map((r) => r.id), [5, 4, 3, 2]);
    });

    test('丢弃已存在的 id（重新请求当前页时的重叠部分）', () {
      final merged = mergeRecordsById([_r(5), _r(4), _r(3)], [_r(4), _r(3), _r(2), _r(1)]);
      expect(merged.map((r) => r.id), [5, 4, 3, 2, 1]);
    });
  });
}
