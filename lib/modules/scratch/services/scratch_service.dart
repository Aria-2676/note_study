import 'dart:math';
import '../models/scratch_model.dart';
import '../repositories/scratch_repository.dart';

class ScratchService {
  final ScratchRepository _repository;

  ScratchService({ScratchRepository? repository})
    : _repository = repository ?? ScratchRepository();

  static const int maxPrizeValueMultiplier = 10;

  Future<List<PrizeItem>> getCustomPrizePool() async {
    return await _repository.getCustomPrizePool();
  }

  Future<void> saveCustomPrizePool(List<PrizeItem> items) async {
    await _repository.saveCustomPrizePool(items);
  }

  Future<void> clearCustomPrizePool() async {
    await _repository.clearCustomPrizePool();
  }

  Future<List<LotteryRecord>> getLotteryHistory() async {
    final records = await _repository.getLotteryRecords();
    records.sort((a, b) => b.drawTime.compareTo(a.drawTime));
    return records;
  }

  Future<int> saveLotteryResult(
    PrizeItem prize,
    int costPoints, {
    int? existingRecordId,
  }) async {
    final record = LotteryRecord(
      id: existingRecordId,
      drawTime: DateTime.now(),
      prizeName: prize.name,
      prizeType: prize.type,
      prizeValue: prize.value,
      costPoints: costPoints,
    );

    if (existingRecordId != null) {
      await _repository.updateLotteryRecord(record);
      return existingRecordId;
    } else {
      return await _repository.insertLotteryRecord(record);
    }
  }

  Future<int> deleteLotteryRecord(int id) async {
    return await _repository.deleteLotteryRecord(id);
  }

  Future<int> clearLotteryHistory() async {
    return await _repository.deleteAllLotteryRecords();
  }

  PrizeItem drawPrize(
    List<PrizeItem> defaultPool,
    List<PrizeItem> customPool,
    int cost,
  ) {
    final allPrizes = [...defaultPool, ...customPool];
    final maxAllowedValue = cost * maxPrizeValueMultiplier;
    final prizes = allPrizes.where((p) => p.value <= maxAllowedValue).toList();

    if (prizes.isEmpty) {
      throw Exception('奖品池为空');
    }

    final probabilities = _calculateProbabilities(prizes, cost);

    final random = Random.secure();
    final randomValue = random.nextDouble();

    double cumulative = 0;
    for (final entry in probabilities.entries) {
      cumulative += entry.value;
      if (randomValue <= cumulative) {
        return entry.key;
      }
    }

    return probabilities.keys.last;
  }

  Map<PrizeItem, double> _calculateProbabilities(
    List<PrizeItem> prizes,
    int cost,
  ) {
    if (prizes.isEmpty) return {};

    final weights = <PrizeItem, double>{};
    for (final prize in prizes) {
      weights[prize] = 1.0 / prize.value.toDouble();
    }

    final totalWeight = weights.values.fold(0.0, (sum, w) => sum + w);

    final result = <PrizeItem, double>{};
    for (final entry in weights.entries) {
      result[entry.key] = entry.value / totalWeight;
    }

    return result;
  }

  bool validatePoints(int userPoints, int cost) {
    return userPoints >= cost && cost > 0;
  }

  bool validatePrizePool(List<PrizeItem> pool) {
    if (pool.isEmpty) return false;
    return pool.every(
      (p) =>
          p.name.isNotEmpty &&
          p.value >= 0 &&
          (p.type == 'integral' || p.type == 'goods'),
    );
  }
}
