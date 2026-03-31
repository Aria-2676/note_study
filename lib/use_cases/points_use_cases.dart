import '../models/user_points.dart';
import '../repositories/points_repository.dart';

class PointsUseCases {
  final PointsRepository _pointsRepo;

  PointsUseCases(this._pointsRepo);

  // 获取用户积分
  Future<UserPoints> getUserPoints() async {
    return await _pointsRepo.getUserPoints();
  }

  // 添加积分
  Future<void> addPoints(int points) async {
    await _pointsRepo.addPoints(points);
  }

  // 扣除积分
  Future<void> deductPoints(int points) async {
    await _pointsRepo.deductPoints(points);
  }

  // 更新积分
  Future<void> updatePoints(int points) async {
    await _pointsRepo.updatePoints(points);
  }

  // 检查积分是否足够
  Future<bool> hasEnoughPoints(int requiredPoints) async {
    final userPoints = await _pointsRepo.getUserPoints();
    return userPoints.points >= requiredPoints;
  }
}
