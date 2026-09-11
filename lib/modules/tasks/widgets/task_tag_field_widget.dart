import 'package:flutter/material.dart';
import '../../tag/models/tag_model.dart';

/// 任务标签 / 单词任务选择。
///
/// 从 `task_form_widget.dart` 提取（规范 6：Widget ≤300 行）。
/// - 无标签时：显示「单词任务」勾选项
/// - 有标签时：显示标签筛选块，并依据「单词」标签同步单词任务状态
class TaskTagFieldWidget extends StatelessWidget {
  const TaskTagFieldWidget({
    super.key,
    required this.tags,
    required this.selectedTagIds,
    required this.isWord,
    required this.wordTagId,
    required this.onChanged,
  });

  final List<Tag> tags;
  final Set<int> selectedTagIds;
  final bool isWord;

  /// 「单词」标签的 id（若存在）。
  final int? wordTagId;

  /// 选择变化时回调：新的（选中标签集合, 是否单词任务）。
  final void Function(Set<int> selectedTagIds, bool isWord) onChanged;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    if (tags.isEmpty) {
      return InkWell(
        onTap: () => onChanged(selectedTagIds, !isWord),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            border: Border.all(
              color: colorScheme.outline.withValues(alpha: 0.5),
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(
                Icons.translate,
                size: 20,
                color: colorScheme.onSurface.withValues(alpha: 0.6),
              ),
              const SizedBox(width: 12),
              const Expanded(child: Text('单词任务')),
              Icon(
                isWord ? Icons.check_box : Icons.check_box_outline_blank,
                color: isWord
                    ? colorScheme.primary
                    : colorScheme.onSurface.withValues(alpha: 0.4),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '标签',
          style: TextStyle(
            fontSize: 14,
            color: colorScheme.onSurface.withValues(alpha: 0.7),
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: tags.map((tag) {
            final isSelected = selectedTagIds.contains(tag.id);
            return FilterChip(
              label: Text(tag.name),
              selected: isSelected,
              selectedColor: tag.flutterColor.withValues(alpha: 0.3),
              checkmarkColor: tag.flutterColor,
              avatar: Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: tag.flutterColor,
                  shape: BoxShape.circle,
                ),
              ),
              onSelected: (selected) {
                final next = Set<int>.from(selectedTagIds);
                if (selected) {
                  next.add(tag.id!);
                } else {
                  next.remove(tag.id);
                }
                onChanged(next, wordTagId != null && next.contains(wordTagId));
              },
            );
          }).toList(),
        ),
      ],
    );
  }
}
