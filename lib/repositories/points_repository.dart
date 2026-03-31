
import '../models/user_points.dart';
import '../services/database_service.dart';

class PointsRepository {
  final DatabaseService _db = DatabaseService.instance;

  Future<UserPoints> getUserPoints() async {
    return await _db.getUserPoints();
  }

  Future<void> addPoints(int points) async {
    await _db.addPoints(points);
  }

  Future<void> deductPoints(int points) async {
    await _db.deductPoints(points);
  }

  Future<void> updatePoints(int points) async {
    await _db.updatePoints(points);
  }
}