import 'package:english_learning_app/l10n/l10n.dart';
import 'package:english_learning_app/providers/difficulty.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/pump_app.dart';

void main() {
  test('只提供简体中文', () {
    expect(AppLocalizations.supportedLocales, [const Locale('zh')]);
    expect(appL10n.appTitle, 'AI 英语学习');
  });

  test('带参数的文案', () {
    expect(testL10n.confirmSelectedCount(18, 20), '已选 18 / 20');
    expect(testL10n.historyLoadMore(20, 57), '加载更多（20 / 57）');
    expect(testL10n.historyAllLoaded(57), '已显示全部 57 条记录');
    expect(testL10n.confirmGenerateFailed('请求超时，请重试。'), '生成失败：请求超时，请重试。');
    expect(testL10n.historyNoMatch('zebra'), '没有匹配“zebra”的记录');
    expect(
      testL10n.deleteDialogWords('harvest、lantern、journey', 18),
      '包含 harvest、lantern、journey 等 18 个单词',
    );
    expect(testL10n.rateLimitedCountdown('07:59'), '07:59 后可再试');
    expect(testL10n.errorServer(500), '服务器出错（500），请稍后再试。');
  });

  // 日期格式依赖 intl 的中文日期数据，由 MaterialApp 加载 GlobalMaterialLocalizations 时初始化，
  // 所以放在 Widget 树里测（与 App 实际使用方式一致）
  testWidgets('时间格式（列表 / 详情）', (tester) async {
    await pumpLocalized(tester, const SizedBox());
    final l10n = AppLocalizations.of(tester.element(find.byType(SizedBox)));
    final t = DateTime(2026, 10, 5, 13, 8);
    expect(l10n.historyCardTime(t), '10月5日 13:08');
    expect(l10n.detailTime(t), '2026年10月5日 13:08');
    expect(l10n.pdfDate(t), '日期：2026年10月5日 13:08');
  });

  test('难度显示中文，传给后端的值不变', () {
    expect(Difficulty.values.map((d) => difficultyLabel(testL10n, d)), [
      '初级',
      '中级',
      '高级',
    ]);
    expect(Difficulty.intermediate.apiValue, 'intermediate');
  });

  testWidgets('系统控件为中文（返回按钮提示）', (tester) async {
    await pumpLocalized(tester, const BackButton());
    final localizations = MaterialLocalizations.of(
      tester.element(find.byType(BackButton)),
    );
    expect(localizations.backButtonTooltip, '返回');
    expect(localizations.copyButtonLabel, '复制');
  });
}
