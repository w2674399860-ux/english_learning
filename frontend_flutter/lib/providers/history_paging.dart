import '../models/learning_record.dart';

const int historyPageSize = 20;

/// 根据已加载条数计算下一次要请求的页码。
/// 后端按 OFFSET 分页：删除记录后，后面的记录整体前移，这时重新请求当前页，
/// 配合 [mergeRecordsById] 去重，既不漏也不重。
int nextHistoryPage(int loadedCount, {int pageSize = historyPageSize}) =>
    loadedCount ~/ pageSize + 1;

/// 把新取到的一页追加到已有列表后面，丢弃已存在的 id。
List<LearningRecord> mergeRecordsById(
  List<LearningRecord> existing,
  List<LearningRecord> incoming,
) {
  final ids = existing.map((r) => r.id).toSet();
  return [
    ...existing,
    ...incoming.where((r) => r.id == null || !ids.contains(r.id)),
  ];
}
