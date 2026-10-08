import 'dart:js_interop';

import 'token_store.dart';

TokenStore createTokenStore() => SessionStorageTokenStore();

@JS('sessionStorage')
external _Storage get _sessionStorage;

extension type _Storage._(JSObject _) implements JSObject {
  external String? getItem(String key);
  external void setItem(String key, String value);
  external void removeItem(String key);
}

/// Web 端：sessionStorage。刷新页面保持登录，关闭标签页即失效；
/// 公用电脑上下一个人打开不会是已登录状态（A-2 前端方案 F1）。
/// 与 localStorage 一样能被页面内的恶意脚本读取，差别只在保留时长。
class SessionStorageTokenStore implements TokenStore {
  @override
  Future<StoredCredential?> read() async => parseStoredCredential(
    _sessionStorage.getItem(tokenStorageKey),
    _sessionStorage.getItem(expiresAtStorageKey),
  );

  @override
  Future<void> write(StoredCredential credential) async {
    _sessionStorage.setItem(tokenStorageKey, credential.token);
    _sessionStorage.setItem(
      expiresAtStorageKey,
      credential.expiresAt.toUtc().toIso8601String(),
    );
  }

  @override
  Future<void> clear() async {
    _sessionStorage.removeItem(tokenStorageKey);
    _sessionStorage.removeItem(expiresAtStorageKey);
  }
}
