import 'package:flutter/material.dart';
import '../modules/points/models/points_model.dart';
import '../core/services/database/database_service.dart';

class PointsProvider extends ChangeNotifier {
  final DatabaseService _db = DatabaseService.instance;

  UserPoints _userPoints = UserPoints();
  List<PointsRecord> _records = [];

  UserPoints get userPoints => _userPoints;
  int get currentPoints => _userPoints.points;
  List<PointsRecord> get records => _records;

  Future<void> initialize() async {
    await _loadUserPoints();
    await _loadRecords();
  }

  Future<void> _loadUserPoints() async {
    _userPoints = await _db.getUserPoints();
    notifyListeners();
  }

  Future<void> _loadRecords() async {
    _records = await _db.getPointsRecords(limit: 50);
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

  /// 加分并写入积分记录。
  ///
  /// 积分变更与流水写入在同一个事务内完成，避免中途失败导致两者不一致。
  Future<void> addPointsWithRecord({
    required int points,
    required String type,
    required String description,
    int? relatedId,
  }) async {
    await _db.applyPointsChange(
      delta: points,
      record: PointsRecord(
        points: points,
        type: type,
        description: description,
        relatedId: relatedId,
      ),
    );
    await _loadUserPoints();
    await _loadRecords();
  }

  /// 扣分并写入积分记录（与积分变更同事务）。
  Future<void> deductPointsWithRecord({
    required int points,
    required String type,
    required String description,
    int? relatedId,
  }) async {
    await _db.applyPointsChange(
      delta: -points,
      record: PointsRecord(
        points: -points,
        type: type,
        description: description,
        relatedId: relatedId,
      ),
    );
    await _loadUserPoints();
    await _loadRecords();
  }

  Future<bool> hasRecordForTypeAndRelatedId(String type, int relatedId) async {
    return await _db.hasPointsRecordByTypeAndRelatedId(type, relatedId);
  }

  /// 取某个关联对象上、指定类型中最后写入的一条积分记录。
  ///
  /// 用于判断关联对象（如任务）当前的积分结算状态：最后一条是加分记录
  /// 表示「已加分未冲销」，是扣分记录则表示「已冲销」。
  Future<PointsRecord?> getLatestRecord(
    int relatedId,
    List<String> types,
  ) async {
    return await _db.getLatestPointsRecord(relatedId, types);
  }

  /// 从数据库重新加载积分与流水。
  ///
  /// 供外部事务已直接改动积分（如商城原子兑换）后刷新 Provider 状态使用。
  Future<void> reload() async {
    await _loadUserPoints();
    await _loadRecords();
  }

  Future<void> refreshRecords() async {
    await _loadRecords();
  }
}
