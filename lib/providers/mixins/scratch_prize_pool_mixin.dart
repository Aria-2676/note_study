part of '../scratch_provider.dart';

/// 抽奖池的组装、可用范围与中奖概率计算。
mixin ScratchPrizePoolMixin on ScratchProviderCoreMixin {
  List<PrizeItem> get defaultPrizePool {
    return defaultPrizePoolsByCost[_selectedCost] ??
        defaultPrizePoolsByCost[10]!;
  }

  List<PrizeItem> get completePrizePool {
    return [...defaultPrizePool, ..._customPrizePool];
  }

  double get expectedReturnValue {
    return _selectedCost.toDouble();
  }

  bool canAddToPrizePool(PrizeItem prize) {
    return prize.value <=
        _selectedCost * ScratchProvider.maxPrizeValueMultiplier;
  }

  List<PrizeItem> get availablePrizePool {
    final maxAllowedValue =
        _selectedCost * ScratchProvider.maxPrizeValueMultiplier;
    return completePrizePool.where((p) => p.value <= maxAllowedValue).toList();
  }

  Map<PrizeItem, double> getPrizeProbabilities() {
    final prizes = availablePrizePool;
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

  /// 按概率随机抽取一个奖品。
  PrizeItem _drawPrize() {
    final probabilities = getPrizeProbabilities();

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

  Future<void> addPrizeToPool(PrizeItem prize) async {
    if (!_customPrizePool.any((p) => p.id == prize.id)) {
      _customPrizePool.add(prize);
      await _repository.saveCustomPrizePool(_customPrizePool);
      notifyListeners();
    }
  }

  Future<void> removePrizeFromPool(String prizeId) async {
    _customPrizePool.removeWhere((p) => p.id == prizeId);
    await _repository.saveCustomPrizePool(_customPrizePool);
    notifyListeners();
  }

  Future<void> resetPrizePoolToDefault() async {
    try {
      await _repository.clearCustomPrizePool();
      _customPrizePool = [];
      notifyListeners();
    } catch (e) {
      _errorMessage = '重置抽奖池失败: $e';
      notifyListeners();
    }
  }

  Future<void> updatePrizeWeight(String prizeId, double newWeight) async {
    final index = _customPrizePool.indexWhere((p) => p.id == prizeId);
    if (index != -1) {
      _customPrizePool[index] = _customPrizePool[index].copyWith(
        weight: newWeight,
      );
      await _repository.saveCustomPrizePool(_customPrizePool);
      notifyListeners();
    }
  }
}
