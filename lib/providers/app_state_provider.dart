import 'package:flutter/material.dart';

/// 应用全局状态Provider
/// 管理应用级别的状态信息
class AppStateProvider extends ChangeNotifier {
  int _currentTab = 0;

  int get currentTab => _currentTab;

  void setCurrentTab(int index) {
    _currentTab = index;
    notifyListeners();
  }
}
