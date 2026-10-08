import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:v5_app/core/services/database/database_service.dart';
import 'package:v5_app/providers/scratch_provider.dart';
import 'package:v5_app/modules/scratch/models/scratch_model.dart';
import 'package:v5_app/modules/scratch/models/scratch_state.dart';

void main() {
  // DatabaseService.instance 落到 ffi SQLite，独立临时目录隔离。
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
  setUpAll(() async {
    final dir = Directory.systemTemp.createTempSync('v5_scratch_test');
    await databaseFactory.setDatabasesPath(dir.path);
  });

  late ScratchProvider provider;

  setUp(() async {
    await DatabaseService.instance.clearAllData();
    provider = ScratchProvider();
  });

  ScratchTicket ticket() => ScratchTicket(
    costPoints: 10,
    prizeId: 'test',
    prizeName: 'Test',
    prizeType: 'integral',
    prizeValue: 10,
  );

  group('initial state', () {
    test('should have correct default values', () {
      expect(provider.state, ScratchState.idle);
      expect(provider.customPrizePool, isEmpty);
      expect(provider.lotteryRecords, isEmpty);
      expect(provider.ticketWallet, isEmpty);
      expect(provider.currentTicket, isNull);
      expect(provider.selectedCost, 10);
      expect(provider.isProcessing, false);
      expect(provider.errorMessage, isNull);
    });

    test('costOptions should contain correct values', () {
      expect(ScratchProvider.costOptions, containsAll([10, 20, 50]));
    });

    test('unscratchedCount should return correct count', () {
      expect(provider.unscratchedCount, 0);
    });
  });

  group('cost selection', () {
    test('setCost should update selectedCost when in idle state', () {
      provider.setCost(20);
      expect(provider.selectedCost, 20);
    });

    test('setCost should not update when cost is not in options', () {
      provider.setCost(100);
      expect(provider.selectedCost, 10);
    });

    test('setCost should not update when not in idle state', () {
      final ticket = ScratchTicket(
        costPoints: 10,
        prizeId: 'test',
        prizeName: 'Test',
        prizeType: 'integral',
        prizeValue: 10,
      );
      provider.selectTicket(ticket);
      provider.startScratching();
      provider.setCost(20);
      expect(provider.selectedCost, 10);
    });
  });

  group('canAfford', () {
    test('should return true when user has enough points', () {
      expect(provider.canAfford(100), true);
    });

    test('should return false when user does not have enough points', () {
      provider.setCost(50);
      expect(provider.canAfford(30), false);
    });

    test('should return true when user has exactly enough points', () {
      provider.setCost(20);
      expect(provider.canAfford(20), true);
    });
  });

  group('prize pool', () {
    test('defaultPrizePool should return correct pool for selected cost', () {
      provider.setCost(10);
      final pool10 = provider.defaultPrizePool;
      expect(pool10.isNotEmpty, true);

      provider.setCost(20);
      final pool20 = provider.defaultPrizePool;
      expect(pool20.isNotEmpty, true);
      expect(pool10, isNot(equals(pool20)));
    });

    test('completePrizePool should include both default and custom prizes', () {
      final completePool = provider.completePrizePool;
      expect(
        completePool.length,
        greaterThanOrEqualTo(provider.defaultPrizePool.length),
      );
    });

    test('availablePrizePool should filter by max value', () {
      provider.setCost(10);
      final availablePool = provider.availablePrizePool;
      final maxAllowed = 10 * ScratchProvider.maxPrizeValueMultiplier;

      for (final prize in availablePool) {
        expect(prize.value, lessThanOrEqualTo(maxAllowed));
      }
    });
  });

  group('probability calculation', () {
    test(
      'getPrizeProbabilities should return non-empty map for available prizes',
      () {
        provider.setCost(10);
        final probabilities = provider.getPrizeProbabilities();

        expect(probabilities.isNotEmpty, true);
      },
    );

    test('getPrizeProbabilities should sum to approximately 1.0', () {
      provider.setCost(10);
      final probabilities = provider.getPrizeProbabilities();

      final totalProbability = probabilities.values.fold(
        0.0,
        (sum, p) => sum + p,
      );
      expect(totalProbability, closeTo(1.0, 0.0001));
    });
  });

  group('state management', () {
    test(
      'startScratching should change state to scratching when ticket exists',
      () {
        final ticket = ScratchTicket(
          costPoints: 10,
          prizeId: 'test',
          prizeName: 'Test',
          prizeType: 'integral',
          prizeValue: 10,
        );
        provider.selectTicket(ticket);

        provider.startScratching();
        expect(provider.state, ScratchState.scratching);
      },
    );

    test('startScratching should not change state when no ticket', () {
      provider.startScratching();
      expect(provider.state, ScratchState.idle);
    });

    test('exitScratching should change state back to idle', () {
      final ticket = ScratchTicket(
        costPoints: 10,
        prizeId: 'test',
        prizeName: 'Test',
        prizeType: 'integral',
        prizeValue: 10,
      );
      provider.selectTicket(ticket);
      provider.startScratching();

      provider.exitScratching();
      expect(provider.state, ScratchState.idle);
    });

    test('revealPrize should change state to revealed when scratching', () {
      final ticket = ScratchTicket(
        costPoints: 10,
        prizeId: 'test',
        prizeName: 'Test',
        prizeType: 'integral',
        prizeValue: 10,
      );
      provider.selectTicket(ticket);
      provider.startScratching();

      provider.revealPrize();
      expect(provider.state, ScratchState.revealed);
    });

    test('resetScratchCard should reset state and ticket', () {
      final ticket = ScratchTicket(
        costPoints: 10,
        prizeId: 'test',
        prizeName: 'Test',
        prizeType: 'integral',
        prizeValue: 10,
      );
      provider.selectTicket(ticket);
      provider.startScratching();
      provider.revealPrize();

      provider.resetScratchCard();
      expect(provider.state, ScratchState.idle);
      expect(provider.currentTicket, isNull);
      expect(provider.errorMessage, isNull);
    });
  });

  group('ticket selection', () {
    test('selectTicket should set currentTicket when in idle state', () {
      final ticket = ScratchTicket(
        costPoints: 10,
        prizeId: 'test',
        prizeName: 'Test',
        prizeType: 'integral',
        prizeValue: 10,
      );

      provider.selectTicket(ticket);
      expect(provider.currentTicket, ticket);
    });

    test('selectTicket should not change ticket when not in idle state', () {
      final ticket1 = ScratchTicket(
        costPoints: 10,
        prizeId: 'test1',
        prizeName: 'Test1',
        prizeType: 'integral',
        prizeValue: 10,
      );
      final ticket2 = ScratchTicket(
        costPoints: 20,
        prizeId: 'test2',
        prizeName: 'Test2',
        prizeType: 'integral',
        prizeValue: 20,
      );

      provider.selectTicket(ticket1);
      provider.startScratching();
      provider.selectTicket(ticket2);

      expect(provider.currentTicket?.prizeId, 'test1');
    });
  });

  group('error handling', () {
    test('clearError should set errorMessage to null', () {
      provider.clearError();
      expect(provider.errorMessage, isNull);
    });
  });

  group('canAddToPrizePool', () {
    test('should return true when prize value is within limit', () {
      provider.setCost(10);
      final prize = PrizeItem(
        id: 'test',
        name: 'Test',
        type: 'integral',
        value: 50,
      );

      expect(provider.canAddToPrizePool(prize), true);
    });

    test('should return false when prize value exceeds limit', () {
      provider.setCost(10);
      final prize = PrizeItem(
        id: 'test',
        name: 'Test',
        type: 'integral',
        value: 200,
      );

      expect(provider.canAddToPrizePool(prize), false);
    });
  });

  group('ScratchPlayMixin 购票与开奖', () {
    test('buyTicket 成功扣分并出票', () async {
      await DatabaseService.instance.updateUserPoints(100);

      final ok = await provider.buyTicket(100);

      expect(ok, isTrue);
      expect(provider.isProcessing, isFalse);
      expect(provider.currentTicket, isNotNull);
      expect(provider.currentTicket!.id, isNotNull);
      expect(provider.ticketWallet.length, 1);
      expect(provider.unscratchedCount, 1);
    });

    test('buyTicket 积分不足返回 false 并提示', () async {
      final ok = await provider.buyTicket(5);

      expect(ok, isFalse);
      expect(provider.errorMessage, contains('积分不足'));
    });

    test('buyTicket 非 idle 状态直接返回 false', () async {
      await DatabaseService.instance.updateUserPoints(100);
      provider.selectTicket(ticket());
      provider.startScratching();

      expect(await provider.buyTicket(100), isFalse);
    });

    test('saveLotteryResult 写入开奖记录并刷新彩票夹', () async {
      await DatabaseService.instance.updateUserPoints(100);
      await provider.buyTicket(100);
      provider.startScratching();
      provider.revealPrize();

      await provider.saveLotteryResult();

      expect(provider.lotteryRecords.length, 1);
      expect(
        provider.lotteryRecords.single.prizeName,
        provider.currentTicket!.prizeName,
      );
      expect(provider.ticketWallet, isEmpty);
    });

    test('deleteTicket 删除彩票并清空当前票', () async {
      await DatabaseService.instance.updateUserPoints(100);
      await provider.buyTicket(100);
      final id = provider.currentTicket!.id!;

      await provider.deleteTicket(id);

      expect(provider.currentTicket, isNull);
      expect(provider.ticketWallet, isEmpty);
    });

    test('deleteRecord 删除单条记录', () async {
      await _insertRecord(provider, 1);
      expect(provider.lotteryRecords.length, 1);

      await provider.deleteRecord(provider.lotteryRecords.single.id!);

      expect(provider.lotteryRecords, isEmpty);
    });

    test('clearAllRecords 清空全部记录', () async {
      await _insertRecord(provider, 1);
      await _insertRecord(provider, 2);
      expect(provider.lotteryRecords.length, 2);

      await provider.clearAllRecords();

      expect(provider.lotteryRecords, isEmpty);
    });
  });

  group('ScratchPrizePoolMixin 奖池持久化', () {
    test('initialize 加载空的自定义奖池与记录', () async {
      await provider.initialize(const []);

      expect(provider.customPrizePool, isEmpty);
      expect(provider.lotteryRecords, isEmpty);
      expect(provider.ticketWallet, isEmpty);
      expect(provider.errorMessage, isNull);
    });

    test('addPrizeToPool 幂等持久化', () async {
      await provider.initialize(const []);
      final prize = PrizeItem(
        id: 'p1',
        name: '自定义',
        type: 'integral',
        value: 8,
      );

      await provider.addPrizeToPool(prize);
      await provider.addPrizeToPool(prize);

      expect(provider.customPrizePool.map((p) => p.id), ['p1']);
      expect(provider.completePrizePool.any((p) => p.id == 'p1'), isTrue);
    });

    test('updatePrizeWeight 更新权重', () async {
      await provider.initialize(const []);
      await provider.addPrizeToPool(
        PrizeItem(id: 'p1', name: '自定义', type: 'integral', value: 8),
      );

      await provider.updatePrizeWeight('p1', 3.0);

      expect(provider.customPrizePool.single.weight, 3.0);
    });

    test('removePrizeFromPool 与 resetPrizePoolToDefault', () async {
      await provider.initialize(const []);
      await provider.addPrizeToPool(
        PrizeItem(id: 'p1', name: '自定义', type: 'integral', value: 8),
      );

      await provider.removePrizeFromPool('p1');
      expect(provider.customPrizePool, isEmpty);

      await provider.addPrizeToPool(
        PrizeItem(id: 'p2', name: '自定义2', type: 'integral', value: 9),
      );
      await provider.resetPrizePoolToDefault();
      expect(provider.customPrizePool, isEmpty);
    });
  });
}

Future<void> _insertRecord(ScratchProvider provider, int day) async {
  await DatabaseService.instance.insertLotteryRecord(
    LotteryRecord(
      drawTime: DateTime(2024, 1, day),
      prizeName: 'p$day',
      prizeType: 'integral',
      prizeValue: 1,
      costPoints: 10,
    ),
  );
  await provider.initialize(const []);
}
