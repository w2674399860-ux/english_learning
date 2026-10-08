import 'dart:typed_data';

import 'package:english_learning_app/providers/app_provider.dart';
import 'package:english_learning_app/providers/difficulty.dart';
import 'package:english_learning_app/providers/flow_phase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';

// AppProvider 沿用"不加测试入口"（F2）：内部直接 new ApiService，不能注入假接口。
// 这里只通过不发请求的公开方法设置状态，验证重置结果。历史列表字段需要请求后端才能填充，
// 这里只能验证重置后为初始值，无法验证"有数据 → 被清空"。
void main() {
  AppProvider withState() {
    final p = AppProvider();
    p.startNewCapture(XFile.fromData(Uint8List(0), name: 'a.png'));
    p.addWord('harvest');
    p.addWord('lantern');
    p.toggleWord('lantern');
    p.setDifficulty(Difficulty.advanced);
    return p;
  }

  test('resetForSignOut 清空全部用户相关状态，难度回到默认', () {
    final p = withState();
    var notified = 0;
    p.addListener(() => notified++);

    p.resetForSignOut();

    expect(notified, 1);
    expect(p.pickedImage, isNull);
    expect(p.recognizedWords, isEmpty);
    expect(p.selectedWords, isEmpty);
    expect(p.difficulty, Difficulty.defaultValue);
    expect(p.phase, FlowPhase.idle);
    expect(p.error, isNull);
    expect(p.currentRecord, isNull);
    expect(p.isSaving, isFalse);
    expect(p.isSaved, isFalse);
    expect(p.saveError, isNull);
    expect(p.ocrDegradedReason, isNull);
    expect(p.storyDegradedReason, isNull);
    expect(p.records, isEmpty);
    expect(p.historyTotal, 0);
    expect(p.historyQuery, '');
    expect(p.isLoadingHistory, isFalse);
    expect(p.isLoadingMoreHistory, isFalse);
    expect(p.historyError, isNull);
  });

  test('startNewCapture 清掉上一轮的单词与结果，但保留难度', () {
    final p = withState();
    final next = XFile.fromData(Uint8List(0), name: 'b.png');

    p.startNewCapture(next);

    expect(p.pickedImage, same(next));
    expect(p.recognizedWords, isEmpty);
    expect(p.selectedWords, isEmpty);
    expect(p.currentRecord, isNull);
    expect(p.isSaved, isFalse);
    expect(p.difficulty, Difficulty.advanced);
  });

  test('selectAll / clearSelection 只改选中集合，单词仍留在词表中', () {
    final p = withState();
    expect(p.selectedWords, {'harvest'});

    p.selectAll();
    expect(p.selectedWords, {'harvest', 'lantern'});
    expect(p.selectedWordsInOrder, ['harvest', 'lantern']);

    p.clearSelection();
    expect(p.selectedWords, isEmpty);
    expect(p.recognizedWords, ['harvest', 'lantern']);
  });

  test('没有当前结果时保存直接返回 false（不发请求）', () async {
    final p = withState()..resetForSignOut();
    expect(await p.saveCurrentRecord(), isFalse);
  });
}
