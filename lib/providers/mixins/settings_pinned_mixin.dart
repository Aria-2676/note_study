part of '../settings_provider.dart';

/// 快捷设置项（profile / settings 两处的置顶项）的增删与排序。
mixin SettingsPinnedMixin
    on SettingsProviderCoreMixin, SettingsPersistenceMixin {
  bool addPinnedSetting(String key, PinnedSettingLocation location) {
    if (!SettingsProvider.availablePinnedSettings.containsKey(key)) return false;

    final list = location == PinnedSettingLocation.profile
        ? _profilePinnedSettings
        : _settingsPinnedSettings;

    if (list.contains(key)) return false;
    if (list.length >= SettingsProvider.maxPinnedSettings) return false;

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
