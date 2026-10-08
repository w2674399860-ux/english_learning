import 'dart:io';
import 'dart:typed_data';

import 'package:english_learning_app/l10n/l10n.dart';
import 'package:english_learning_app/models/learning_record.dart';
import 'package:english_learning_app/providers/difficulty.dart';
import 'package:english_learning_app/services/pdf_export_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/widgets.dart' as pw;

import '../helpers/pump_app.dart';

/// 测试用小字体（Plus Jakarta Sans，176 KB），避免每次加载 10.5 MB 的思源黑体。
/// 缺少中文字形只影响渲染，不影响结构测试。
pw.Font _smallFont() {
  final bytes = File(
    'assets/fonts/plus_jakarta_sans/PlusJakartaSans-Variable.ttf',
  ).readAsBytesSync();
  return pw.Font.ttf(ByteData.sublistView(bytes));
}

void main() {
  test('填空统一加长到 10 个下划线；单个下划线不变', () {
    expect(expandBlanksForPrint('the ___ sat'), 'the ${'_' * 10} sat');
    expect(expandBlanksForPrint('穿过___ (___)'), '穿过${'_' * 10} (${'_' * 10})');
    expect(expandBlanksForPrint('snake_case'), 'snake_case');
  });

  test('目标词与中译夹注用高亮样式，其余为正文（复用页面的匹配逻辑）', () {
    final highlight = pw.TextStyle(fontSize: 99);
    final en = pdfHighlightedSpans(
      'The cat sat.',
      ['cat'],
      chinese: false,
      highlight: highlight,
    );
    expect(en.map((s) => s.text), ['The ', 'cat', ' sat.']);
    expect(en[1].style, highlight);
    expect(en[0].style, isNull);

    final zh = pdfHighlightedSpans(
      '那只猫 (cat) 坐在垫子 (mat) 上。',
      ['cat'],
      chinese: true,
      highlight: highlight,
    );
    expect(zh.firstWhere((s) => s.text == '(cat)').style, highlight);
    expect(zh.firstWhere((s) => s.text == '(mat)').style, isNull);
  });

  test('粗体、斜体都映射到中文字体（不回退到不支持中文的 Helvetica-Bold）', () {
    final font = _smallFont();
    final theme = PdfExportService.buildTheme(font);
    expect(theme.defaultTextStyle.font, same(font));
    expect(theme.defaultTextStyle.fontBold, same(font));
    expect(theme.defaultTextStyle.fontItalic, same(font));
    expect(theme.defaultTextStyle.fontBoldItalic, same(font));
  });

  // 中文日期格式需要 MaterialApp 加载本地化时初始化的数据，所以放在 Widget 树里测
  testWidgets('生成合法的 PDF（中文标题、本地时间、元信息）', (tester) async {
    await pumpLocalized(tester, const SizedBox());
    final l10n = AppLocalizations.of(tester.element(find.byType(SizedBox)));
    final service = PdfExportService(
      l10n: l10n,
      fontLoader: () async => _smallFont(),
    );
    final record = LearningRecord(
      id: 3,
      words: const ['forest', 'harvest'],
      englishStory: 'Mia walked through the forest.',
      chineseTranslation: '米娅穿过森林 (forest)。',
      englishBlank: 'Mia walked through the ___.',
      chineseBlank: '米娅穿过___ (___)。',
      difficulty: Difficulty.beginner,
      createdAt: '2026-10-05T05:28:31.384Z',
    );

    final bytes = await tester.runAsync(() => service.generatePdf(record));
    expect(bytes, isNotNull);
    expect(String.fromCharCodes(bytes!.take(4)), '%PDF');
    expect(bytes.length, greaterThan(1000));

    // 没有保存时间也能生成
    final noTime = await tester.runAsync(
      () => service.generatePdf(
        LearningRecord(
          words: const [],
          englishStory: '',
          chineseTranslation: '',
          englishBlank: '',
          chineseBlank: '',
        ),
      ),
    );
    expect(String.fromCharCodes(noTime!.take(4)), '%PDF');
  });
}
