import 'package:flutter/material.dart';
import './task_provider.dart';
import './points_provider.dart';
import './shop_provider.dart';
import './settings_provider.dart';
import '../repositories/settings_repository.dart';
import '../services/database_service.dart';
import '../services/widget_service.dart';
import '../models/task.dart';
import '../models/shop_item.dart';

class AppProvider extends ChangeNotifier {
  // 子Provider实例
  late final TaskProvider task;
  late final PointsProvider points;
  late final ShopProvider shop;
  late final SettingsProvider settings;

  AppProvider() {
    task = TaskProvider();
    points = PointsProvider();
    shop = ShopProvider();
    settings = SettingsProvider();

    // 监听子Provider的变化，并转发通知
    task.addListener(_onSubProviderChanged);
    points.addListener(_onSubProviderChanged);
    shop.addListener(_onSubProviderChanged);
    settings.addListener(_onSubProviderChanged);
  }

  void _onSubProviderChanged() {
    notifyListeners();
  }

  // 页面状态
  int _currentTab = 0;

  // 页面状态 getter
  int get currentTab => _currentTab;

  // 便捷访问
  int get currentPoints => points.currentPoints;
  DateTime get selectedDate => task.selectedDate;
  ThemeMode get themeMode => settings.themeMode;

  Future<void> initialize() async {
    await WidgetService.init();

    // 初始化所有子Provider
    await Future.wait([
      task.initialize(),
      points.initialize(),
      shop.initialize(),
      settings.initialize(),
    ]);

    // 初始化引导任务
    await _initTutorialTasks();

    // 更新小组件
    await _updateWidget();
  }

  // 从小组件同步数据
  Future<void> syncFromWidget() async {
    try {
      final widgetData = await WidgetService.readWidgetData();
      if (widgetData == null) return;

      final List<dynamic> widgetTasks = widgetData['tasks'] ?? [];
      final int widgetPoints = widgetData['points'] ?? 0;

      // 同步任务数据
      bool hasTaskChanges = false;
      for (int i = 0; i < widgetTasks.length && i < task.tasks.length; i++) {
        final widgetTask = widgetTasks[i];
        final localTask = task.tasks[i];
        final bool widgetIsOK = widgetTask['isOK'] ?? false;

        if (widgetIsOK != localTask.isOK) {
          if (widgetIsOK) {
            await task.completeTask(localTask);
            if (localTask.rewardPoints > 0) {
              await points.addPoints(localTask.rewardPoints);
            }
          } else {
            await task.uncompleteTask(localTask);
            if (localTask.rewardPoints > 0) {
              await points.deductPoints(localTask.rewardPoints);
            }
          }
          hasTaskChanges = true;
        }
      }

      // 同步积分数据
      if (widgetPoints != points.currentPoints) {
        await points.updatePoints(widgetPoints);
        hasTaskChanges = true;
      }

      if (hasTaskChanges) {
        await task.loadTasksByDate(task.selectedDate);
        print('【小组件同步】已从小组件同步数据');
      }
    } catch (e) {
      print('【小组件同步】同步失败: $e');
    }
  }

  // 初始化引导任务
  Future<void> _initTutorialTasks() async {
    final todayTasks = await task.getTasksByDate(DateTime.now());
    if (todayTasks.isNotEmpty) return;

    if (settings.tutorialCompleted) return;

    final tutorialTasks = [
      Task(
        title: '👋 欢迎使用任务管家',
        description: '点击左侧复选框完成这个任务，获得你的第一笔积分！',
        cplTime: DateTime.now(),
        recurrence: 'none',
        isWord: false,
        isOK: false,
        rewardPoints: 10,
      ),
      Task(
        title: '📝 创建你的第一个任务',
        description: '点击右下角的 + 按钮，创建属于你自己的任务',
        cplTime: DateTime.now(),
        recurrence: 'none',
        isWord: false,
        isOK: false,
        rewardPoints: 20,
      ),
      Task(
        title: '🏪 探索积分商城',
        description: '在"我的"页面找到积分商城，用积分兑换奖励',
        cplTime: DateTime.now(),
        recurrence: 'none',
        isWord: false,
        isOK: false,
        rewardPoints: 15,
      ),
      Task(
        title: '📅 尝试切换日期',
        description: '在首页左右滑动日历，查看不同日期的任务',
        cplTime: DateTime.now(),
        recurrence: 'none',
        isWord: false,
        isOK: false,
        rewardPoints: 10,
      ),
      Task(
        title: '🎨 切换任务视图',
        description: '在"我的"页面切换列表/卡片视图，找到你喜欢的展示方式',
        cplTime: DateTime.now(),
        recurrence: 'none',
        isWord: false,
        isOK: false,
        rewardPoints: 10,
      ),
      Task(
        title: '📱 添加桌面小组件',
        description: '在设置中查看小组件指南，把任务添加到桌面',
        cplTime: DateTime.now(),
        recurrence: 'none',
        isWord: false,
        isOK: false,
        rewardPoints: 25,
      ),
    ];

    for (final tutorialTask in tutorialTasks) {
      await task.addTask(tutorialTask);
    }
  }

  // 更新桌面小组件
  Future<void> _updateWidget() async {
    try {
      await WidgetService.updateWidgetData(
        tasks: task.tasks,
        points: points.currentPoints,
        date: task.selectedDate,
      );
    } catch (e) {
      print('【小组件更新】更新失败: $e');
    }
  }

  // 购买商品
  Future<String?> purchaseItem(ShopItem item) async {
    final result = await shop.purchaseItem(item, points.currentPoints);
    if (result == null) {
      await points.loadUserPoints();
    }
    return result;
  }

  // 页面状态管理
  void setCurrentTab(int index) {
    _currentTab = index;
    notifyListeners();
  }

  // 主题管理
  void toggleTheme() {
    settings.toggleTheme();
    notifyListeners();
  }

  void setThemeMode(ThemeMode mode) {
    settings.setThemeMode(mode);
    notifyListeners();
  }

  // 任务视图模式管理
  void setTaskViewMode(TaskViewMode mode) {
    settings.setTaskViewMode(mode);
    notifyListeners();
  }

  void toggleTaskViewMode() {
    settings.toggleTaskViewMode();
    notifyListeners();
  }

  // 清除所有数据
  Future<void> clearAllData() async {
    await SettingsRepository().clearAllData();
    await initialize();
  }

  // 手动触发通知所有监听器
  void notifyAll() {
    notifyListeners();
  }

  @override
  void dispose() {
    // 移除所有子Provider的监听器，避免内存泄漏
    task.removeListener(_onSubProviderChanged);
    points.removeListener(_onSubProviderChanged);
    shop.removeListener(_onSubProviderChanged);
    settings.removeListener(_onSubProviderChanged);
    super.dispose();
  }
}
