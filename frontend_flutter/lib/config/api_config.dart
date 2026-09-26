class ApiConfig {
  /// 后端地址。默认指向本地开发环境，部署时用 --dart-define 覆盖：
  ///   flutter build web --dart-define=API_BASE_URL=http://<服务器>:8000
  /// Android 模拟器用 http://10.0.2.2:8000，真机用电脑的局域网 IP。
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:8000',
  );
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
