import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/task_provider.dart';
import '../../../providers/settings_provider.dart';
import '../../../providers/tag_provider.dart';
import '../../tag/models/tag_model.dart';

class TagFilterWidget extends StatefulWidget {
  final TaskProvider taskProvider;
  final SettingsProvider settingsProvider;

  const TagFilterWidget({
    super.key,
    required this.taskProvider,
    required this.settingsProvider,
  });

  @override
  State<TagFilterWidget> createState() => _TagFilterWidgetState();
}

class _TagFilterWidgetState extends State<TagFilterWidget> {
  bool _isTagFilterExpanded = false;

  @override
  Widget build(BuildContext context) {
    final tagProvider = context.watch<TagProvider>();
    final tags = tagProvider.tags;
    final colorScheme = Theme.of(context).colorScheme;

    if (tags.isEmpty) {
      return const SizedBox.shrink();
    }

    final hasSelectedTag = widget.taskProvider.selectedTagId != null;
    Tag? selectedTag;
    if (hasSelectedTag) {
      try {
        selectedTag = tags.firstWhere(
          (t) => t.id == widget.taskProvider.selectedTagId,
        );
      } catch (_) {
        selectedTag = null;
      }
    }

    return Column(
      children: [
        InkWell(
          onTap: () {
            setState(() {
              _isTagFilterExpanded = !_isTagFilterExpanded;
            });
          },
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.local_offer_outlined,
                  size: 18,
                  color: hasSelectedTag
                      ? colorScheme.primary
                      : colorScheme.onSurface.withValues(alpha: 0.6),
                ),
                const SizedBox(width: 6),
                Text(
                  hasSelectedTag && selectedTag != null
                      ? '标签: ${selectedTag.name}'
                      : '标签筛选',
                  style: TextStyle(
                    fontSize: 13,
                    color: hasSelectedTag
                        ? colorScheme.primary
                        : colorScheme.onSurface.withValues(alpha: 0.7),
                    fontWeight: hasSelectedTag
                        ? FontWeight.w500
                        : FontWeight.normal,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  _isTagFilterExpanded
                      ? Icons.keyboard_arrow_up
                      : Icons.keyboard_arrow_down,
                  size: 18,
                  color: colorScheme.onSurface.withValues(alpha: 0.5),
                ),
              ],
            ),
          ),
        ),
        AnimatedCrossFade(
          firstChild: const SizedBox(width: double.infinity, height: 0),
          secondChild: Container(
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: tags.length + 1,
              itemBuilder: (context, index) {
                if (index == 0) {
                  final isSelected = widget.taskProvider.selectedTagId == null;
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: FilterChip(
                      label: const Text('全部'),
                      selected: isSelected,
                      onSelected: (_) {
                        widget.taskProvider.clearTagFilter();
                        widget.settingsProvider.setLastTagFilterId(null);
                      },
                      selectedColor: Colors.blue.withValues(alpha: 0.2),
                      checkmarkColor: Colors.blue,
                    ),
                  );
                }

                final tag = tags[index - 1];
                final isSelected = widget.taskProvider.selectedTagId == tag.id;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: FilterChip(
                    label: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: tag.flutterColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(tag.name),
                      ],
                    ),
                    selected: isSelected,
                    onSelected: (_) async {
                      final taskIds = await tagProvider.getTaskIdsByTag(
                        tag.id!,
                      );
                      widget.taskProvider.selectTag(tag.id!, taskIds: taskIds);
                      widget.settingsProvider.setLastTagFilterId(tag.id);
                    },
                    selectedColor: tag.flutterColor.withValues(alpha: 0.2),
                    checkmarkColor: tag.flutterColor,
                  ),
                );
              },
            ),
          ),
          crossFadeState: _isTagFilterExpanded
              ? CrossFadeState.showSecond
              : CrossFadeState.showFirst,
          duration: const Duration(milliseconds: 200),
        ),
      ],
    );
  }
}
