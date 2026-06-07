import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import '../models/learning_record.dart';
import '../services/api_service.dart';

class AppProvider extends ChangeNotifier {
  final ApiService _api = ApiService();

  // State
  bool _isLoading = false;
  String? _error;
  LearningRecord? _currentRecord;
  List<LearningRecord> _records = [];
  XFile? _pickedImage;

  // Getters
  bool get isLoading => _isLoading;
  String? get error => _error;
  LearningRecord? get currentRecord => _currentRecord;
  List<LearningRecord> get records => _records;
  XFile? get pickedImage => _pickedImage;

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
      
      // 使用智能解析器提取单词列表
      final words = _extractWords(result['words']);
      await _generateStory(words);
    } catch (e) {
      _error = 'Failed to recognize text: $e';
      _isLoading = false;
      notifyListeners();
    }
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

  Future<void> saveCurrentRecord() async {
    if (_currentRecord == null) return;

    try {
      await _api.saveRecord(_currentRecord!.toJson());
    } catch (e) {
      _error = 'Failed to save record: $e';
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
    notifyListeners();
  }
}