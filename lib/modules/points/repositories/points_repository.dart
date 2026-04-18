import '../../../core/services/database/database_service.dart';
/// 积分数据仓储
/// 负责积分数据的增删改查操作
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
