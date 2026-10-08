import 'token_store_secure.dart'
    if (dart.library.js_interop) 'token_store_web.dart'
    as platform;

/// 持久化的凭证：只存凭证与过期时间，不存用户名和密码。
class StoredCredential {
  const StoredCredential({required this.token, required this.expiresAt});

  final String token;
  final DateTime expiresAt;
}

/// 凭证存储。手机端为 Keychain / Android Keystore（flutter_secure_storage），
/// Web 端为 sessionStorage（关闭标签页即失效，A-2 前端方案 F1）。
abstract class TokenStore {
  Future<StoredCredential?> read();
  Future<void> write(StoredCredential credential);
  Future<void> clear();
}

/// 存储中的键名（两种平台实现共用）。
const String tokenStorageKey = 'auth.token';
const String expiresAtStorageKey = 'auth.expires_at';

/// 当前平台的凭证存储。
TokenStore createPlatformTokenStore() => platform.createTokenStore();

/// 把两个存储值还原为凭证；任一缺失或时间格式不对都视为没有凭证。
StoredCredential? parseStoredCredential(String? token, String? expiresAt) {
  if (token == null || token.isEmpty || expiresAt == null) return null;
  final parsed = DateTime.tryParse(expiresAt);
  if (parsed == null) return null;
  return StoredCredential(token: token, expiresAt: parsed);
}

/// 测试用、或平台存储不可用时的内存实现。
class InMemoryTokenStore implements TokenStore {
  InMemoryTokenStore([this._credential]);

  StoredCredential? _credential;

  @override
  Future<StoredCredential?> read() async => _credential;

  @override
  Future<void> write(StoredCredential credential) async =>
      _credential = credential;

  @override
  Future<void> clear() async => _credential = null;
}
