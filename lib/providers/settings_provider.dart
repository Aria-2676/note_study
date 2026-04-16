import 'package:flutter/material.dart';
import '../core/services/database_service.dart';
import 'task_provider.dart' show TaskSortOption;

/// 任务视图模式
enum TaskViewMode { simple, rich }

/// 任务创建模式
enum TaskCreateMode { minimal, full, custom }

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
    label: '单词任务',
    icon: Icons.translate,
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
/// 负责主题、视图模式、任务创建设置等
class SettingsProvider extends ChangeNotifier {
  final DatabaseService _db = DatabaseService.instance;

  ThemeMode _themeMode = ThemeMode.light;
  TaskViewMode _taskViewMode = TaskViewMode.simple;
  TaskCreateMode _taskCreateMode = TaskCreateMode.minimal;
  TaskSortOption _taskSortOption = TaskSortOption.defaultOrder;
  final Set<String> _enabledCreateFields = {};

  bool _allowEditPastTasks = false;
  bool _allowCompletePastTasks = false;

  ThemeMode get themeMode => _themeMode;
  TaskViewMode get taskViewMode => _taskViewMode;
  TaskCreateMode get taskCreateMode => _taskCreateMode;
  TaskSortOption get taskSortOption => _taskSortOption;
  Set<String> get enabledCreateFields => _enabledCreateFields;
  bool get allowEditPastTasks => _allowEditPastTasks;
  bool get allowCompletePastTasks => _allowCompletePastTasks;

  bool get isDark => _themeMode == ThemeMode.dark;
  bool get isRichView => _taskViewMode == TaskViewMode.rich;

  bool isFieldEnabled(String key) {
    return _enabledCreateFields.contains(key);
  }

  Future<void> initialize() async {
    await _loadSettings();
  }

  Future<void> _loadSettings() async {
    final settings = await _db.getSettings();
    _themeMode = settings['themeMode'] == 'dark'
        ? ThemeMode.dark
        : ThemeMode.light;
    _taskViewMode = settings['taskViewMode'] == 'simple'
        ? TaskViewMode.simple
        : TaskViewMode.rich;

    final createModeStr = settings['taskCreateMode'];
    if (createModeStr == 'full') {
      _taskCreateMode = TaskCreateMode.full;
    } else if (createModeStr == 'custom') {
      _taskCreateMode = TaskCreateMode.custom;
    } else {
      _taskCreateMode = TaskCreateMode.minimal;
    }

    final sortOptionStr = settings['taskSortOption'];
    _taskSortOption = TaskSortOption.values.firstWhere(
      (e) => e.name == sortOptionStr,
      orElse: () => TaskSortOption.defaultOrder,
    );

    final enabledFieldsStr = settings['enabledCreateFields'];
    if (enabledFieldsStr != null && enabledFieldsStr.isNotEmpty) {
      _enabledCreateFields.clear();
      _enabledCreateFields.addAll(enabledFieldsStr.split(','));
    } else {
      _enabledCreateFields.clear();
      for (final field in TaskCreateFields.all) {
        if (field.defaultEnabled) {
          _enabledCreateFields.add(field.key);
        }
      }
    }

    _allowEditPastTasks = settings['allowEditPastTasks'] == 'true';
    _allowCompletePastTasks = settings['allowCompletePastTasks'] == 'true';
  }

  Future<void> _saveSettings() async {
    await _db.saveSettings({
      'themeMode': _themeMode == ThemeMode.dark ? 'dark' : 'light',
      'taskViewMode': _taskViewMode == TaskViewMode.simple ? 'simple' : 'rich',
      'taskCreateMode': _taskCreateMode == TaskCreateMode.full
          ? 'full'
          : _taskCreateMode == TaskCreateMode.custom
          ? 'custom'
          : 'minimal',
      'taskSortOption': _taskSortOption.name,
      'enabledCreateFields': _enabledCreateFields.join(','),
      'allowEditPastTasks': _allowEditPastTasks ? 'true' : 'false',
      'allowCompletePastTasks': _allowCompletePastTasks ? 'true' : 'false',
    });
  }

  void toggleTheme() {
    _themeMode = _themeMode == ThemeMode.light
        ? ThemeMode.dark
        : ThemeMode.light;
    _saveSettings();
    notifyListeners();
  }

  void setTaskViewMode(TaskViewMode mode) {
    _taskViewMode = mode;
    _saveSettings();
    notifyListeners();
  }

  void toggleTaskViewMode() {
    _taskViewMode = _taskViewMode == TaskViewMode.rich
        ? TaskViewMode.simple
        : TaskViewMode.rich;
    _saveSettings();
    notifyListeners();
  }

  void setTaskSortOption(TaskSortOption option) {
    _taskSortOption = option;
    _saveSettings();
    notifyListeners();
  }

  void setTaskCreateMode(TaskCreateMode mode) {
    _taskCreateMode = mode;
    if (mode == TaskCreateMode.full) {
      _enabledCreateFields.clear();
      _enabledCreateFields.addAll(TaskCreateFields.all.map((f) => f.key));
    } else if (mode == TaskCreateMode.minimal) {
      _enabledCreateFields.clear();
    }
    _saveSettings();
    notifyListeners();
  }

  void toggleCreateField(String fieldKey) {
    if (_taskCreateMode != TaskCreateMode.custom) return;

    if (_enabledCreateFields.contains(fieldKey)) {
      _enabledCreateFields.remove(fieldKey);
    } else {
      _enabledCreateFields.add(fieldKey);
    }
    _saveSettings();
    notifyListeners();
  }

  void setEnabledCreateFields(Set<String> fields) {
    _enabledCreateFields.clear();
    _enabledCreateFields.addAll(fields);
    _saveSettings();
    notifyListeners();
  }

  void setAllowEditPastTasks(bool value) {
    _allowEditPastTasks = value;
    _saveSettings();
    notifyListeners();
  }

  void setAllowCompletePastTasks(bool value) {
    _allowCompletePastTasks = value;
    _saveSettings();
    notifyListeners();
  }
}
