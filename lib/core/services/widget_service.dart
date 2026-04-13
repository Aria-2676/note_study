import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:home_widget/home_widget.dart';
import '../../data/models/task/task_model.dart';

class WidgetService {
  static const String widgetName = 'TaskWidget';
  static const String tasksKey = 'widget_tasks';
  static const String pointsKey = 'widget_points';
  static const String dateKey = 'widget_date';

  static const MethodChannel _channel = MethodChannel('com.noteapp.taskmaster/widget');

  static Future<void> init() async {
  }

  static Future<void> updateWidgetData({
    required List<Task> tasks,
    required int points,
    required DateTime date,
  }) async {
    try {
      final taskData = tasks.map((t) => {
        'title': t.title,
        'isOK': t.isOK,
        'rewardPoints': t.rewardPoints,
      }).toList();

      await HomeWidget.saveWidgetData(tasksKey, jsonEncode(taskData));
      await HomeWidget.saveWidgetData(pointsKey, points.toString());
      await HomeWidget.saveWidgetData(dateKey, 
        '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}');

      await HomeWidget.updateWidget(
        name: widgetName,
        androidName: 'TaskWidgetProvider',
      );
    } catch (_) {
      // Widget update failed, ignore
    }
  }

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

  static void registerClickCallback(Function(Uri?) callback) {
    HomeWidget.widgetClicked.listen(callback);
  }

  static Future<bool> isWidgetAdded() async {
    if (!Platform.isAndroid) return false;
    try {
      final bool result = await _channel.invokeMethod('isWidgetAdded');
      return result;
    } catch (e) {
      return false;
    }
  }

  static Future<void> requestAddWidget() async {
    try {
      await HomeWidget.requestPinWidget(
        name: widgetName,
        androidName: 'TaskWidgetProvider',
      );
    } catch (e) {
      await _openWidgetPicker();
    }
  }

  static Future<void> _openWidgetPicker() async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod('openWidgetPicker');
    } catch (_) {
      // Widget picker not available, ignore
    }
  }
}