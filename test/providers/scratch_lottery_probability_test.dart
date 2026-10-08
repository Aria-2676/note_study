import 'package:flutter_test/flutter_test.dart';
import 'package:v5_app/modules/scratch/models/scratch_model.dart';
import 'package:v5_app/providers/scratch_provider.dart';

/// 刮刮乐概率模型的纯数学验证（不依赖数据库）。
///
/// 对齐真实即开型彩票：返奖率固定 65%、中奖率由返奖率反解、
/// 三档票价中奖率一致、头奖金额随票价放大但概率极低。
void main() {
  late ScratchProvider provider;

  setUp(() => provider = ScratchProvider());

  Map<PrizeItem, double> probabilitiesFor(int cost) {
    provider.setCost(cost);
    return provider.getPrizeProbabilities();
  }

  double returnRateFor(int cost) {
    provider.setCost(cost);
    return provider.actualReturnRate;
  }

  group('刮刮乐概率模型（对齐即开型彩票）', () {
    test('三档返奖率均约为 65%', () {
      for (final cost in ScratchProvider.costOptions) {
        expect(
          returnRateFor(cost),
          closeTo(ScratchProvider.targetReturnRate, 0.01),
          reason: '票价 $cost 的返奖率应约为 65%',
        );
      }
    });

    test('三档中奖率一致且落在合理区间', () {
      final rates = ScratchProvider.costOptions
          .map((cost) => probabilitiesFor(cost))
          .map(
            (probabilities) => probabilities.entries
                .where((entry) => entry.key.value > 0)
                .fold(0.0, (sum, entry) => sum + entry.value),
          )
          .toList();

      for (final rate in rates) {
        expect(rate, greaterThan(0.20));
        expect(rate, lessThan(0.40));
      }
      // 面额随票价等比放大 ⇒ 三档中奖率完全一致
      expect(rates[0], closeTo(rates[1], 1e-9));
      expect(rates[1], closeTo(rates[2], 1e-9));
    });

    test('概率总和为 1，且空奖概率 = 1 - 中奖率', () {
      for (final cost in ScratchProvider.costOptions) {
        provider.setCost(cost);
        final probabilities = provider.getPrizeProbabilities();

        final total = probabilities.values.fold(0.0, (sum, v) => sum + v);
        expect(total, closeTo(1.0, 1e-9));

        final noPrize = probabilities.entries
            .where((entry) => entry.key.value <= 0)
            .toList();
        expect(noPrize, hasLength(1), reason: '每档应恰好一个空奖');
        expect(
          noPrize.single.value,
          closeTo(1 - provider.winProbability, 1e-9),
        );
      }
    });

    test('空奖为最高概率结果且名为「谢谢参与」', () {
      final probabilities = probabilitiesFor(10);
      final maxEntry = probabilities.entries.reduce(
        (a, b) => a.value >= b.value ? a : b,
      );

      expect(maxEntry.key.type, ScratchProvider.noPrizeType);
      expect(maxEntry.key.name, '谢谢参与');
      expect(maxEntry.value, greaterThan(0.5));
    });

    test('头奖概率极低（低于万分之一）', () {
      for (final cost in ScratchProvider.costOptions) {
        final probabilities = probabilitiesFor(cost);
        final jackpot = probabilities.entries.reduce(
          (a, b) => a.key.value >= b.key.value ? a : b,
        );

        expect(
          jackpot.value,
          lessThan(0.0001),
          reason: '票价 $cost 的头奖概率应极低',
        );
      }
    });

    test('头奖金额随票价等比放大', () {
      final jackpots = ScratchProvider.costOptions
          .map(
            (cost) => probabilitiesFor(
              cost,
            ).keys.map((p) => p.value).reduce((a, b) => a > b ? a : b),
          )
          .toList();

      expect(jackpots[0], greaterThan(0));
      expect(jackpots[1] / jackpots[0], closeTo(2.0, 1e-9));
      expect(jackpots[2] / jackpots[0], closeTo(5.0, 1e-9));
    });

    test('所有概率有限且非负，期望回报为正', () {
      for (final cost in ScratchProvider.costOptions) {
        provider.setCost(cost);
        final probabilities = provider.getPrizeProbabilities();

        for (final value in probabilities.values) {
          expect(value.isFinite, isTrue);
          expect(value, greaterThanOrEqualTo(0));
        }
        expect(provider.winProbability, greaterThan(0));
        expect(provider.expectedReturnValue, greaterThan(0));
      }
    });

    test('奖池面额上限为 100 倍票价', () {
      expect(ScratchProvider.maxPrizeValueMultiplier, 100);

      for (final cost in ScratchProvider.costOptions) {
        provider.setCost(cost);
        final maxValue = provider.availablePrizePool
            .map((p) => p.value)
            .reduce((a, b) => a > b ? a : b);
        expect(maxValue, cost * ScratchProvider.maxPrizeValueMultiplier);
      }
    });
  });
}