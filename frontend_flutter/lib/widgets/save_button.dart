import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import 'ink_button.dart';

/// 学习结果页顶栏右侧的保存按钮（设计稿 _1），三种状态：
/// - 可保存：书签图标 +"保存"；
/// - 保存中：进度圈 +"保存中"，不可点；
/// - 已保存：对勾 +"已保存"，置灰不可再点（不像设计稿那样 2 秒后变回"保存"，避免重复保存）。
class SaveButton extends StatelessWidget {
  const SaveButton({
    super.key,
    required this.isSaving,
    required this.isSaved,
    required this.onPressed,
  });

  final bool isSaving;
  final bool isSaved;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    if (isSaved) {
      return InkButton(
        label: l10n.saveButtonSaved,
        leadingIcon: Icons.check,
        variant: InkButtonVariant.lime,
        compact: true,
        onPressed: null,
      );
    }
    return InkButton(
      label: l10n.saveButton,
      leadingIcon: Icons.bookmark,
      compact: true,
      isLoading: isSaving,
      loadingLabel: l10n.saveButtonSaving,
      onPressed: isSaving ? null : onPressed,
    );
  }
}
