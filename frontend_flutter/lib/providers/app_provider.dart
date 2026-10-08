import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import '../l10n/l10n.dart';
import '../models/learning_record.dart';
import '../services/api_response.dart';
import '../services/api_service.dart';
import 'difficulty.dart';
import 'flow_phase.dart';
import 'history_paging.dart';

/// 一次生成最多使用的单词数，与后端 compose_max_words 默认值一致（S-5）。
const int maxWordsPerCompose = 20;

/// 单个单词的最大长度，与后端 compose_max_word_length 默认值一致（S-5）。
/// 按码点计算，与后端 Python 的 len() 一致。
const int maxWordLength = 40;

/// 手动添加单词的校验结果。
enum AddWordResult { added, empty, noLetter, tooLong, duplicate }

/// 校验手动输入的单词。仅用于手动添加，不过滤 OCR 返回的词。
AddWordResult validateNewWord(String raw, Iterable<String> existing) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return AddWordResult.empty;
  if (!trimmed.contains(RegExp(r'[A-Za-z]'))) return AddWordResult.noLetter;
  if (trimmed.runes.length > maxWordLength) return AddWordResult.tooLong;

  final lower = trimmed.toLowerCase();
  if (existing.any((w) => w.toLowerCase() == lower)) {
    return AddWordResult.duplicate;
  }
  return AddWordResult.added;
}

class AppProvider extends ChangeNotifier {
  final ApiService _api = ApiService();

  // State
  // 识别 / 生成流程的阶段与错误。历史列表的 loading / error 单独管理，互不影响。
  FlowPhase _phase = FlowPhase.idle;
  String? _error;
  // 识别 / 生成失败的类别：决定是否显示"重试"、是否显示网络错误画面
  FlowErrorKind? _errorKind;
  bool _isLoadingHistory = false;
  String? _historyError;
  LearningRecord? _currentRecord;
  // 历史列表：已加载的记录、后端总数、当前搜索词。
  // _historyRequestSeq 在每次重新加载第 1 页时递增，晚到的旧响应直接丢弃。
  List<LearningRecord> _records = [];
  int _historyTotal = 0;
  String _historyQuery = '';
  bool _isLoadingMoreHistory = false;
  int _historyRequestSeq = 0;
  XFile? _pickedImage;
  List<String> _recognizedWords = [];
  final Set<String> _selectedWords = {};
  // 难度只在本次会话内保留，不存进历史记录。
  Difficulty _difficulty = Difficulty.defaultValue;
  bool _isSaving = false;
  bool _isSaved = false;
  String? _saveError;
  // 降级 reason（开发环境下返回了示例数据）。null 表示未降级。
  String? _ocrDegradedReason;
  String? _storyDegradedReason;
  // 流程序号：开始新照片或登出时递增。识别、生成、保存在 await 之后核对，
  // 不一致说明期间已经换了照片或换了用户，返回的结果直接丢弃（A-2 前端方案第 3 项）。
  int _flowSeq = 0;

  // Getters
  FlowPhase get phase => _phase;
  bool get isBusy => _phase != FlowPhase.idle;
  String? get error => _error;
  FlowErrorKind? get errorKind => _errorKind;
  bool get isLoadingHistory => _isLoadingHistory;
  String? get historyError => _historyError;
  LearningRecord? get currentRecord => _currentRecord;
  List<LearningRecord> get records => _records;
  int get historyTotal => _historyTotal;
  String get historyQuery => _historyQuery;
  bool get isLoadingMoreHistory => _isLoadingMoreHistory;
  bool get hasMoreRecords => _records.length < _historyTotal;
  XFile? get pickedImage => _pickedImage;
  List<String> get recognizedWords => List.unmodifiable(_recognizedWords);
  Set<String> get selectedWords => Set.unmodifiable(_selectedWords);
  Difficulty get difficulty => _difficulty;

  /// 勾选中的词，按词表原有顺序返回。
  List<String> get selectedWordsInOrder =>
      _recognizedWords.where(_selectedWords.contains).toList();

  bool get isSaving => _isSaving;
  bool get isSaved => _isSaved;
  String? get saveError => _saveError;
  String? get ocrDegradedReason => _ocrDegradedReason;
  String? get storyDegradedReason => _storyDegradedReason;

  /// 首页选了一张新照片：清掉上一轮的单词、结果、保存状态与错误，保留难度。
  /// 修复"新照片进入确认页时按钮仍显示「重新生成」"（上一轮的 currentRecord 没有清掉）。
  void startNewCapture(XFile image) {
    _flowSeq++;
    _resetFlow();
    _pickedImage = image;
    notifyListeners();
  }

  // 智能安全解析：将任意类型的后端数据安全转换为 List<String>，绝不闪退
  List<String> _extractWords(dynamic rawWords) {
    if (rawWords == null) return [];
    if (rawWords is List) {
      return List<String>.from(rawWords.map((e) => e.toString()));
    } else if (rawWords is String) {
      return rawWords
          .split(RegExp(r'[,\s]+'))
          .where((w) => w.isNotEmpty)
          .toList();
    } else if (rawWords is Map) {
      return List<String>.from(rawWords.keys.map((e) => e.toString()));
    }
    return [rawWords.toString()];
  }

  // 智能安全解析：将任意类型的后端数据安全转换为 String，彻底杜绝 _Map is not a subtype of String 报错
  String _safeString(dynamic val) {
    if (val == null) return '';
    if (val is Map) {
      if (val.containsKey('text')) return val['text'].toString();
      if (val.containsKey('story')) return val['story'].toString();
      if (val.containsKey('content')) return val['content'].toString();
      return val.toString();
    }
    return val.toString();
  }

  Future<void> recognizeText() async {
    if (_pickedImage == null) return;

    final seq = _flowSeq;
    _phase = FlowPhase.recognizing;
    _error = null;
    _errorKind = null;
    notifyListeners();

    try {
      final bytes = await _pickedImage!.readAsBytes();
      final filename = _pickedImage!.name;
      final result = await _api.recognizeText(bytes, filename);
      if (seq != _flowSeq) return;

      // 使用智能解析器提取单词列表。OCR 返回的词不做过滤，原样呈现给用户。
      _recognizedWords = _extractWords(result['words']);
      _ocrDegradedReason = degradedReasonOf(result);
      _selectedWords
        ..clear()
        ..addAll(_recognizedWords);

      _phase = FlowPhase.idle;
      notifyListeners();
    } catch (e) {
      if (seq != _flowSeq) return;
      debugPrint('recognizeText failed: $e');
      _ocrDegradedReason = null;
      // 只存原因：识别页单独显示"识别失败"标题
      _error = errorMessage(e);
      _errorKind = classifyFlowError(e);
      _phase = FlowPhase.idle;
      notifyListeners();
    }
  }

  void setDifficulty(Difficulty value) {
    if (value == _difficulty) return;
    _difficulty = value;
    notifyListeners();
  }

  void toggleWord(String word) {
    if (!_selectedWords.remove(word)) {
      _selectedWords.add(word);
    }
    notifyListeners();
  }

  /// 选中词表中的全部单词（Q-F4）。
  void selectAll() {
    _selectedWords.addAll(_recognizedWords);
    notifyListeners();
  }

  /// 取消全部选中（Q-F4）。单词仍留在词表中。
  void clearSelection() {
    _selectedWords.clear();
    notifyListeners();
  }

  void removeWord(String word) {
    _recognizedWords.remove(word);
    _selectedWords.remove(word);
    notifyListeners();
  }

  /// 手动添加一个单词，返回校验结果。成功时追加到词表末尾并默认勾选。
  AddWordResult addWord(String raw) {
    final result = validateNewWord(raw, _recognizedWords);
    if (result != AddWordResult.added) return result;

    final word = raw.trim();
    _recognizedWords.add(word);
    _selectedWords.add(word);
    notifyListeners();
    return result;
  }

  /// 用户在确认页触发生成。后端 /learn/compose 一次返回短文与填空。
  Future<void> generateFromWords(List<String> words) async {
    if (words.isEmpty) return;

    _phase = FlowPhase.generating;
    _error = null;
    _errorKind = null;
    notifyListeners();

    await _generateStory(words);
  }

  void clearError() {
    _error = null;
    _errorKind = null;
    notifyListeners();
  }

  Future<void> _generateStory(List<String> words) async {
    final seq = _flowSeq;
    // 记下本次请求用的难度：保存时随记录发送（D-1 / U-12）
    final difficulty = _difficulty;
    try {
      final result = await _api.composeLearning(
        words,
        difficulty: difficulty.apiValue,
      );
      if (seq != _flowSeq) return;

      // 使用安全提取器，即使 AI 返回了嵌套大括号也能安全提取文本
      final englishStory = _safeString(result['english']);
      final chineseTranslation = _safeString(result['chinese']);

      // 新故事产生 → 保存状态复位。放在这里而不是各调用方，
      // 是为了让后续新增的生成入口自动覆盖到。
      _isSaved = false;
      _saveError = null;
      _storyDegradedReason = degradedReasonOf(result);
      _currentRecord = LearningRecord(
        imageUrl: _pickedImage?.name,
        words: words,
        englishStory: englishStory,
        chineseTranslation: chineseTranslation,
        englishBlank: _safeString(result['english_blank']),
        chineseBlank: _safeString(result['chinese_blank']),
        difficulty: difficulty,
        isDegraded: _storyDegradedReason != null,
      );

      _phase = FlowPhase.idle;
      notifyListeners();
    } catch (e) {
      if (seq != _flowSeq) return;
      debugPrint('generateStory failed: $e');
      _error = appL10n.confirmGenerateFailed(errorMessage(e));
      _errorKind = classifyFlowError(e);
      _phase = FlowPhase.idle;
      notifyListeners();
    }
  }

  /// 保存当前记录。返回是否保存成功。
  /// 保存中或已保存时直接返回 false，避免重复点击产生多条记录。
  Future<bool> saveCurrentRecord() async {
    if (_currentRecord == null || _isSaving || _isSaved) return false;

    final seq = _flowSeq;
    _isSaving = true;
    _saveError = null;
    notifyListeners();

    try {
      await _api.saveRecord(_currentRecord!.toJson());
      if (seq != _flowSeq) return false;
      _isSaved = true;
      return true;
    } catch (e) {
      if (seq != _flowSeq) return false;
      debugPrint('saveRecord failed: $e');
      _saveError = appL10n.saveFailed(errorMessage(e));
      return false;
    } finally {
      // 期间已登出或换了照片：状态已被重置，不再改动
      if (seq == _flowSeq) {
        _isSaving = false;
        notifyListeners();
      }
    }
  }

  /// 按当前搜索词重新加载第 1 页。
  Future<void> loadRecords() async {
    final seq = ++_historyRequestSeq;
    _isLoadingHistory = true;
    _isLoadingMoreHistory = false;
    _historyError = null;
    notifyListeners();

    try {
      final result = await _api.getRecords(
        page: 1,
        pageSize: historyPageSize,
        search: _historyQuery,
      );
      if (seq != _historyRequestSeq) return;
      _records = _parseRecords(result);
      _historyTotal = _parseTotal(result);
    } catch (e) {
      if (seq != _historyRequestSeq) return;
      debugPrint('loadRecords failed: $e');
      _historyError = appL10n.historyLoadFailed(errorMessage(e));
    }

    _isLoadingHistory = false;
    notifyListeners();
  }

  /// 搜索词变化时重新加载。空字符串表示不搜索。
  Future<void> searchRecords(String query) async {
    final trimmed = query.trim();
    if (trimmed == _historyQuery) return;
    _historyQuery = trimmed;
    await loadRecords();
  }

  /// 加载下一页并追加到列表后面。
  Future<void> loadMoreRecords() async {
    if (_isLoadingHistory || _isLoadingMoreHistory || !hasMoreRecords) return;

    final seq = _historyRequestSeq;
    _isLoadingMoreHistory = true;
    _historyError = null;
    notifyListeners();

    try {
      final result = await _api.getRecords(
        page: nextHistoryPage(_records.length),
        pageSize: historyPageSize,
        search: _historyQuery,
      );
      // 期间重新搜索或刷新过：这一页属于旧列表，丢弃
      if (seq != _historyRequestSeq) return;
      _records = mergeRecordsById(_records, _parseRecords(result));
      _historyTotal = _parseTotal(result);
    } catch (e) {
      if (seq != _historyRequestSeq) return;
      debugPrint('loadMoreRecords failed: $e');
      _historyError = appL10n.historyLoadMoreFailed(errorMessage(e));
    }

    _isLoadingMoreHistory = false;
    notifyListeners();
  }

  List<LearningRecord> _parseRecords(Map<String, dynamic> result) {
    final raw = result['records'];
    if (raw is! List) return [];
    return raw
        .whereType<Map<String, dynamic>>()
        .map(LearningRecord.fromJson)
        .toList();
  }

  int _parseTotal(Map<String, dynamic> result) {
    final total = result['total'];
    return total is int ? total : _records.length;
  }

  Future<void> deleteRecord(int id) async {
    final seq = _historyRequestSeq;
    _historyError = null;
    try {
      await _api.deleteRecord(id);
      // 期间已登出：列表已清空，不再改动（避免把错误带给下一个登录的用户）
      if (seq != _historyRequestSeq) return;
      final before = _records.length;
      _records.removeWhere((r) => r.id == id);
      if (_records.length < before && _historyTotal > 0) _historyTotal--;
      notifyListeners();
      // 已加载的都删光了但后端还有：重新取第 1 页，避免误显示空列表
      if (_records.isEmpty && _historyTotal > 0) await loadRecords();
    } catch (e) {
      if (seq != _historyRequestSeq) return;
      debugPrint('deleteRecord failed: $e');
      _historyError = appL10n.historyDeleteFailed(errorMessage(e));
      notifyListeners();
    }
  }

  /// 登出或凭证失效时清空全部用户相关状态（A-2 前端方案第 3 项，共 23 个字段）。
  /// 两个序号都递增，让还在路上的识别、生成、保存、历史请求的结果被丢弃。
  void resetForSignOut() {
    _flowSeq++;
    _historyRequestSeq++;
    _resetFlow();
    _difficulty = Difficulty.defaultValue;
    _records = [];
    _historyTotal = 0;
    _historyQuery = '';
    _isLoadingHistory = false;
    _isLoadingMoreHistory = false;
    _historyError = null;
    notifyListeners();
  }

  /// 识别 / 生成流程与当前结果（不含难度、历史列表）。
  void _resetFlow() {
    _phase = FlowPhase.idle;
    _error = null;
    _errorKind = null;
    _pickedImage = null;
    _recognizedWords = [];
    _selectedWords.clear();
    _ocrDegradedReason = null;
    _storyDegradedReason = null;
    _currentRecord = null;
    _isSaving = false;
    _isSaved = false;
    _saveError = null;
  }
}
