class ApiConfig {
  static const String baseUrl = 'http://8.163.96.222:8000';
  static const String apiPrefix = '/api/v1';
  static const int connectTimeout = 30000;
  static const int receiveTimeout = 60000;

  // API endpoints
  static const String ocrRecognize = 'http://8.163.96.222:8866/ocr';
  static const String storyGenerate = '$apiPrefix/story/generate';
  static const String storyFillBlank = '$apiPrefix/story/fill-blank';
  static const String historySave = '$apiPrefix/history/save';
  static const String historyRecords = '$apiPrefix/history/records';
}
