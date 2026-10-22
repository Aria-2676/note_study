import 'package:flutter/material.dart';

import '../models/calendar_strip_style.dart';
import 'destinations.dart';

/// 「我的」页。两块内容：
///   1. 设置项（日历条形态、删除确认）—— 内联控件
///   2. 入口清单 —— 与侧边栏**同源**（[AppDestination]），只是带右箭头
class ProfileStubPage extends StatelessWidget {
  const ProfileStubPage({
    super.key,
    required this.calendarStyle,
    required this.onCalendarStyleChanged,
    required this.confirmBeforeDelete,
    required this.onConfirmBeforeDeleteChanged,
    required this.onOpenDestination,
  });

  final CalendarStripStyle calendarStyle;
  final ValueChanged<CalendarStripStyle> onCalendarStyleChanged;

  /// 删除前是否弹确认框（对应"以后不再提醒"那个勾选）
  final bool confirmBeforeDelete;
  final ValueChanged<bool> onConfirmBeforeDeleteChanged;

  final ValueChanged<AppDestination> onOpenDestination;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: <Widget>[
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: <Widget>[
              Icon(Icons.bolt, size: 20, color: scheme.outline),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '当前货币：未安装',
                  style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Text('外观', style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
        const SizedBox(height: 6),
        Row(
          children: <Widget>[
            const Expanded(child: Text('日历条形态', style: TextStyle(fontSize: 14))),
            SegmentedButton<CalendarStripStyle>(
              segments: CalendarStripStyle.values
                  .map((s) => ButtonSegment<CalendarStripStyle>(value: s, label: Text(s.label)))
                  .toList(),
              selected: <CalendarStripStyle>{calendarStyle},
              showSelectedIcon: false,
              style: const ButtonStyle(visualDensity: VisualDensity.compact),
              onSelectionChanged: (selection) => onCalendarStyleChanged(selection.first),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Divider(color: scheme.outlineVariant.withValues(alpha: 0.5)),
        const SizedBox(height: 4),
        Text('操作', style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          dense: true,
          title: const Text('删除前确认', style: TextStyle(fontSize: 14)),
          subtitle: Text(
            confirmBeforeDelete ? '左滑删除前会问一次' : '左滑直接移入回收站',
            style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
          ),
          value: confirmBeforeDelete,
          onChanged: onConfirmBeforeDeleteChanged,
        ),
        Divider(color: scheme.outlineVariant.withValues(alpha: 0.5)),
        const SizedBox(height: 4),
        Text('入口', style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
        const SizedBox(height: 2),
        for (final destination in AppDestination.values
            .where((d) => d.surfaces.contains(DestinationSurface.profile)))
          DestinationTile(
            destination: destination,
            showChevron: true,
            onTap: () => onOpenDestination(destination),
          ),
      ],
    );
  }
}
