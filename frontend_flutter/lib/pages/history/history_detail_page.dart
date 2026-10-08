import 'package:flutter/material.dart';
import '../../l10n/l10n.dart';
import '../../models/learning_record.dart';
import '../../services/pdf_export_service.dart';
import '../../theme/theme_x.dart';
import '../../widgets/degraded_banner.dart';
import '../../widgets/ink_button.dart';
import '../../widgets/ink_toast.dart';
import '../../widgets/page_scaffold.dart';
import '../story/story_page.dart';

/// 历史详情页（设计稿 _2）：保存时间、与学习结果页相同的阅读区、底部"导出 PDF"（Q-F6）。
///
/// 状态：默认；示例内容（顶部提示，Q-F12）；导出中（按钮内进度，不可点）；
/// 导出失败（错误 Toast，不显示原始异常）。导出成功由系统分享面板 / 浏览器下载本身反馈。
class HistoryDetailPage extends StatefulWidget {
  final LearningRecord record;

  const HistoryDetailPage({super.key, required this.record});

  @override
  State<HistoryDetailPage> createState() => _HistoryDetailPageState();
}

class _HistoryDetailPageState extends State<HistoryDetailPage> {
  bool _exporting = false;

  Future<void> _exportPdf() async {
    if (_exporting) return;
    setState(() => _exporting = true);
    try {
      await PdfExportService(l10n: context.l10n).sharePdf(widget.record);
    } catch (e) {
      // 原始异常只写日志，界面显示固定文案（现状清单第 10 节第 10 条）
      debugPrint('exportPdf failed: $e');
      if (mounted) {
        showInkToast(context, context.l10n.exportPdfFailed, isError: true);
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final record = widget.record;
    final time = record.createdAtLocal;

    return PageScaffold(
      appBar: AppBar(title: Text(l10n.detailTitle)),
      banner: record.isDegraded
          ? DegradedBanner(
              reason: '',
              message: l10n.degradedSavedRecord,
              showReason: false,
            )
          : null,
      body: StoryContent(
        record: record,
        header: time == null ? null : _SavedTime(time: time),
        footer: InkButton(
          label: l10n.exportPdf,
          leadingIcon: Icons.picture_as_pdf,
          isLoading: _exporting,
          loadingLabel: l10n.exportPdfInProgress,
          onPressed: _exporting ? null : _exportPdf,
        ),
      ),
    );
  }
}

/// 保存时间："2026年10月5日 13:28"（本地时间）。
class _SavedTime extends StatelessWidget {
  const _SavedTime({required this.time});

  final DateTime time;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final c = context.colors;
    return Row(
      children: [
        Icon(Icons.calendar_month, size: tokens.iconMd, color: c.primary),
        SizedBox(width: tokens.spaceSm),
        Text(context.l10n.detailTime(time), style: context.text.labelMedium),
      ],
    );
  }
}
