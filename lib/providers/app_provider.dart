import 'dart:math';
import 'package:flutter/material.dart';
import '../models/task.dart';
import '../models/shop_item.dart';
import '../models/user_points.dart';
import '../models/purchased_item.dart';
import '../models/recycled_task.dart';
import '../services/database_service.dart';
import '../services/widget_service.dart';

enum TaskViewMode { simple, rich }

class AppProvider extends ChangeNotifier {
  final DatabaseService _db = DatabaseService.instance;

  List<Task> _tasks = [];
  List<ShopItem> _shopItems = [];
  List<PurchasedItem> _purchasedItems = [];
  List<RecycledTask> _recycledTasks = [];
  UserPoints _userPoints = UserPoints();
  DateTime _selectedDate = DateTime.now();
  List<DateTime> _selectedDates = [DateTime.now()];
  bool _multiTaskMode = false;
  int _currentTab = 0;
  ThemeMode _themeMode = ThemeMode.light;
  TaskViewMode _taskViewMode = TaskViewMode.simple;

  List<Task> get tasks => _tasks;
  List<ShopItem> get shopItems => _shopItems;
  List<PurchasedItem> get purchasedItems => _purchasedItems;
  List<RecycledTask> get recycledTasks => _recycledTasks;
  UserPoints get userPoints => _userPoints;
  int get currentPoints => _userPoints.points;
  DateTime get selectedDate => _selectedDate;
  List<DateTime> get selectedDates => _selectedDates;
  bool get multiTaskMode => _multiTaskMode;
  int get currentTab => _currentTab;
  ThemeMode get themeMode => _themeMode;
  TaskViewMode get taskViewMode => _taskViewMode;

  bool get isDark => _themeMode == ThemeMode.dark;
  bool get isRichView => _taskViewMode == TaskViewMode.rich;

  Future<void> initialize() async {
    await WidgetService.init();
    await _loadSettings(); // 加载设置
    await _loadUserPoints();
    await _loadShopItems();
    await _loadPurchasedItems();
    await _loadRecycledTasks();
    await _initDefaultData(); // 初始化示例数据和固定商品
    await autoCheckRecurringTasks();
    await _checkOverdueTasks();
    await loadTasksByDate(DateTime.now());
    await _updateWidget();
  }

  // 从小组件同步数据（当用户在小组件上完成任务时调用）
  Future<void> syncFromWidget() async {
    try {
      final widgetData = await WidgetService.readWidgetData();
      if (widgetData == null) return;

      final List<dynamic> widgetTasks = widgetData['tasks'] ?? [];
      final int widgetPoints = widgetData['points'] ?? 0;

      // 检查任务状态是否有变化
      bool hasChanges = false;
      for (int i = 0; i < widgetTasks.length && i < _tasks.length; i++) {
        final widgetTask = widgetTasks[i];
        final localTask = _tasks[i];
        final bool widgetIsOK = widgetTask['isOK'] ?? false;

        // 如果小组件中的任务状态与本地不同，更新本地数据库
        if (widgetIsOK != localTask.isOK) {
          if (widgetIsOK) {
            // 在小组件上标记完成
            await _db.completeTask(localTask.id!);
            if (localTask.rewardPoints > 0) {
              await _db.addPoints(localTask.rewardPoints);
            }
          } else {
            // 在小组件上取消完成
            await _db.uncompleteTask(localTask.id!);
            if (localTask.rewardPoints > 0) {
              await _db.deductPoints(localTask.rewardPoints);
            }
          }
          hasChanges = true;
        }
      }

      // 同步积分（如果小组件积分与本地不同）
      if (widgetPoints != _userPoints.points) {
        await _db.updatePoints(widgetPoints);
        hasChanges = true;
      }

      // 如果有变化，重新加载数据
      if (hasChanges) {
        await _loadUserPoints();
        await loadTasksByDate(_selectedDate);
        print('【小组件同步】已从小组件同步数据');
      }
    } catch (e) {
      print('【小组件同步】同步失败: $e');
    }
  }

  // 加载设置
  Future<void> _loadSettings() async {
    final settings = await _db.getSettings();
    _themeMode = settings['themeMode'] == 'dark'
        ? ThemeMode.dark
        : ThemeMode.light;
    _taskViewMode = settings['taskViewMode'] == 'simple'
        ? TaskViewMode.simple
        : TaskViewMode.rich;
  }

  // 保存设置
  Future<void> _saveSettings() async {
    await _db.saveSettings({
      'themeMode': _themeMode == ThemeMode.dark ? 'dark' : 'light',
      'taskViewMode': _taskViewMode == TaskViewMode.simple ? 'simple' : 'rich',
    });
  }

  // 更新桌面小组件
  Future<void> _updateWidget() async {
    await WidgetService.updateWidgetData(
      tasks: _tasks,
      points: _userPoints.points,
      date: _selectedDate,
    );
  }

  // 初始化默认数据（示例任务和固定商品）
  Future<void> _initDefaultData() async {
    // 检查是否需要初始化固定商品
    final existingItems = await _db.getAllShopItems();
    if (existingItems.isEmpty) {
      await _initDefaultShopItems();
    }

    // 检查是否需要添加引导任务
    await _initTutorialTasks();
  }

  // 初始化引导任务（首次使用）
  Future<void> _initTutorialTasks() async {
    // 检查是否已经完成过引导
    final settings = await _db.getSettings();
    if (settings['tutorialCompleted'] == 'true') return;

    // 检查是否已存在任务
    final todayTasks = await _db.getTasksByDate(DateTime.now());
    if (todayTasks.isNotEmpty) return;

    // 添加引导任务
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

    for (final task in tutorialTasks) {
      await _db.createTask(task);
    }

    // 立即标记引导已完成，防止重复添加
    await _db.saveSettings({...settings, 'tutorialCompleted': 'true'});
  }

  // 初始化固定商城商品
  Future<void> _initDefaultShopItems() async {
    final defaultItems = [
      ShopItem(
        name: '休息15分钟',
        description: '兑换后可以休息15分钟，放松身心',
        price: 50,
        iconName: 'local_cafe',
        colorValue: 0xFF795548, // 棕色
      ),
      ShopItem(
        name: '看一集动漫',
        description: '奖励自己看一集喜欢的动漫',
        price: 100,
        iconName: 'movie',
        colorValue: 0xFFE91E63, // 粉色
      ),
      ShopItem(
        name: '吃一块蛋糕',
        description: '兑换一块美味的蛋糕奖励自己',
        price: 80,
        iconName: 'cake',
        colorValue: 0xFFFF9800, // 橙色
      ),
      ShopItem(
        name: '玩游戏30分钟',
        description: '兑换30分钟游戏时间',
        price: 120,
        iconName: 'sports_esports',
        colorValue: 0xFF9C27B0, // 紫色
      ),
      ShopItem(
        name: '买一本书',
        description: '兑换购买一本心仪的书籍',
        price: 200,
        iconName: 'book',
        colorValue: 0xFF4CAF50, // 绿色
      ),
      ShopItem(
        name: '周末旅行',
        description: '兑换一次周末短途旅行',
        price: 500,
        iconName: 'flight',
        colorValue: 0xFF2196F3, // 蓝色
      ),
      ShopItem(
        name: '买新装备',
        description: '兑换购买新的电子设备或配件',
        price: 300,
        iconName: 'laptop',
        colorValue: 0xFF607D8B, // 蓝灰
      ),
      ShopItem(
        name: 'SPA放松',
        description: '兑换一次SPA按摩放松',
        price: 400,
        iconName: 'spa',
        colorValue: 0xFF00BCD4, // 青色
      ),
    ];

    for (final item in defaultItems) {
      await _db.createShopItem(item);
    }
    await _loadShopItems();
  }

  Future<void> _loadUserPoints() async {
    _userPoints = await _db.getUserPoints();
    notifyListeners();
  }

  Future<void> _loadShopItems() async {
    _shopItems = await _db.getAllShopItems();
    notifyListeners();
  }

  Future<void> _loadPurchasedItems() async {
    _purchasedItems = await _db.getAllPurchasedItems();
    notifyListeners();
  }

  Future<void> _loadRecycledTasks() async {
    _recycledTasks = await _db.getRecycledTasks();
    notifyListeners();
  }

  Future<void> loadRecycledTasks() async {
    await _loadRecycledTasks();
  }

  Future<void> restoreTaskFromRecycle(int recycledTaskId) async {
    // 获取回收站任务信息（用于获取原始cplTime）
    final recycledTasks = await _db.getRecycledTasks();
    final recycledTask = recycledTasks.firstWhere(
      (t) => t.id == recycledTaskId,
    );
    final originalCplTime = recycledTask.task.cplTime;

    // 恢复任务（使用原始cplTime）
    final restoredTask = await _db.restoreTaskFromRecycle(recycledTaskId);

    // 如果是循环任务，从原始日期开始重新生成循环实例
    if (restoredTask.recurrence != 'none') {
      // 使用原始cplTime创建任务模板，用于生成循环实例
      final taskTemplate = restoredTask.copyWith(cplTime: originalCplTime);
      await _generateTaskRange(taskTemplate);
    }

    await _loadRecycledTasks();
    await loadTasksByDate(_selectedDate);
  }

  Future<void> deleteFromRecycle(int recycledTaskId) async {
    await _db.deleteFromRecycle(recycledTaskId);
    await _loadRecycledTasks();
  }

  Future<void> clearRecycleBin() async {
    await _db.clearRecycleBin();
    await _loadRecycledTasks();
  }

  Future<void> _checkOverdueTasks() async {
    final overdueTasks = await _db.getOverdueTasks(DateTime.now());
    for (final task in overdueTasks) {
      if (task.rewardPoints > 0 && !task.isDeducted) {
        final deductPoints = (task.rewardPoints / 2).floor();
        if (deductPoints > 0) {
          await _db.deductPoints(deductPoints);
          await _db.markTaskDeducted(task.id!);
        }
      }
    }
    await _loadUserPoints();
  }

  Future<void> loadTasksByDate(DateTime date) async {
    _selectedDate = date;
    _tasks = await _db.getTasksByDate(date);
    notifyListeners();
    await _updateWidget();
  }

  Future<void> loadTodayTasks() async {
    await loadTasksByDate(DateTime.now());
  }

  Future<void> addTask(Task task) async {
    // 为循环任务生成唯一的 loopId
    if (task.recurrence != 'none' && task.loopId == null) {
      final newTask = task.copyWith(loopId: _generateLoopId());
      await _insertTaskIfNotExists(newTask);
      await _generateTaskRange(newTask);
    } else {
      await _insertTaskIfNotExists(task);
      if (task.recurrence != 'none') {
        await _generateTaskRange(task);
      }
    }
    await loadTasksByDate(_selectedDate);
  }

  Future<void> _insertTaskIfNotExists(Task task) async {
    // 对于循环任务，使用 loopId 和日期来检查任务是否存在
    // 这样即使任务名称改变，也不会创建新的循环任务实例
    bool exists;
    if (task.recurrence != 'none' && task.loopId != null) {
      final allTasks = await _db.getAllTasks();
      exists = allTasks.any((t) {
        return t.loopId == task.loopId && _sameDay(t.cplTime, task.cplTime);
      });
    } else {
      // 对于非循环任务，使用传统的检查方式
      exists = await _db.existsTaskOnDate(
        task.title,
        task.description,
        task.cplTime,
      );
    }
    if (!exists) {
      await _db.createTask(task);
    }
  }

  // 生成唯一的循环任务标识符
  String _generateLoopId() {
    return 'loop_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(10000)}';
  }

  Future<void> _generateTaskRange(Task task) async {
    final now = DateTime.now();
    final rangeEnd = now.add(const Duration(days: 15));

    // 使用任务的原始日期作为起始点
    var next = DateTime(
      task.cplTime.year,
      task.cplTime.month,
      task.cplTime.day,
    );

    while (!next.isAfter(rangeEnd)) {
      if (task.recurrence == 'daily') {
        await _insertTaskIfNotExists(
          task.copyWith(
            id: null, // 清除id，让数据库自动生成
            cplTime: next,
            isOK: false,
            completedAt: null,
            isDeducted: false,
          ),
        );
        next = next.add(const Duration(days: 1));
        continue;
      }
      if (task.recurrence == 'weekly') {
        // 找到下一个与原任务相同星期几的日期
        while (next.weekday != task.cplTime.weekday) {
          next = next.add(const Duration(days: 1));
        }
        // 如果已经超出范围，直接退出
        if (next.isAfter(rangeEnd)) {
          break;
        }
        await _insertTaskIfNotExists(
          task.copyWith(
            id: null, // 清除id，让数据库自动生成
            cplTime: next,
            isOK: false,
            completedAt: null,
            isDeducted: false,
          ),
        );
        next = next.add(const Duration(days: 7));
        continue;
      }
      if (task.recurrence == 'monthly') {
        // 确保日期不超过月份的最大天数
        int day = task.cplTime.day;
        int daysInMonth = DateTime(next.year, next.month + 1, 0).day;
        day = day > daysInMonth ? daysInMonth : day;
        var monthlyDate = DateTime(next.year, next.month, day);

        if (!monthlyDate.isAfter(rangeEnd)) {
          await _insertTaskIfNotExists(
            task.copyWith(
              id: null, // 清除id，让数据库自动生成
              cplTime: monthlyDate,
              isOK: false,
              completedAt: null,
              isDeducted: false,
            ),
          );
        }

        // 处理月循环的日期边界问题
        int nextMonth = next.month + 1;
        int nextYear = next.year;
        if (nextMonth > 12) {
          nextMonth = 1;
          nextYear++;
        }
        next = DateTime(nextYear, nextMonth, 1);
        continue;
      }
      break;
    }
  }

  Future<void> autoCheckRecurringTasks() async {
    final recurringTasks = await _db.getRecurringTasks();
    final futures = <Future>[];
    final uniquePatterns = <String, Task>{};

    for (var task in recurringTasks) {
      // 使用 loopId 来识别唯一的循环任务模式
      // 如果没有 loopId，则使用传统的属性组合
      final key =
          task.loopId ??
          '${task.title}||${task.description}||${task.recurrence}||${task.isWord}||${task.rewardPoints}';
      if (!uniquePatterns.containsKey(key) ||
          uniquePatterns[key]!.cplTime.isAfter(task.cplTime)) {
        uniquePatterns[key] = task;
      }
    }

    for (var task in uniquePatterns.values) {
      futures.add(_generateTaskRange(task));
    }
    await Future.wait(futures);
  }

  Future<String?> completeTask(Task task) async {
    final now = DateTime.now();
    if (!_sameDay(task.cplTime, now)) {
      return '当前日期不是任务日期，不能完成任务';
    }
    await _db.completeTask(task.id!);

    // 添加积分奖励
    if (task.rewardPoints > 0) {
      await _db.addPoints(task.rewardPoints);
      await _loadUserPoints();
    }

    await loadTasksByDate(_selectedDate);
    return null;
  }

  Future<void> uncompleteTask(Task task) async {
    await _db.uncompleteTask(task.id!);

    // 如果任务有奖励积分，取消完成时扣除相应积分（防止刷分）
    if (task.rewardPoints > 0) {
      await _db.deductPoints(task.rewardPoints);
      await _loadUserPoints();
    }

    await loadTasksByDate(_selectedDate);
  }

  Future<void> deleteTask(int id, {bool deleteAll = false}) async {
    final task = _tasks.firstWhere((t) => t.id == id);

    if (deleteAll && task.recurrence != 'none' && task.loopId != null) {
      // 删除循环任务：使用 loopId 查找所有相关的循环任务实例
      final allTasks = await _db.getAllTasks();

      // 找到需要删除的所有任务（相同 loopId 且日期 >= 当前任务日期）
      final tasksToDelete = allTasks.where((t) {
        return t.loopId == task.loopId &&
            !_isDateBefore(t.cplTime, task.cplTime); // 日期 >= 当前任务日期
      }).toList();

      // 保存到回收站（使用最早的日期作为基准）
      final earliestTask = tasksToDelete.reduce(
        (a, b) => a.cplTime.isBefore(b.cplTime) ? a : b,
      );

      // 保存到回收站（只保存一次）
      await _db.deleteTask(earliestTask.id!);

      // 删除其他实例（不保存到回收站）
      for (final t in tasksToDelete) {
        if (t.id != earliestTask.id) {
          await _db.deleteTaskWithoutRecycle(t.id!);
        }
      }
    } else {
      // 只删除当前任务
      await _db.deleteTask(id);
    }

    await loadTasksByDate(_selectedDate);
    await _updateWidget();
  }

  Future<void> updateTask(Task task, {bool updateAll = false}) async {
    // 更新当前任务
    await _db.updateTask(task);

    if (task.recurrence != 'none' && updateAll && task.loopId != null) {
      // 批量更新所有相关的循环任务
      final allTasks = await _db.getAllTasks();

      // 使用 loopId 来查找所有相关的循环任务实例，并且日期 >= 当前任务日期
      final tasksToUpdate = allTasks.where((t) {
        return t.loopId == task.loopId &&
            t.id != task.id && // 排除当前任务，因为已经更新过了
            !_isDateBefore(t.cplTime, task.cplTime); // 日期 >= 当前任务日期
      }).toList();

      // 更新所有相关的循环任务
      for (final t in tasksToUpdate) {
        final updatedTask = t.copyWith(
          id: t.id, // 确保传递任务ID
          title: task.title,
          description: task.description,
          isWord: task.isWord,
          rewardPoints: task.rewardPoints,
          priority: task.priority,
          recurrence: task.recurrence,
        );
        await _db.updateTask(updatedTask);
      }
    }

    // 无论是否更新全部，都生成未来的循环实例
    // 这样可以确保即使修改了任务属性，未来的循环实例也能保持一致
    if (task.recurrence != 'none') {
      await _generateTaskRange(task);
    }

    // 重新加载当前日期的任务，确保UI更新
    await loadTasksByDate(_selectedDate);
    // 强制通知监听器，确保UI更新
    notifyListeners();
    await _updateWidget();
  }

  void selectDate(DateTime date) {
    _selectedDate = date;
    if (!_selectedDates.any((d) => _sameDay(d, date))) {
      _selectedDates = [date];
    }
    loadTasksByDate(date);
  }

  void toggleSelectedDate(DateTime date) {
    final idx = _selectedDates.indexWhere((d) => _sameDay(d, date));
    if (idx >= 0) {
      if (_selectedDates.length > 1) {
        _selectedDates.removeAt(idx);
      }
    } else {
      _selectedDates.add(date);
    }
    notifyListeners();
  }

  void setMultiTaskMode(bool value) {
    _multiTaskMode = value;
    if (!value) {
      _selectedDates = [_selectedDate];
    }
    notifyListeners();
  }

  void setCurrentTab(int index) {
    _currentTab = index;
    notifyListeners();
  }

  void toggleTheme() {
    _themeMode = _themeMode == ThemeMode.light
        ? ThemeMode.dark
        : ThemeMode.light;
    _saveSettings(); // 保存设置
    notifyListeners();
  }

  void setTaskViewMode(TaskViewMode mode) {
    _taskViewMode = mode;
    _saveSettings(); // 保存设置
    notifyListeners();
  }

  void toggleTaskViewMode() {
    _taskViewMode = _taskViewMode == TaskViewMode.rich
        ? TaskViewMode.simple
        : TaskViewMode.rich;
    _saveSettings(); // 保存设置
    notifyListeners();
  }

  // ========== Shop Item Methods ==========

  Future<void> addShopItem(ShopItem item) async {
    await _db.createShopItem(item);
    await _loadShopItems();
  }

  Future<void> updateShopItem(ShopItem item) async {
    await _db.updateShopItem(item);
    await _loadShopItems();
  }

  Future<void> deleteShopItem(int id) async {
    await _db.deleteShopItem(id);
    await _loadShopItems();
  }

  Future<String?> purchaseItem(ShopItem item) async {
    if (_userPoints.points < item.price) {
      return '积分不足，无法兑换';
    }
    await _db.deductPoints(item.price);

    // 添加到仓库，包含外观信息
    final purchasedItem = PurchasedItem(
      shopItemId: item.id!,
      name: item.name,
      description: item.description,
      price: item.price,
      iconName: item.iconName,
      colorValue: item.colorValue,
    );
    await _db.addPurchasedItem(purchasedItem);
    await _loadPurchasedItems();
    await _loadUserPoints();
    return null;
  }

  Future<void> deletePurchasedItem(int id) async {
    await _db.deletePurchasedItem(id);
    await _loadPurchasedItems();
  }

  // ========== Points Methods ==========

  Future<void> addPoints(int points) async {
    await _db.addPoints(points);
    await _loadUserPoints();
  }

  Future<void> deductPoints(int points) async {
    await _db.deductPoints(points);
    await _loadUserPoints();
  }

  Future<void> clearAllData() async {
    await _db.clearAllData();
    await initialize();
  }

  DateTime maxDate(DateTime a, DateTime b) {
    if (a.isAfter(b)) return a;
    return b;
  }

  bool _sameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  // 检查日期a是否在日期b之前（只比较年月日）
  bool _isDateBefore(DateTime a, DateTime b) {
    final dateA = DateTime(a.year, a.month, a.day);
    final dateB = DateTime(b.year, b.month, b.day);
    return dateA.isBefore(dateB);
  }
}
