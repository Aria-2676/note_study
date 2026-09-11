part of '../settings_provider.dart';

/// 设置的变更方法：主题、视图、排序、创建/编辑字段、筛选记忆等。
///
/// 每个 setter 都是「改内存 → 落库 → 通知」的同一节奏。
mixin SettingsMutationMixin
    on SettingsProviderCoreMixin, SettingsPersistenceMixin {
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
}
