import 'dart:io';
import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:path_provider/path_provider.dart';
import '../models/learning_record.dart';

class PdfExportService {
  Future<Uint8List> generatePdf(LearningRecord record) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (context) => [
          pw.Header(
            level: 0,
            child: pw.Text('English Learning Record',
                style: pw.TextStyle(
                    fontSize: 22, fontWeight: pw.FontWeight.bold)),
          ),
          if (record.createdAt != null)
            pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 20),
              child: pw.Text('Date: ${record.createdAt}',
                  style: const pw.TextStyle(
                      fontSize: 11, color: PdfColors.grey700)),
            ),
          _buildSection('Recognized Words',
              child: pw.Wrap(
                spacing: 6,
                runSpacing: 3,
                children: record.words
                    .map((w) => pw.Container(
                          padding: const pw.EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: pw.BoxDecoration(
                            color: PdfColors.blue50,
                            borderRadius:
                                const pw.BorderRadius.all(pw.Radius.circular(12)),
                          ),
                          child: pw.Text(w, style: const pw.TextStyle(fontSize: 10)),
                        ))
                    .toList(),
              )),
          _buildSection('English Story',
              child: pw.Paragraph(
                  text: record.englishStory,
                  style: const pw.TextStyle(fontSize: 12, lineSpacing: 1.5))),
          _buildSection('Chinese Translation',
              child: pw.Paragraph(
                  text: record.chineseTranslation,
                  style: const pw.TextStyle(fontSize: 12, lineSpacing: 1.5))),
          _buildSection('English Fill-in-the-Blank',
              child: pw.Paragraph(
                  text: record.englishBlank,
                  style: const pw.TextStyle(
                      fontSize: 12, lineSpacing: 1.5, color: PdfColors.blue800))),
          _buildSection('Chinese Fill-in-the-Blank',
              child: pw.Paragraph(
                  text: record.chineseBlank,
                  style: const pw.TextStyle(
                      fontSize: 12, lineSpacing: 1.5, color: PdfColors.blue800))),
        ],
      ),
    );

    return pdf.save();
  }

  pw.Widget _buildSection(String title, {required pw.Widget child}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 16),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Container(
            margin: const pw.EdgeInsets.only(bottom: 8),
            child: pw.Text(
              title,
              style: pw.TextStyle(
                fontSize: 14,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.blue700,
              ),
            ),
          ),
          child,
        ],
      ),
    );
  }

  Future<void> sharePdf(LearningRecord record) async {
    final pdfBytes = await generatePdf(record);
    await Printing.sharePdf(
      bytes: pdfBytes,
      filename: 'english_learning_${record.id ?? DateTime.now().millisecondsSinceEpoch}.pdf',
    );
  }

  Future<void> savePdf(LearningRecord record) async {
    final pdfBytes = await generatePdf(record);
    final dir = await getApplicationDocumentsDirectory();
    final file = File(
        '${dir.path}/english_learning_${record.id ?? DateTime.now().millisecondsSinceEpoch}.pdf');
    await file.writeAsBytes(pdfBytes);
  }
}
