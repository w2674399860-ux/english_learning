/// 内存中的当前凭证。拦截器只从这里读取，不直接访问持久化存储。
class AuthSession {
  String? _token;
  DateTime? _expiresAt;

  String? get token => _token;
  DateTime? get expiresAt => _expiresAt;
  bool get hasToken => _token != null;

  void set(String token, DateTime expiresAt) {
    _token = token;
    _expiresAt = expiresAt;
  }

  void clear() {
    _token = null;
    _expiresAt = null;
  }
}
