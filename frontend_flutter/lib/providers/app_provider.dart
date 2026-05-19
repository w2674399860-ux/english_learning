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

  Future<void> recognizeText() async {
    if (_pickedImage == null) return;

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final bytes = await _pickedImage!.readAsBytes();
      final filename = _pickedImage!.name;
      final result = await _api.recognizeText(bytes, filename);
      final words = List<String>.from(result['words'] ?? []);
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
      final fillBlankResult = await _api.generateFillBlank(
        storyResult['english'],
        storyResult['chinese'],
        words: words,
      );

      _currentRecord = LearningRecord(
        imageUrl: _pickedImage?.name,
        words: words,
        englishStory: storyResult['english'],
        chineseTranslation: storyResult['chinese'],
        englishBlank: fillBlankResult['english_blank'],
        chineseBlank: fillBlankResult['chinese_blank'],
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
