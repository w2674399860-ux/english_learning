import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../models/learning_record.dart';
import '../theme/theme_x.dart';
import 'ink_card.dart';
import 'word_tag.dart';

/// 历史卡片上最多显示的单词标签数，其余折叠为 "+N"。
const int historyCardMaxTags = 5;

/// 历史列表中的一条记录（设计稿 ai_4）：左上角胶带装饰；
/// 第一行时间（本地时间）、难度 · 词数、删除按钮；短文前 3 行；单词标签；右下"查看详情"。
class HistoryRecordCard extends StatelessWidget {
  const HistoryRecordCard({
    super.key,
    required this.record,
    required this.index,
    required this.onTap,
    required this.onDelete,
  });

  final LearningRecord record;

  /// 在列表中的位置：决定胶带颜色与倾斜方向，让相邻卡片看起来不一样。
  final int index;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final c = context.colors;
    final l10n = context.l10n;
    final time = record.createdAtLocal;
    final tapeColor = tokens.tapeColors[index % tokens.tapeColors.length];
    final tilt = (index.isEven ? -1 : 1) * tokens.tiltDegrees * math.pi / 180;

    final header = Row(
      children: [
        Icon(Icons.schedule, size: tokens.iconSm, color: c.primary),
        SizedBox(width: tokens.spaceXs),
        if (time != null)
          Text(
            l10n.historyCardTime(time),
            style: context.text.labelSmall?.copyWith(color: c.onSurfaceVariant),
          ),
        SizedBox(width: tokens.spaceSm),
        Container(
          width: tokens.tagDot,
          height: tokens.tagDot,
          decoration: BoxDecoration(color: c.secondary, shape: BoxShape.circle),
        ),
        SizedBox(width: tokens.spaceXs),
        Flexible(
          child: Text(
            l10n.historyCardMeta(
              difficultyLabel(l10n, record.difficulty),
              record.words.length,
            ),
            style: context.text.labelSmall?.copyWith(color: c.secondary),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const Spacer(),
        IconButton(
          tooltip: l10n.historyDeleteTooltip,
          onPressed: onDelete,
          icon: Icon(Icons.delete, size: tokens.iconSm),
          color: c.onSurfaceVariant,
          style: IconButton.styleFrom(
            backgroundColor: c.surfaceContainer,
            fixedSize: Size.square(tokens.iconTile),
            minimumSize: Size.square(tokens.iconTile),
          ),
        ),
      ],
    );

    return Stack(
      clipBehavior: Clip.none,
      children: [
        InkCard(
          shadow: tokens.shadowButton,
          onTap: onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              header,
              SizedBox(height: tokens.spaceSm),
              Text(
                record.englishStory,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: context.text.bodyMedium,
              ),
              SizedBox(height: tokens.spaceMd),
              WordTagWrap(words: record.words, maxVisible: historyCardMaxTags),
              SizedBox(height: tokens.spaceSm),
              Align(
                alignment: Alignment.centerRight,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      l10n.historyCardViewDetail,
                      style: context.text.labelMedium?.copyWith(
                        color: c.primary,
                      ),
                    ),
                    Icon(
                      Icons.chevron_right,
                      size: tokens.iconMd,
                      color: c.primary,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        // 胶带装饰：纯装饰，不进语义树，不拦截点击
        Positioned(
          top: -tokens.spaceXs,
          left: tokens.spaceXl,
          child: IgnorePointer(
            child: ExcludeSemantics(
              child: Transform.rotate(
                angle: tilt,
                child: Container(
                  width: tokens.iconTileLg,
                  height: tokens.spaceMd,
                  decoration: BoxDecoration(
                    color: tapeColor,
                    borderRadius: BorderRadius.circular(tokens.radiusXs),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
