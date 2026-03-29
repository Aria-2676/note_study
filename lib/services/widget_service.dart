import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:home_widget/home_widget.dart';
import '../models/task.dart';

class WidgetService {
  static const String widgetName = 'TaskWidget';
  static const String tasksKey = 'widget_tasks';
  static const String pointsKey = 'widget_points';
  static const String dateKey = 'widget_date';

  static const MethodChannel _channel = MethodChannel('com.noteapp.taskmaster/widget');

  // 初始化小组件
  static Future<void> init() async {
    // 不需要特殊初始化
  }

  // 更新小组件数据
  static Future<void> updateWidgetData({
    required List<Task> tasks,
    required int points,
    required DateTime date,
  }) async {
    try {
      // 准备任务数据
      final taskData = tasks.map((t) => {
        'title': t.title,
        'isOK': t.isOK,
        'rewardPoints': t.rewardPoints,
      }).toList();

      // 使用 home_widget 保存数据
      await HomeWidget.saveWidgetData(tasksKey, jsonEncode(taskData));
      await HomeWidget.saveWidgetData(pointsKey, points.toString());
      await HomeWidget.saveWidgetData(dateKey, 
        '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}');

      // 更新小组件
      await HomeWidget.updateWidget(
        name: widgetName,
        androidName: 'TaskWidgetProvider',
      );
    } catch (e, stackTrace) {
      // 静默处理错误，避免污染日志
    }
  }

  // 从小组件读取数据（用于同步小组件上的修改）
  static Future<Map<String, dynamic>?> readWidgetData() async {
    try {
      String? tasksJson = await HomeWidget.getWidgetData<String>(tasksKey);
      String? pointsStr = await HomeWidget.getWidgetData<String>(pointsKey);
      String? dateStr = await HomeWidget.getWidgetData<String>(dateKey);

      if (tasksJson == null) return null;

      return {
        'tasks': jsonDecode(tasksJson),
        'points': int.tryParse(pointsStr ?? '0') ?? 0,
        'date': dateStr ?? '${DateTime.now().year}-${DateTime.now().month.toString().padLeft(2, '0')}-${DateTime.now().day.toString().padLeft(2, '0')}',
      };
    } catch (e) {
      return null;
    }
  }

  // 注册小组件点击回调
  static void registerClickCallback(Function(Uri?) callback) {
    HomeWidget.widgetClicked.listen(callback);
  }

  // 检查是否已添加小组件（通过原生代码实现）
  static Future<bool> isWidgetAdded() async {
    if (!Platform.isAndroid) return false;
    try {
      final bool result = await _channel.invokeMethod('isWidgetAdded');
      return result;
    } catch (e) {
      return false;
    }
  }

  // 请求添加小组件（跳转到系统小组件选择界面）
  static Future<void> requestAddWidget() async {
    try {
      await HomeWidget.requestPinWidget(
        name: widgetName,
        androidName: 'TaskWidgetProvider',
      );
    } catch (e) {
      // 如果请求失败，尝试打开系统小组件选择界面
      await _openWidgetPicker();
    }
  }

  // 打开系统小组件选择界面
  static Future<void> _openWidgetPicker() async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod('openWidgetPicker');
    } catch (e) {
      // 静默处理
    }
  }
}
