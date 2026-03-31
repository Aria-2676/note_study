import 'package:flutter/material.dart';
import '../repositories/settings_repository.dart';

enum TaskViewMode { simple, rich }

class SettingsProvider extends ChangeNotifier {
  final SettingsRepository _settingsRepo = SettingsRepository();

  ThemeMode _themeMode = ThemeMode.light;
  TaskViewMode _taskViewMode = TaskViewMode.simple;
  bool _tutorialCompleted = false;

  ThemeMode get themeMode => _themeMode;
  TaskViewMode get taskViewMode => _taskViewMode;
  bool get tutorialCompleted => _tutorialCompleted;

  bool get isDark => _themeMode == ThemeMode.dark;
  bool get isRichView => _taskViewMode == TaskViewMode.rich;

  Future<void> initialize() async {
    await _loadSettings();
  }

  Future<void> _loadSettings() async {
    final settings = await _settingsRepo.getSettings();
    _themeMode = settings['themeMode'] == 'dark'
        ? ThemeMode.dark
        : ThemeMode.light;
    _taskViewMode = settings['taskViewMode'] == 'simple'
        ? TaskViewMode.simple
        : TaskViewMode.rich;
    _tutorialCompleted = settings['tutorialCompleted'] == 'true';
    notifyListeners();
  }

  Future<void> _saveSettings() async {
    await _settingsRepo.saveSettings({
      'themeMode': _themeMode == ThemeMode.dark ? 'dark' : 'light',
      'taskViewMode': _taskViewMode == TaskViewMode.simple ? 'simple' : 'rich',
      'tutorialCompleted': _tutorialCompleted ? 'true' : 'false',
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

  void setThemeMode(ThemeMode mode) {
    _themeMode = mode;
    _saveSettings();
    notifyListeners();
  }

  void markTutorialCompleted() {
    _tutorialCompleted = true;
    _saveSettings();
    notifyListeners();
  }

  Future<void> resetSettings() async {
    _themeMode = ThemeMode.light;
    _taskViewMode = TaskViewMode.simple;
    _tutorialCompleted = false;
    await _saveSettings();
    notifyListeners();
  }
}
