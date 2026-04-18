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

  Future<void> addPointsWithRecord({
    required int points,
    required String type,
    required String description,
    int? relatedId,
  }) async {
    await _db.addPoints(points);
    await _db.addPointsRecord(
      PointsRecord(
        points: points,
        type: type,
        description: description,
        relatedId: relatedId,
      ),
    );
    await _loadUserPoints();
    await _loadRecords();
  }

  Future<void> deductPointsWithRecord({
    required int points,
    required String type,
    required String description,
    int? relatedId,
  }) async {
    await _db.deductPoints(points);
    await _db.addPointsRecord(
      PointsRecord(
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

  Future<void> refreshRecords() async {
    await _loadRecords();
  }
}
