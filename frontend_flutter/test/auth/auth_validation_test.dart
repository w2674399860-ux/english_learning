import 'package:english_learning_app/auth/auth_validation.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/pump_app.dart';

void main() {
  final l = testL10n;

  group('validateUsername（与后端 ^[A-Za-z0-9_]{3,20}\$ 一致）', () {
    test('空、2 位、21 位、非法字符不通过', () {
      expect(validateUsername(l, ''), '请输入用户名');
      expect(validateUsername(l, '   '), '请输入用户名');
      expect(validateUsername(l, 'ab'), l.validationUsernameInvalid);
      expect(validateUsername(l, 'a' * 21), l.validationUsernameInvalid);
      expect(validateUsername(l, 'mia-2026'), l.validationUsernameInvalid);
      expect(validateUsername(l, '小明abc'), l.validationUsernameInvalid);
      // 西里尔字母 а（U+0430），形似拉丁字母 a
      expect(validateUsername(l, 'аlice'), l.validationUsernameInvalid);
    });

    test('3 位、20 位、字母数字下划线通过；首尾空格去掉后再判断', () {
      expect(validateUsername(l, 'abc'), isNull);
      expect(validateUsername(l, 'a' * 20), isNull);
      expect(validateUsername(l, 'Mia_2026'), isNull);
      expect(validateUsername(l, '  mia_2026 '), isNull);
      expect(normalizeUsername('  mia_2026 '), 'mia_2026');
    });
  });

  group('validateNewPassword', () {
    test('长度边界：7 不通过，8 通过，128 通过，129 不通过', () {
      expect(validateNewPassword(l, '', username: 'mia'), '请输入密码');
      expect(validateNewPassword(l, 'a' * 7, username: 'mia'), '密码至少 8 位');
      expect(validateNewPassword(l, 'a' * 8, username: 'mia'), isNull);
      expect(validateNewPassword(l, 'a' * 128, username: 'mia'), isNull);
      expect(
        validateNewPassword(l, 'a' * 129, username: 'mia'),
        '密码不能超过 128 位',
      );
    });

    test('长度按码点计算（与后端 Python len 一致）', () {
      // 4 个 emoji：UTF-16 长度 8，码点 4
      expect(
        validateNewPassword(l, '😀😀😀😀', username: 'mia'),
        l.validationPasswordTooShort,
      );
    });

    test('不能与用户名相同（不区分大小写）', () {
      expect(
        validateNewPassword(l, 'Mia_2026', username: ' mia_2026 '),
        '密码不能与用户名相同',
      );
      expect(validateNewPassword(l, 'mia_2026x', username: 'mia_2026'), isNull);
    });

    test('密码不去空格：首尾空格也算长度', () {
      expect(validateNewPassword(l, ' abcdef ', username: 'mia'), isNull);
    });
  });

  test('两次密码一致性', () {
    expect(
      validatePasswordConfirmation(l, 'river-stone', 'river-stone'),
      isNull,
    );
    expect(
      validatePasswordConfirmation(l, 'river-stone', 'river-ston'),
      '两次输入的密码不一致',
    );
  });

  test('修改密码：当前密码必填，新旧不能相同', () {
    expect(validateCurrentPassword(l, ''), '请输入当前密码');
    expect(validateCurrentPassword(l, 'x'), isNull);
    expect(
      validateNewDiffersFromCurrent(l, 'river-stone', 'river-stone'),
      '新密码不能与当前密码相同',
    );
    expect(
      validateNewDiffersFromCurrent(l, 'river-stone', 'lake-stone'),
      isNull,
    );
  });

  test('登录只检查非空，不检查格式', () {
    expect(validateLoginFields(l, '', 'x'), '请输入用户名和密码');
    expect(validateLoginFields(l, 'mia', ''), '请输入用户名和密码');
    expect(validateLoginFields(l, 'a', 'x'), isNull);
  });
}
