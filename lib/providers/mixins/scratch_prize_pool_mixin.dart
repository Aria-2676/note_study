part of '../scratch_provider.dart';

/// 抽奖池的组装、可用范围与中奖概率计算。
///
/// 概率模型对齐真实即开型彩票（体彩顶呱刮 / 福彩刮刮乐）：
/// - 返奖率固定为 [ScratchProvider.targetReturnRate]（官方口径 65%）；
/// - **中奖率由返奖率反解**，因此三档票价的中奖率一致；
/// - 奖项面额随票价等比放大 → 头奖金额随票价放大，但概率极低；
/// - 未中奖由奖池中的空奖「谢谢参与」（`value == 0`）承载。
///
/// 所有计算都提供「按指定档位」的变体（`xxxFor(cost)`），以便免费刮奖
/// 固定使用最低档而**不改变用户当前选中的档位**。
mixin ScratchPrizePoolMixin on ScratchProviderCoreMixin {
  /// 指定档位的默认奖池。
  List<PrizeItem> defaultPrizePoolFor(int cost) {
    return defaultPrizePoolsByCost[cost] ?? defaultPrizePoolsByCost[10]!;
  }

  List<PrizeItem> get defaultPrizePool => defaultPrizePoolFor(_selectedCost);

  /// 指定档位的兜底空奖。
  PrizeItem noPrizeItemFor(int cost) => PrizeItem(
    id: 'none_$cost',
    name: '谢谢参与',
    type: ScratchProvider.noPrizeType,
    value: 0,
    weight: 1,
    isDefault: true,
  );

  PrizeItem get noPrizeItem => noPrizeItemFor(_selectedCost);

  /// 指定档位的完整奖池（默认 + 自定义，并保证含一个空奖）。
  List<PrizeItem> completePrizePoolFor(int cost) {
    final pool = [...defaultPrizePoolFor(cost), ..._customPrizePool];
    if (pool.any((p) => p.value <= 0)) return pool;
    return [noPrizeItemFor(cost), ...pool];
  }

  List<PrizeItem> get completePrizePool => completePrizePoolFor(_selectedCost);

  bool canAddToPrizePool(PrizeItem prize) {
    return prize.value <=
        _selectedCost * ScratchProvider.maxPrizeValueMultiplier;
  }

  /// 指定档位下实际入池的奖品（剔除超过面额上限的）。
  List<PrizeItem> availablePrizePoolFor(int cost) {
    final maxAllowedValue = cost * ScratchProvider.maxPrizeValueMultiplier;
    return completePrizePoolFor(
      cost,
    ).where((p) => p.value <= maxAllowedValue).toList();
  }

  List<PrizeItem> get availablePrizePool => availablePrizePoolFor(_selectedCost);

  /// 「中奖条件下」的奖项分布（不含空奖），按 [PrizeItem.weight] 归一化。
  ///
  /// 权重在此才真正生效：`weight` 越大越容易中，但**不影响返奖率**——
  /// 返奖率由下面的中奖率反解统一守住。
  Map<PrizeItem, double> _conditionalWinDistribution(List<PrizeItem> prizes) {
    final winnable = prizes.where((p) => p.value > 0 && p.weight > 0).toList();
    final totalWeight = winnable.fold(0.0, (sum, p) => sum + p.weight);
    if (winnable.isEmpty || totalWeight <= 0) return const {};
    return {for (final p in winnable) p: p.weight / totalWeight};
  }

  /// 指定档位各奖项的中奖概率（含空奖）。
  ///
  /// 推导：设中奖率为 `q`、中奖时平均回报为 `S`，则期望回报 `= q·S`。
  /// 令其等于目标返奖额 `R·C`，即得 `q = R·C / S`（上限 1）。
  /// 故只要奖池可支付，实际返奖率恒为 `R`
  /// （奖池过于寒酸、`S < R·C` 时会自然封顶为「必中但回报偏低」）。
  Map<PrizeItem, double> probabilitiesFor(int cost) {
    final prizes = availablePrizePoolFor(cost);
    if (prizes.isEmpty) return const {};

    final conditional = _conditionalWinDistribution(prizes);
    if (conditional.isEmpty) return const {};

    final averageWin = conditional.entries.fold(
      0.0,
      (sum, entry) => sum + entry.key.value * entry.value,
    );
    if (averageWin <= 0) return const {};

    final targetPayout = ScratchProvider.targetReturnRate * cost;
    final winRate = (targetPayout / averageWin).clamp(0.0, 1.0);

    final result = <PrizeItem, double>{};
    final noPrize = prizes.firstWhere(
      (p) => p.value <= 0,
      orElse: () => noPrizeItemFor(cost),
    );
    result[noPrize] = 1 - winRate;
    for (final entry in conditional.entries) {
      result[entry.key] = entry.value * winRate;
    }
    return result;
  }

  Map<PrizeItem, double> getPrizeProbabilities() =>
      probabilitiesFor(_selectedCost);

  /// 中奖率（不含空奖）。
  double get winProbability {
    return getPrizeProbabilities().entries
        .where((entry) => entry.key.value > 0)
        .fold(0.0, (sum, entry) => sum + entry.value);
  }

  /// 单张彩票的期望回报（积分）。
  double get expectedReturnValue {
    return getPrizeProbabilities().entries.fold(
      0.0,
      (sum, entry) => sum + entry.key.value * entry.value,
    );
  }

  /// 实际返奖率 = 期望回报 / 票价。
  double get actualReturnRate =>
      _selectedCost <= 0 ? 0 : expectedReturnValue / _selectedCost;

  /// 按概率随机抽取一个奖品（可能为空奖）。
  ///
  /// [cost] 用于指定档位；默认使用当前选中档位（免费刮奖传 10）。
  PrizeItem _drawPrize({int? cost}) {
    final targetCost = cost ?? _selectedCost;
    final probabilities = probabilitiesFor(targetCost);
    if (probabilities.isEmpty) return noPrizeItemFor(targetCost);

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
}