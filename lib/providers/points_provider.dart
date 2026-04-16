import 'package:flutter/material.dart';
import '../modules/points/models/points_model.dart';
import '../core/services/database_service.dart';

/// 积分状态管理Provider
/// 负责积分的增减和查询
class PointsProvider extends ChangeNotifier {
  final DatabaseService _db = DatabaseService.instance;

  UserPoints _userPoints = UserPoints();

  UserPoints get userPoints => _userPoints;
  int get currentPoints => _userPoints.points;

  Future<void> initialize() async {
    await _loadUserPoints();
  }

  Future<void> _loadUserPoints() async {
    _userPoints = await _db.getUserPoints();
    notifyListeners();
  }

  Future<void> addPoints(int points) async {
    await _db.addPoints(points);
    await _loadUserPoints();
  }

  Future<void> deductPoints(int points) async {
    await _db.deductPoints(points);
    await _loadUserPoints();
  }

  Future<void> updatePoints(int points) async {
    await _db.updateUserPoints(points);
    await _loadUserPoints();
  }
}
