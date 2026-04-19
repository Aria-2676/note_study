import 'package:flutter/material.dart';
import '../core/services/database/database_service.dart';
import 'task_provider.dart' show TaskSortOption;

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
/// 负责主题、视图模式、任务创建设置等
class SettingsProvider extends ChangeNotifier {
  final DatabaseService _db = DatabaseService.instance;

  ThemeMode _themeMode = ThemeMode.light;
  TaskViewMode _taskViewMode = TaskViewMode.simple;
  TaskCreateMode _taskCreateMode = TaskCreateMode.full;
  TaskEditMode _taskEditMode = TaskEditMode.full;
  TaskSortOption _taskSortOption = TaskSortOption.defaultOrder;
  final Set<String> _enabledCreateFields = {};
  final Set<String> _enabledEditFields = {};

  bool _allowEditPastTasks = false;
  bool _allowCompletePastTasks = false;

  String? _lastPriorityFilter;
  bool? _lastCompletionFilter;
  bool? _lastRecurrenceFilter;
  int? _lastTagFilterId;
  bool _rememberFilters = true;

  List<String> _profilePinnedSettings = [];
  List<String> _settingsPinnedSettings = [];

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

  ThemeMode get themeMode => _themeMode;
  TaskViewMode get taskViewMode => _taskViewMode;
  TaskCreateMode get taskCreateMode => _taskCreateMode;
  TaskEditMode get taskEditMode => _taskEditMode;
  TaskSortOption get taskSortOption => _taskSortOption;
  Set<String> get enabledCreateFields => _enabledCreateFields;
  Set<String> get enabledEditFields => _enabledEditFields;
  bool get allowEditPastTasks => _allowEditPastTasks;
  bool get allowCompletePastTasks => _allowCompletePastTasks;

  String? get lastPriorityFilter => _lastPriorityFilter;
  bool? get lastCompletionFilter => _lastCompletionFilter;
  bool? get lastRecurrenceFilter => _lastRecurrenceFilter;
  int? get lastTagFilterId => _lastTagFilterId;
  bool get rememberFilters => _rememberFilters;

  bool get isDark => _themeMode == ThemeMode.dark;
  bool get isRichView => _taskViewMode == TaskViewMode.rich;

  List<String> get profilePinnedSettings => _profilePinnedSettings;
  List<String> get settingsPinnedSettings => _settingsPinnedSettings;

  bool isFieldEnabled(String key) {
    return _enabledCreateFields.contains(key);
  }

  bool isEditFieldEnabled(String key) {
    return _enabledEditFields.contains(key);
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
    } else if (createModeStr == 'minimal') {
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

    final editModeStr = settings['taskEditMode'];
    if (editModeStr == 'full') {
      _taskEditMode = TaskEditMode.full;
    } else if (editModeStr == 'custom') {
      _taskEditMode = TaskEditMode.custom;
    } else if (editModeStr == 'minimal') {
      _taskEditMode = TaskEditMode.minimal;
    }

    final enabledEditFieldsStr = settings['enabledEditFields'];
    if (enabledEditFieldsStr != null && enabledEditFieldsStr.isNotEmpty) {
      _enabledEditFields.clear();
      _enabledEditFields.addAll(enabledEditFieldsStr.split(','));
    } else {
      _enabledEditFields.clear();
      for (final field in TaskCreateFields.all) {
        if (field.defaultEnabled) {
          _enabledEditFields.add(field.key);
        }
      }
    }

    _allowEditPastTasks = settings['allowEditPastTasks'] == 'true';
    _allowCompletePastTasks = settings['allowCompletePastTasks'] == 'true';

    final priorityFilter = settings['lastPriorityFilter'];
    _lastPriorityFilter = (priorityFilter == null || priorityFilter.isEmpty)
        ? null
        : priorityFilter;
    _lastCompletionFilter = settings['lastCompletionFilter'] == 'true'
        ? true
        : settings['lastCompletionFilter'] == 'false'
        ? false
        : null;
    _lastRecurrenceFilter = settings['lastRecurrenceFilter'] == 'true'
        ? true
        : settings['lastRecurrenceFilter'] == 'false'
        ? false
        : null;
    final tagIdStr = settings['lastTagFilterId'];
    _lastTagFilterId = tagIdStr != null && tagIdStr.isNotEmpty
        ? int.tryParse(tagIdStr)
        : null;
    _rememberFilters = settings['rememberFilters'] != 'false';

    final profilePinnedStr = settings['profilePinnedSettings'];
    if (profilePinnedStr != null && profilePinnedStr.isNotEmpty) {
      _profilePinnedSettings = profilePinnedStr
          .split(',')
          .where((k) => availablePinnedSettings.containsKey(k))
          .toList();
    }

    final settingsPinnedStr = settings['settingsPinnedSettings'];
    if (settingsPinnedStr != null && settingsPinnedStr.isNotEmpty) {
      _settingsPinnedSettings = settingsPinnedStr
          .split(',')
          .where((k) => availablePinnedSettings.containsKey(k))
          .toList();
    }
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
      'taskEditMode': _taskEditMode == TaskEditMode.full
          ? 'full'
          : _taskEditMode == TaskEditMode.custom
          ? 'custom'
          : 'minimal',
      'taskSortOption': _taskSortOption.name,
      'enabledCreateFields': _enabledCreateFields.join(','),
      'enabledEditFields': _enabledEditFields.join(','),
      'allowEditPastTasks': _allowEditPastTasks ? 'true' : 'false',
      'allowCompletePastTasks': _allowCompletePastTasks ? 'true' : 'false',
      'lastPriorityFilter': _lastPriorityFilter ?? '',
      'lastCompletionFilter': _lastCompletionFilter == null
          ? ''
          : _lastCompletionFilter!
          ? 'true'
          : 'false',
      'lastRecurrenceFilter': _lastRecurrenceFilter == null
          ? ''
          : _lastRecurrenceFilter!
          ? 'true'
          : 'false',
      'lastTagFilterId': _lastTagFilterId?.toString() ?? '',
      'rememberFilters': _rememberFilters ? 'true' : 'false',
      'profilePinnedSettings': _profilePinnedSettings.join(','),
      'settingsPinnedSettings': _settingsPinnedSettings.join(','),
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

  void setTaskEditMode(TaskEditMode mode) {
    _taskEditMode = mode;
    if (mode == TaskEditMode.full) {
      _enabledEditFields.clear();
      _enabledEditFields.addAll(TaskCreateFields.all.map((f) => f.key));
    } else if (mode == TaskEditMode.minimal) {
      _enabledEditFields.clear();
    }
    _saveSettings();
    notifyListeners();
  }

  void toggleEditField(String fieldKey) {
    if (_taskEditMode != TaskEditMode.custom) return;

    if (_enabledEditFields.contains(fieldKey)) {
      _enabledEditFields.remove(fieldKey);
    } else {
      _enabledEditFields.add(fieldKey);
    }
    _saveSettings();
    notifyListeners();
  }

  void setEnabledEditFields(Set<String> fields) {
    _enabledEditFields.clear();
    _enabledEditFields.addAll(fields);
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

  void setLastPriorityFilter(String? value) {
    _lastPriorityFilter = value;
    _saveSettings();
    notifyListeners();
  }

  void setLastCompletionFilter(bool? value) {
    _lastCompletionFilter = value;
    _saveSettings();
    notifyListeners();
  }

  void setLastRecurrenceFilter(bool? value) {
    _lastRecurrenceFilter = value;
    _saveSettings();
    notifyListeners();
  }

  void setLastTagFilterId(int? value) {
    _lastTagFilterId = value;
    _saveSettings();
    notifyListeners();
  }

  void setRememberFilters(bool value) {
    _rememberFilters = value;
    _saveSettings();
    notifyListeners();
  }

  void clearAllFilters() {
    _lastPriorityFilter = null;
    _lastCompletionFilter = null;
    _lastRecurrenceFilter = null;
    _lastTagFilterId = null;
    _saveSettings();
    notifyListeners();
  }

  bool addPinnedSetting(String key, PinnedSettingLocation location) {
    if (!availablePinnedSettings.containsKey(key)) return false;

    final list = location == PinnedSettingLocation.profile
        ? _profilePinnedSettings
        : _settingsPinnedSettings;

    if (list.contains(key)) return false;
    if (list.length >= maxPinnedSettings) return false;

    list.add(key);
    _saveSettings();
    notifyListeners();
    return true;
  }

  void removePinnedSetting(String key, PinnedSettingLocation location) {
    final list = location == PinnedSettingLocation.profile
        ? _profilePinnedSettings
        : _settingsPinnedSettings;

    if (list.remove(key)) {
      _saveSettings();
      notifyListeners();
    }
  }

  void reorderPinnedSettings(
    int oldIndex,
    int newIndex,
    PinnedSettingLocation location,
  ) {
    final list = location == PinnedSettingLocation.profile
        ? _profilePinnedSettings
        : _settingsPinnedSettings;

    if (oldIndex < 0 ||
        oldIndex >= list.length ||
        newIndex < 0 ||
        newIndex >= list.length) {
      return;
    }

    final item = list.removeAt(oldIndex);
    list.insert(newIndex, item);
    _saveSettings();
    notifyListeners();
  }

  void resetPinnedSettings(PinnedSettingLocation? location) {
    if (location == null) {
      _profilePinnedSettings.clear();
      _settingsPinnedSettings.clear();
    } else if (location == PinnedSettingLocation.profile) {
      _profilePinnedSettings.clear();
    } else {
      _settingsPinnedSettings.clear();
    }
    _saveSettings();
    notifyListeners();
  }

  bool isPinned(String key, PinnedSettingLocation location) {
    final list = location == PinnedSettingLocation.profile
        ? _profilePinnedSettings
        : _settingsPinnedSettings;
    return list.contains(key);
  }
}
