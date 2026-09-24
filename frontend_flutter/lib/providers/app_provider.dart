import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import '../models/learning_record.dart';
import '../services/api_service.dart';

/// 手动添加单词的校验结果。
enum AddWordResult { added, empty, noLetter, duplicate }

/// 校验手动输入的单词。仅用于手动添加，不过滤 OCR 返回的词。
AddWordResult validateNewWord(String raw, Iterable<String> existing) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return AddWordResult.empty;
  if (!trimmed.contains(RegExp(r'[A-Za-z]'))) return AddWordResult.noLetter;

  final lower = trimmed.toLowerCase();
  if (existing.any((w) => w.toLowerCase() == lower)) {
    return AddWordResult.duplicate;
  }
  return AddWordResult.added;
}

class AppProvider extends ChangeNotifier {
  final ApiService _api = ApiService();

  // State
  bool _isLoading = false;
  String? _error;
  LearningRecord? _currentRecord;
  List<LearningRecord> _records = [];
  XFile? _pickedImage;
  List<String> _recognizedWords = [];
  final Set<String> _selectedWords = {};
  bool _isSaving = false;
  bool _isSaved = false;
  String? _saveError;

  // Getters
  bool get isLoading => _isLoading;
  String? get error => _error;
  LearningRecord? get currentRecord => _currentRecord;
  List<LearningRecord> get records => _records;
  XFile? get pickedImage => _pickedImage;
  List<String> get recognizedWords => List.unmodifiable(_recognizedWords);
  Set<String> get selectedWords => Set.unmodifiable(_selectedWords);

  /// 勾选中的词，按词表原有顺序返回。
  List<String> get selectedWordsInOrder =>
      _recognizedWords.where(_selectedWords.contains).toList();

  bool get isSaving => _isSaving;
  bool get isSaved => _isSaved;
  String? get saveError => _saveError;

  void setPickedImage(XFile? image) {
    _pickedImage = image;
    notifyListeners();
  }

  // 智能安全解析：将任意类型的后端数据安全转换为 List<String>，绝不闪退
  List<String> _extractWords(dynamic rawWords) {
    if (rawWords == null) return [];
    if (rawWords is List) {
      return List<String>.from(rawWords.map((e) => e.toString()));
    } else if (rawWords is String) {
      return rawWords.split(RegExp(r'[,\s]+')).where((w) => w.isNotEmpty).toList();
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

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final bytes = await _pickedImage!.readAsBytes();
      final filename = _pickedImage!.name;
      final result = await _api.recognizeText(bytes, filename);
      
      // 使用智能解析器提取单词列表。OCR 返回的词不做过滤，原样呈现给用户。
      _recognizedWords = _extractWords(result['words']);
      _selectedWords
        ..clear()
        ..addAll(_recognizedWords);

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = 'Failed to recognize text: $e';
      _isLoading = false;
      notifyListeners();
    }
  }

  void toggleWord(String word) {
    if (!_selectedWords.remove(word)) {
      _selectedWords.add(word);
    }
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

  /// 用户在确认页触发生成。内部仍串行 generateStory → generateFillBlank。
  Future<void> generateFromWords(List<String> words) async {
    if (words.isEmpty) return;

    _isLoading = true;
    _error = null;
    notifyListeners();

    await _generateStory(words);
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  Future<void> _generateStory(List<String> words) async {
    try {
      final storyResult = await _api.generateStory(words);
      
      // 使用安全提取器，即使 AI 返回了嵌套大括号也能安全提取文本
      final englishStory = _safeString(storyResult['english']);
      final chineseTranslation = _safeString(storyResult['chinese']);

      final fillBlankResult = await _api.generateFillBlank(
        englishStory,
        chineseTranslation,
        words: words,
      );

      // 新故事产生 → 保存状态复位。放在这里而不是各调用方，
      // 是为了让后续新增的生成入口自动覆盖到。
      _isSaved = false;
      _saveError = null;
      _currentRecord = LearningRecord(
        imageUrl: _pickedImage?.name,
        words: words,
        englishStory: englishStory,
        chineseTranslation: chineseTranslation,
        englishBlank: _safeString(fillBlankResult['english_blank']),
        chineseBlank: _safeString(fillBlankResult['chinese_blank']),
      );

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = 'Failed to generate story: $e';
      _isLoading = false;
      notifyListeners();
    }
  }

  /// 保存当前记录。返回是否保存成功。
  /// 保存中或已保存时直接返回 false，避免重复点击产生多条记录。
  Future<bool> saveCurrentRecord() async {
    if (_currentRecord == null || _isSaving || _isSaved) return false;

    _isSaving = true;
    _saveError = null;
    notifyListeners();

    try {
      await _api.saveRecord(_currentRecord!.toJson());
      _isSaved = true;
      return true;
    } catch (e) {
      _saveError = 'Failed to save record: $e';
      return false;
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  Future<void> loadRecords() async {
    _isLoading = true;
    notifyListeners();

    try {
      final result = await _api.getRecords();
      _records = (result['records'] as List)
          .map((json) => LearningRecord.fromJson(json))
          .toList();
    } catch (e) {
      _error = 'Failed to load records: $e';
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> deleteRecord(int id) async {
    try {
      await _api.deleteRecord(id);
      _records.removeWhere((r) => r.id == id);
      notifyListeners();
    } catch (e) {
      _error = 'Failed to delete record: $e';
      notifyListeners();
    }
  }

  void clearCurrentRecord() {
    _currentRecord = null;
    _pickedImage = null;
    _error = null;
    _recognizedWords = [];
    _selectedWords.clear();
    _isSaving = false;
    _isSaved = false;
    _saveError = null;
    notifyListeners();
  }
}