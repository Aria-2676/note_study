import 'dart:convert';
import 'package:home_widget/home_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';

class WidgetService {
  static const String widgetName = 'TaskWidget';
  static const String tasksKey = 'widget_tasks';
  static const String pointsKey = 'widget_points';
  static const String dateKey = 'widget_date';
  static const String widgetAddedKey = 'widget_added_flag';

  static Future<void> init() async {
    // 初始化时不再设置静态数据，让 TaskProvider 管理动态数据
  }

  static Future<Map<String, dynamic>?> readWidgetData() async {
    try {
      String? tasksJson = await HomeWidget.getWidgetData<String>(tasksKey);
      String? pointsStr = await HomeWidget.getWidgetData<String>(pointsKey);
      String? dateStr = await HomeWidget.getWidgetData<String>(dateKey);

      if (tasksJson == null) return null;

      // 标记小组件已添加
      await _setWidgetAdded(true);

      return {
        'tasks': jsonDecode(tasksJson),
        'points': int.tryParse(pointsStr ?? '0') ?? 0,
        'date':
            dateStr ??
            '${DateTime.now().year}-${DateTime.now().month.toString().padLeft(2, '0')}-${DateTime.now().day.toString().padLeft(2, '0')}',
      };
    } catch (e) {
      return null;
    }
  }

  static Future<bool> isWidgetAdded() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(widgetAddedKey) ?? false;
  }

  static Future<void> _setWidgetAdded(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(widgetAddedKey, value);
  }

  static Future<void> requestAddWidget() async {
    try {
      await HomeWidget.requestPinWidget(
        name: widgetName,
        androidName: 'TaskWidgetProvider',
      );
      // 请求添加后标记为已添加
      await _setWidgetAdded(true);
    } catch (_) {
      // Widget request failed, ignore
    }
  }
}
