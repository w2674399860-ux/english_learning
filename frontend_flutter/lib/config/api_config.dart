import 'package:flutter/foundation.dart' show kIsWeb, kReleaseMode;

/// 移动端 release 构建的后端地址必须是 https（S-3b）。
///
/// Android 的 usesCleartextTraffic 与 iOS 的 ATS 只约束系统原生网络，
/// Dart 自己的 HttpClient（Dio 使用的）不受约束，所以在这里检查。
/// debug / profile 构建不检查（连本地后端）；Web 不检查：由页面自身的协议决定，
/// HTTPS 页面中浏览器会拦截明文请求。
/// 返回 null 表示允许，否则返回拒绝原因（只写进异常，供开发者排查，不显示给用户）。
String? insecureBaseUrlReason(
  String baseUrl, {
  required bool isRelease,
  required bool isWeb,
}) {
  if (!isRelease || isWeb) return null;
  final scheme = Uri.tryParse(baseUrl)?.scheme.toLowerCase();
  if (scheme == 'https') return null;
  return 'Release builds must use an https:// API_BASE_URL '
      '(use --dart-define=API_BASE_URL=https://...), got "$baseUrl".';
}

class ApiConfig {
  /// 后端地址。默认指向本地开发环境，部署时用 --dart-define 覆盖：
  ///   flutter build apk --dart-define=API_BASE_URL=https://<正式域名>
  /// Android 模拟器用 http://10.0.2.2:8000，真机用 adb reverse 后的 localhost 或电脑的局域网 IP。
  /// 移动端 release 构建只接受 https（见 [ensureSecureBaseUrl]）。
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:8000',
  );
  static const String apiPrefix = '/api/v1';
  static const int connectTimeout = 30000;
  // 必须大于后端单个请求的最长耗时，否则前端先超时报错，而后端仍在正常生成。
  // /learn/compose 在后端串行调用 DeepSeek 两次，单次超时 60 秒（ai_service.py），合计约 120 秒。
  static const int receiveTimeout = 180000;

  // API endpoints
  static const String ocrRecognize = '$baseUrl$apiPrefix/ocr/recognize';
  static const String learnCompose = '$apiPrefix/learn/compose';
  static const String historySave = '$apiPrefix/history/save';
  static const String historyRecords = '$apiPrefix/history/records';

  // 账号（A-2）
  static const String authRegister = '$apiPrefix/auth/register';
  static const String authLogin = '$apiPrefix/auth/login';
  static const String authLogout = '$apiPrefix/auth/logout';
  static const String authMe = '$apiPrefix/auth/me';
  static const String authChangePassword = '$apiPrefix/auth/change-password';

  /// 启动时调用：移动端 release 构建配置了明文后端地址时直接失败，不发出任何请求。
  static void ensureSecureBaseUrl() {
    final reason = insecureBaseUrlReason(
      baseUrl,
      isRelease: kReleaseMode,
      isWeb: kIsWeb,
    );
    if (reason != null) throw StateError(reason);
  }
}
