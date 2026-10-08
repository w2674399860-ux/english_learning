import 'package:english_learning_app/auth/token_store.dart';
import 'package:flutter_test/flutter_test.dart';

// 安全存储（flutter_secure_storage）与 sessionStorage 只是对平台接口的薄封装，
// 不在单元测试中运行；这里测内存实现与两者共用的解析逻辑。
void main() {
  test('内存实现：读、写、清除', () async {
    final store = InMemoryTokenStore();
    expect(await store.read(), isNull);
    final credential = StoredCredential(
      token: 't',
      expiresAt: DateTime.utc(2026, 11, 6),
    );
    await store.write(credential);
    expect((await store.read())!.token, 't');
    await store.clear();
    expect(await store.read(), isNull);
  });

  test('parseStoredCredential：任一缺失或时间格式不对都视为没有凭证', () {
    expect(parseStoredCredential(null, '2026-11-06T03:47:00.123Z'), isNull);
    expect(parseStoredCredential('', '2026-11-06T03:47:00.123Z'), isNull);
    expect(parseStoredCredential('t', null), isNull);
    expect(parseStoredCredential('t', 'not-a-date'), isNull);

    final parsed = parseStoredCredential('t', '2026-11-06T03:47:00.123Z')!;
    expect(parsed.token, 't');
    expect(parsed.expiresAt, DateTime.utc(2026, 11, 6, 3, 47, 0, 123));
  });
}
