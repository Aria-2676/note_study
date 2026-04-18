import 'dart:math';
import '../models/scratch_model.dart';
import '../repositories/scratch_repository.dart';
import '../../shop/models/shop_model.dart';

class ScratchService {
    final ScratchRepository _repository;

    ScratchService({ScratchRepository? repository})
        : _repository = repository ?? ScratchRepository();

    Future<List<PrizeItem>> getPrizePool() async {
        return await _repository.getCustomPrizePool();
    }

    Future<void> initializePrizePool(List<ShopItem> shopItems) async {
        await _repository.initializePrizePoolFromShopItems(shopItems);
    }

    Future<void> updatePrizePool(List<PrizeItem> items) async {
        await _repository.saveCustomPrizePool(items);
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

    PrizeItem drawPrize(List<PrizeItem> prizePool, int cost) {
        if (prizePool.isEmpty) {
            throw Exception('奖品池为空');
        }

        final probabilities = _calculateProbabilities(prizePool, cost);
        final random = Random.secure();
        final randomValue = random.nextDouble();

        double cumulative = 0.0;
        for (int i = 0; i < prizePool.length; i++) {
            cumulative += probabilities[i];
            if (randomValue <= cumulative) {
                return prizePool[i];
            }
        }

        return prizePool.last;
    }

    List<double> _calculateProbabilities(List<PrizeItem> prizes, int cost) {
        final weights = <double>[];
        final bonusMultiplier = cost / 10.0;

        for (final prize in prizes) {
            final adjustedValue = prize.value / bonusMultiplier;
            weights.add(1.0 / (adjustedValue * 0.1 + 1));
        }

        final totalWeight = weights.fold(0.0, (sum, w) => sum + w);
        return weights.map((w) => w / totalWeight).toList();
    }

    bool validatePoints(int userPoints, int cost) {
        return userPoints >= cost && cost > 0;
    }

    bool validatePrizePool(List<PrizeItem> pool) {
        if (pool.isEmpty) return false;
        return pool.every((p) =>
            p.name.isNotEmpty &&
            p.value >= 0 &&
            (p.type == 'integral' || p.type == 'goods')
        );
    }
}
