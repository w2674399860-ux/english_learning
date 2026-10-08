import 'package:flutter_test/flutter_test.dart';

import 'package:english_learning_app/providers/app_provider.dart';

void main() {
  group('validateNewWord', () {
    test('正常单词可以添加', () {
      expect(validateNewWord('window', ['apple']), AddWordResult.added);
    });

    test('空串被拒绝', () {
      expect(validateNewWord('', ['apple']), AddWordResult.empty);
    });

    test('纯空白被拒绝', () {
      expect(validateNewWord('   ', ['apple']), AddWordResult.empty);
    });

    test('不含字母的输入被拒绝', () {
      expect(validateNewWord('123', ['apple']), AddWordResult.noLetter);
      expect(validateNewWord('---', ['apple']), AddWordResult.noLetter);
    });

    test('重复项被拒绝，且忽略大小写', () {
      expect(validateNewWord('apple', ['apple']), AddWordResult.duplicate);
      expect(validateNewWord('APPLE', ['apple']), AddWordResult.duplicate);
      expect(validateNewWord('  Apple  ', ['apple']), AddWordResult.duplicate);
    });

    test('超过 40 个字符被拒绝；40 个字符可以添加；按码点计算', () {
      expect(validateNewWord('a' * 40, ['apple']), AddWordResult.added);
      expect(validateNewWord('a' * 41, ['apple']), AddWordResult.tooLong);
      // 首尾空格不计入长度
      expect(
        validateNewWord('  ${'a' * 40}  ', ['apple']),
        AddWordResult.added,
      );
      // 39 个字母 + 1 个 emoji：UTF-16 长度 41，码点 40
      expect(validateNewWord('${'a' * 39}😀', ['apple']), AddWordResult.added);
    });

    test('含连字符或撇号的词可以添加', () {
      expect(validateNewWord('self-aware', ['apple']), AddWordResult.added);
      expect(validateNewWord("don't", ['apple']), AddWordResult.added);
      expect(validateNewWord('COVID-19', ['apple']), AddWordResult.added);
    });
  });
}
