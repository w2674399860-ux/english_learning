import 'package:flutter/material.dart';
import '../providers/difficulty.dart';

/// 确认页的难度选择。onChanged 为 null 时禁用（例如生成中）。
class DifficultySelector extends StatelessWidget {
  const DifficultySelector({super.key, required this.value, this.onChanged});

  final Difficulty value;
  final ValueChanged<Difficulty>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text('Difficulty', style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(width: 12),
        Expanded(
          child: Wrap(
            spacing: 8,
            runSpacing: 4,
            children: Difficulty.values
                .map((d) => ChoiceChip(
                      label: Text(d.label),
                      selected: d == value,
                      onSelected:
                          onChanged == null ? null : (_) => onChanged!(d),
                    ))
                .toList(),
          ),
        ),
      ],
    );
  }
}
