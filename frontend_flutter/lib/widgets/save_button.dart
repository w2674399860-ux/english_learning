import 'package:flutter/material.dart';

/// 学习结果页的保存按钮，三种状态：可保存 / 保存中 / 已保存。
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
    if (isSaving) {
      return const IconButton(
        icon: SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
        // onPressed 为 null 时 IconButton 自动禁用并置灰
        onPressed: null,
        tooltip: 'Saving',
      );
    }

    if (isSaved) {
      return const IconButton(
        icon: Icon(Icons.check),
        onPressed: null,
        tooltip: 'Saved',
      );
    }

    return IconButton(
      icon: const Icon(Icons.save),
      onPressed: onPressed,
      tooltip: 'Save Record',
    );
  }
}
