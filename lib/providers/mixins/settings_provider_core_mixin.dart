part of '../settings_provider.dart';

/// 设置状态的共享字段与只读视图。
///
/// 其余 mixin 都声明 `on SettingsProviderCoreMixin`，因此都能直接读写这里的私有字段。
/// [`SettingsProvider`] 自身只保留静态常量表（`availablePinnedSettings` 等）。
mixin SettingsProviderCoreMixin on ChangeNotifier {
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
}
