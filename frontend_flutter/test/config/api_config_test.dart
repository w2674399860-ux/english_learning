import 'package:english_learning_app/config/api_config.dart';
import 'package:flutter_test/flutter_test.dart';

// S-3b：移动端 release 构建的后端地址必须是 https。
void main() {
  String? check(String url, {bool release = true, bool web = false}) =>
      insecureBaseUrlReason(url, isRelease: release, isWeb: web);

  test('移动端 release：http 地址被拒绝，原因中带出实际地址', () {
    final reason = check('http://192.168.1.10:8000');
    expect(reason, isNotNull);
    expect(reason, contains('http://192.168.1.10:8000'));
    expect(check('http://localhost:8000'), isNotNull);
    expect(check('not a url'), isNotNull);
  });

  test('移动端 release：https 地址允许（大小写不敏感）', () {
    expect(check('https://api.example.com'), isNull);
    expect(check('HTTPS://api.example.com'), isNull);
  });

  test('debug / profile 构建不检查（连本地后端）', () {
    expect(check('http://10.0.2.2:8000', release: false), isNull);
  });

  test('Web 不检查（由页面自身的协议决定）', () {
    expect(check('http://localhost:8000', web: true), isNull);
  });

  test('测试运行在 debug 模式：启动检查不会抛异常', () {
    expect(ApiConfig.ensureSecureBaseUrl, returnsNormally);
  });
}
