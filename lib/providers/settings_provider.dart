
import 'package:flutter/material.dart';
import '../core/services/database_service.dart';

enum TaskViewMode { simple, rich }

class SettingsProvider extends ChangeNotifier {
  final DatabaseService _db = DatabaseService.instance;
  
  ThemeMode _themeMode = ThemeMode.light;
  TaskViewMode _taskViewMode = TaskViewMode.simple;

  ThemeMode get themeMode => _themeMode;
  TaskViewMode get taskViewMode => _taskViewMode;
  
  bool get isDark => _themeMode == ThemeMode.dark;
  bool get isRichView => _taskViewMode == TaskViewMode.rich;

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
  }

  Future<void> _saveSettings() async {
    await _db.saveSettings({
      'themeMode': _themeMode == ThemeMode.dark ? 'dark' : 'light',
      'taskViewMode': _taskViewMode == TaskViewMode.simple ? 'simple' : 'rich',
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
}