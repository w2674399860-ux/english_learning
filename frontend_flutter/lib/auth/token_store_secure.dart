import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'token_store.dart';

TokenStore createTokenStore() => SecureTokenStore();

/// 手机端：iOS Keychain、Android Keystore 加密存储。
/// Android 已在 AndroidManifest 中关闭自动备份（插件要求，否则从备份恢复后解密失败）。
class SecureTokenStore implements TokenStore {
  SecureTokenStore()
    : _storage = const FlutterSecureStorage(
        // 凭证只留在本机，不随 iCloud / 备份迁移到其他设备
        iOptions: IOSOptions(
          accessibility: KeychainAccessibility.first_unlock_this_device,
        ),
      );

  final FlutterSecureStorage _storage;

  @override
  Future<StoredCredential?> read() async {
    final token = await _storage.read(key: tokenStorageKey);
    final expiresAt = await _storage.read(key: expiresAtStorageKey);
    return parseStoredCredential(token, expiresAt);
  }

  @override
  Future<void> write(StoredCredential credential) async {
    await _storage.write(key: tokenStorageKey, value: credential.token);
    await _storage.write(
      key: expiresAtStorageKey,
      value: credential.expiresAt.toUtc().toIso8601String(),
    );
  }

  @override
  Future<void> clear() async {
    await _storage.delete(key: tokenStorageKey);
    await _storage.delete(key: expiresAtStorageKey);
  }
}
