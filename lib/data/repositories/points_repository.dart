import '../../core/services/database_service.dart';

class PointsRepository {
  final DatabaseService _dbService = DatabaseService.instance;

  Future<int> getPoints() async {
    final userPoints = await _dbService.getUserPoints();
    return userPoints.points;
  }

  Future<void> addPoints(int points) async {
    await _dbService.addPoints(points);
  }

  Future<void> deductPoints(int points) async {
    await _dbService.deductPoints(points);
  }

  Future<void> setPoints(int points) async {
    await _dbService.updatePoints(points);
  }
}