import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/painting.dart' show TextStyle;
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:path_provider/path_provider.dart';
import '../l10n/l10n.dart';
import '../models/learning_record.dart';
import '../theme/app_theme.dart';
import '../theme/storybook_tokens.dart';
import '../widgets/highlighted_text.dart';

/// PDF 用的中文字体（思源黑体常规体，SIL OFL 1.1）。只有一个字重，粗体也映射到它。
const String _chineseFontAsset = 'assets/fonts/NotoSansSC-Regular.ttf';

/// 打印时每个填空统一加长到这么多个下划线，留出手写的位置。
const int pdfBlankLength = 10;

// PDF 版式数值（单位：pt）。打印版式与屏幕不同，单独定义在这里。
const double _pageMargin = 32;
const double _titleSize = 22;
const double _metaSize = 11;
const double _sectionTitleSize = 14;
const double _bodySize = 12;
const double _tagSize = 10;
const double _lineSpacing = 4;
const double _sectionGap = 16;
const double _accentBarWidth = 4;
const double _tagRadius = 10;

PdfColor _pdfColor(int argb) => PdfColor.fromInt(argb);

final PdfColor _primary = _pdfColor(storybookColorScheme.primary.toARGB32());
final PdfColor _accent = _pdfColor(
  storybookColorScheme.primaryContainer.toARGB32(),
);
final PdfColor _ink = _pdfColor(StorybookTokens.light.ink.toARGB32());
final PdfColor _muted = _pdfColor(
  storybookColorScheme.onSurfaceVariant.toARGB32(),
);
final PdfColor _tagBackground = _pdfColor(
  storybookColorScheme.surfaceContainerHigh.toARGB32(),
);

/// 把连续的下划线（后端填空用 ___）统一替换为 [pdfBlankLength] 个下划线。
String expandBlanksForPrint(String text) =>
    text.replaceAll(RegExp(r'_{2,}'), '_' * pdfBlankLength);

/// 用页面相同的匹配逻辑（HighlightedText）拆分正文，目标词 / 中译夹注用 [highlight] 样式。
List<pw.TextSpan> pdfHighlightedSpans(
  String text,
  List<String> words, {
  required bool chinese,
  required pw.TextStyle highlight,
}) {
  // 只用作"是否命中"的标记，不参与 PDF 排版
  const marker = TextStyle();
  final spans = chinese
      ? buildChineseSpans(text, words, marker)
      : buildEnglishSpans(text, words, marker);
  return [
    for (final s in spans)
      pw.TextSpan(text: s.text, style: s.style == null ? null : highlight),
  ];
}

/// 学习记录导出为 PDF（A4，自动分页）。文案由页面传入的 [l10n] 提供：
/// 中文日期格式依赖界面加载本地化时初始化的日期数据。
class PdfExportService {
  PdfExportService({required this.l10n, Future<pw.Font> Function()? fontLoader})
    : _fontLoader = fontLoader;

  final AppLocalizations l10n;

  /// 测试时注入小字体，避免每次加载 10.5 MB 的思源黑体。
  final Future<pw.Font> Function()? _fontLoader;
  pw.Font? _font;

  Future<pw.Font> _loadFont() async {
    final cached = _font;
    if (cached != null) return cached;
    final loader = _fontLoader;
    final font = loader != null
        ? await loader()
        : pw.Font.ttf(await rootBundle.load(_chineseFontAsset));
    return _font = font;
  }

  /// 文档主题：常规、粗体、斜体都用同一个中文字体。
  /// 不映射粗体时 pdf 包会回退到 Helvetica-Bold，中文标题显示成方块。
  static pw.ThemeData buildTheme(pw.Font font) => pw.ThemeData.withFont(
    base: font,
    bold: font,
    italic: font,
    boldItalic: font,
  );

  Future<Uint8List> generatePdf(LearningRecord record) async {
    final font = await _loadFont();
    final pdf = pw.Document(theme: buildTheme(font), title: l10n.pdfTitle);
    final time = record.createdAtLocal;
    final body = pw.TextStyle(
      fontSize: _bodySize,
      lineSpacing: _lineSpacing,
      color: _ink,
    );
    final highlight = pw.TextStyle(color: _primary);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(_pageMargin),
        build: (context) => [
          pw.Text(
            l10n.pdfTitle,
            style: pw.TextStyle(fontSize: _titleSize, color: _primary),
          ),
          pw.SizedBox(height: _lineSpacing),
          if (time != null)
            pw.Text(
              l10n.pdfDate(time),
              style: pw.TextStyle(fontSize: _metaSize, color: _muted),
            ),
          pw.Text(
            l10n.recordMeta(
              record.words.length,
              difficultyLabel(l10n, record.difficulty),
            ),
            style: pw.TextStyle(fontSize: _metaSize, color: _muted),
          ),
          pw.Divider(color: _tagBackground),
          pw.SizedBox(height: _lineSpacing),
          _section(
            l10n.sectionWords,
            pw.Wrap(
              spacing: _lineSpacing * 1.5,
              runSpacing: _lineSpacing,
              children: [
                for (final w in record.words)
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(
                      horizontal: _lineSpacing * 2,
                      vertical: _lineSpacing,
                    ),
                    decoration: pw.BoxDecoration(
                      color: _tagBackground,
                      borderRadius: const pw.BorderRadius.all(
                        pw.Radius.circular(_tagRadius),
                      ),
                    ),
                    child: pw.Text(
                      w,
                      style: pw.TextStyle(fontSize: _tagSize, color: _ink),
                    ),
                  ),
              ],
            ),
          ),
          _section(
            l10n.sectionEnglishStory,
            pw.RichText(
              text: pw.TextSpan(
                style: body,
                children: pdfHighlightedSpans(
                  record.englishStory,
                  record.words,
                  chinese: false,
                  highlight: highlight,
                ),
              ),
            ),
          ),
          _section(
            l10n.sectionChineseTranslation,
            pw.RichText(
              text: pw.TextSpan(
                style: body,
                children: pdfHighlightedSpans(
                  record.chineseTranslation,
                  record.words,
                  chinese: true,
                  highlight: highlight,
                ),
              ),
            ),
          ),
          _section(
            l10n.sectionEnglishBlank,
            pw.Text(expandBlanksForPrint(record.englishBlank), style: body),
          ),
          _section(
            l10n.sectionChineseBlank,
            pw.Text(expandBlanksForPrint(record.chineseBlank), style: body),
          ),
        ],
      ),
    );

    return pdf.save();
  }

  /// 分节：左侧粉色竖条 + 标题（与页面的分节卡片标题呼应）。
  pw.Widget _section(String title, pw.Widget child) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: _sectionGap),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            children: [
              pw.Container(
                width: _accentBarWidth,
                height: _sectionTitleSize,
                color: _accent,
              ),
              pw.SizedBox(width: _lineSpacing * 1.5),
              pw.Text(
                title,
                style: pw.TextStyle(fontSize: _sectionTitleSize, color: _ink),
              ),
            ],
          ),
          pw.SizedBox(height: _lineSpacing * 2),
          child,
        ],
      ),
    );
  }

  Future<void> sharePdf(LearningRecord record) async {
    final pdfBytes = await generatePdf(record);
    await Printing.sharePdf(
      bytes: pdfBytes,
      filename:
          'english_learning_${record.id ?? DateTime.now().millisecondsSinceEpoch}.pdf',
    );
  }

  Future<void> savePdf(LearningRecord record) async {
    final pdfBytes = await generatePdf(record);
    final dir = await getApplicationDocumentsDirectory();
    final file = File(
      '${dir.path}/english_learning_${record.id ?? DateTime.now().millisecondsSinceEpoch}.pdf',
    );
    await file.writeAsBytes(pdfBytes);
  }
}
