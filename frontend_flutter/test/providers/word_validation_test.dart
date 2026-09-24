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

    test('含连字符或撇号的词可以添加', () {
      expect(validateNewWord('self-aware', ['apple']), AddWordResult.added);
      expect(validateNewWord("don't", ['apple']), AddWordResult.added);
      expect(validateNewWord('COVID-19', ['apple']), AddWordResult.added);
    });
  });
}
