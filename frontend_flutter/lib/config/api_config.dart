class ApiConfig {
  static const String baseUrl = 'http://8.163.96.222:8000';
  static const String apiPrefix = '/api/v1';
  static const int connectTimeout = 30000;
  // 必须大于后端等待 DeepSeek 的超时（ai_service.py 中为 120 秒），
  // 否则前端先超时报错，而后端仍在正常生成。按单个请求计时，不是整条链路合计。
  static const int receiveTimeout = 180000;

  // API endpoints
  static const String ocrRecognize = '$baseUrl$apiPrefix/ocr/recognize';
  static const String storyGenerate = '$apiPrefix/story/generate';
  static const String storyFillBlank = '$apiPrefix/story/fill-blank';
  static const String historySave = '$apiPrefix/history/save';
  static const String historyRecords = '$apiPrefix/history/records';
}
