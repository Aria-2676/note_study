import 'package:flutter/material.dart';
import '../core/services/database/database_service.dart';
import 'task_provider.dart' show TaskSortOption;

part 'mixins/settings_provider_core_mixin.dart';
part 'mixins/settings_persistence_mixin.dart';
part 'mixins/settings_mutation_mixin.dart';
part 'mixins/settings_pinned_mixin.dart';

/// 任务视图模式
enum TaskViewMode { simple, rich }

/// 任务创建模式
enum TaskCreateMode { minimal, full, custom }

/// 任务编辑模式
enum TaskEditMode { minimal, full, custom }

/// 快捷设置项位置
enum PinnedSettingLocation { profile, settings }

/// 快捷设置项类型
enum SettingType { toggle, segmented }

/// 快捷设置项定义
class PinnedSettingItem {
  final String key;
  final String title;
  final IconData icon;
  final SettingType type;
  final List<String>? options;

  const PinnedSettingItem({
    required this.key,
    required this.title,
    required this.icon,
    required this.type,
    this.options,
  });
}

/// 任务创建字段配置
class TaskCreateField {
  final String key;
  final String label;
  final IconData icon;
  final bool defaultEnabled;

  const TaskCreateField({
    required this.key,
    required this.label,
    required this.icon,
    this.defaultEnabled = true,
  });
}

/// 任务创建字段集合
class TaskCreateFields {
  static const description = TaskCreateField(
    key: 'description',
    label: '任务描述',
    icon: Icons.description_outlined,
    defaultEnabled: true,
  );

  static const rewardPoints = TaskCreateField(
    key: 'rewardPoints',
    label: '积分奖励',
    icon: Icons.stars_outlined,
    defaultEnabled: true,
  );

  static const date = TaskCreateField(
    key: 'date',
    label: '任务日期',
    icon: Icons.calendar_today,
    defaultEnabled: true,
  );

  static const recurrence = TaskCreateField(
    key: 'recurrence',
    label: '循环设置',
    icon: Icons.repeat,
    defaultEnabled: true,
  );

  static const priority = TaskCreateField(
    key: 'priority',
    label: '优先级',
    icon: Icons.flag_outlined,
    defaultEnabled: true,
  );

  static const isWord = TaskCreateField(
    key: 'isWord',
    label: '标签',
    icon: Icons.label,
    defaultEnabled: false,
  );

  static const List<TaskCreateField> all = [
    description,
    rewardPoints,
    date,
    recurrence,
    priority,
    isWord,
  ];
}

/// 应用设置状态管理Provider
///
/// 负责主题、视图模式、任务创建设置等。实现按职责拆分到 `mixins/` 下的 part
/// 文件（同一 library，可共享私有状态）：
/// - [SettingsProviderCoreMixin]：状态字段与只读视图
/// - [SettingsPersistenceMixin]：加载与保存
/// - [SettingsMutationMixin]：各设置项的变更
/// - [SettingsPinnedMixin]：快捷设置项管理
class SettingsProvider extends ChangeNotifier
    with
        SettingsProviderCoreMixin,
        SettingsPersistenceMixin,
        SettingsMutationMixin,
        SettingsPinnedMixin {
  static const int maxPinnedSettings = 6;

  static const Map<String, PinnedSettingItem> availablePinnedSettings = {
    'themeMode': PinnedSettingItem(
      key: 'themeMode',
      title: '夜间模式',
      icon: Icons.dark_mode,
      type: SettingType.toggle,
    ),
    'taskViewMode': PinnedSettingItem(
      key: 'taskViewMode',
      title: '任务视图',
      icon: Icons.view_agenda,
      type: SettingType.segmented,
      options: ['丰富', '简洁'],
    ),
    'taskCreateMode': PinnedSettingItem(
      key: 'taskCreateMode',
      title: '创建模式',
      icon: Icons.add_task,
      type: SettingType.segmented,
      options: ['极简', '完整', '自定义'],
    ),
    'allowEditPastTasks': PinnedSettingItem(
      key: 'allowEditPastTasks',
      title: '编辑非当天',
      icon: Icons.edit,
      type: SettingType.toggle,
    ),
    'allowCompletePastTasks': PinnedSettingItem(
      key: 'allowCompletePastTasks',
      title: '完成非当天',
      icon: Icons.check_circle,
      type: SettingType.toggle,
    ),
    'rememberFilters': PinnedSettingItem(
      key: 'rememberFilters',
      title: '记住筛选',
      icon: Icons.filter_list,
      type: SettingType.toggle,
    ),
  };
}
