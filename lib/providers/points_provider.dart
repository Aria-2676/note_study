import 'package:flutter/material.dart';
import '../models/user_points.dart';
import '../repositories/points_repository.dart';
import '../services/widget_service.dart';

class PointsProvider extends ChangeNotifier {
  final PointsRepository _pointsRepo = PointsRepository();

  UserPoints _userPoints = UserPoints();

  UserPoints get userPoints => _userPoints;
  int get currentPoints => _userPoints.points;

  Future<void> initialize() async {
    await loadUserPoints();
  }

  Future<void> loadUserPoints() async {
    _userPoints = await _pointsRepo.getUserPoints();
    notifyListeners();
  }

  Future<void> addPoints(int points) async {
    await _pointsRepo.addPoints(points);
    await loadUserPoints();
  }

  Future<void> deductPoints(int points) async {
    await _pointsRepo.deductPoints(points);
    await loadUserPoints();
  }

  Future<void> updatePoints(int points) async {
    await _pointsRepo.updatePoints(points);
    await loadUserPoints();
  }

  // 从小组件同步积分数据
  Future<void> syncPointsFromWidget() async {
    try {
      final widgetData = await WidgetService.readWidgetData();
      if (widgetData == null) return;

      final int widgetPoints = widgetData['points'] ?? 0;

      // 同步积分（如果小组件积分与本地不同）
      if (widgetPoints != _userPoints.points) {
        await _pointsRepo.updatePoints(widgetPoints);
        await loadUserPoints();
        print('【积分同步】已从小组件同步积分数据');
      }
    } catch (e) {
      print('【积分同步】同步失败: $e');
    }
  }

  // 更新积分到小组件
  Future<void> updateWidgetPoints() async {
    try {
      await WidgetService.updateWidgetData(
        tasks: [], // 任务由TaskProvider管理
        points: _userPoints.points,
        date: DateTime.now(),
      );
    } catch (e) {
      print('【积分更新】更新小组件失败: $e');
    }
  }
}
