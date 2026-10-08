import 'package:flutter/material.dart';

import '../theme/theme_x.dart';

/// 把内容限制在 maxContentWidth（480）以内并水平居中。桌面浏览器宽窗口下不再拉满（Q-V9）。
class ContentWidth extends StatelessWidget {
  const ContentWidth({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: context.tokens.maxContentWidth),
        child: child,
      ),
    );
  }
}

/// 页面外壳：纸色背景、可选的顶部固定提示条（如降级提示）、限宽内容区。
/// 提示条和内容都限宽；背景铺满整个窗口。
class PageScaffold extends StatelessWidget {
  const PageScaffold({
    super.key,
    required this.body,
    this.appBar,
    this.banner,
    this.bottom,
    this.bottomNavigationBar,
  });

  final PreferredSizeWidget? appBar;

  /// 固定在顶栏下方、不随内容滚动。
  final Widget? banner;
  final Widget body;

  /// 固定在底部的操作区（如确认页的添加单词与生成按钮）。
  final Widget? bottom;
  final Widget? bottomNavigationBar;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: appBar,
      bottomNavigationBar: bottomNavigationBar,
      body: Column(
        children: [
          if (banner != null) ContentWidth(child: banner!),
          Expanded(child: ContentWidth(child: body)),
          if (bottom != null) ContentWidth(child: bottom!),
        ],
      ),
    );
  }
}
