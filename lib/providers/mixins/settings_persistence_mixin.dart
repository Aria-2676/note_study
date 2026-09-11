part of '../settings_provider.dart';

/// 设置的持久化读写。
mixin SettingsPersistenceMixin on SettingsProviderCoreMixin {
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
          .where((k) => SettingsProvider.availablePinnedSettings.containsKey(k))
          .toList();
    }

    final settingsPinnedStr = settings['settingsPinnedSettings'];
    if (settingsPinnedStr != null && settingsPinnedStr.isNotEmpty) {
      _settingsPinnedSettings = settingsPinnedStr
          .split(',')
          .where((k) => SettingsProvider.availablePinnedSettings.containsKey(k))
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
}
