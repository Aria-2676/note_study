import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:v5_app/core/services/database/database_service.dart';
import 'package:v5_app/modules/scratch/models/scratch_model.dart';
import 'package:v5_app/modules/scratch/models/scratch_state.dart';
import 'package:v5_app/providers/points_provider.dart';
import 'package:v5_app/providers/scratch_provider.dart';
import 'package:v5_app/providers/shop_provider.dart';

/// 发奖下沉到 Provider 后的行为验证：空奖不发奖、按面额发放、幂等。
void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
  setUpAll(() async {
    final dir = Directory.systemTemp.createTempSync('v5_scratch_claim_test');
    await databaseFactory.setDatabasesPath(dir.path);
  });

  late ScratchProvider provider;
  late PointsProvider pointsProvider;
  late ShopProvider shopProvider;

  setUp(() async {
    await DatabaseService.instance.clearAllData();
    provider = ScratchProvider();
    pointsProvider = PointsProvider();
    await pointsProvider.reload();
    shopProvider = ShopProvider(pointsProvider);
  });

  /// 落库一张票据并返回带 id 的实例。
  Future<ScratchTicket> seedTicket({
    required String type,
    required int value,
    required String name,
  }) async {
    final ticket = ScratchTicket(
      costPoints: 10,
      prizeId: 'seed',
      prizeName: name,
      prizeType: type,
      prizeValue: value,
    );
    final id = await DatabaseService.instance.insertScratchTicket(ticket);
    return ticket.copyWith(id: id);
  }

  Future<ScratchClaimOutcome> claim() => provider.claimPrize(
    pointsProvider: pointsProvider,
    shopProvider: shopProvider,
  );

  group('ScratchProvider.claimPrize', () {
    test('空奖不发放任何积分', () async {
      await pointsProvider.updatePoints(100);
      final ticket = await seedTicket(
        type: ScratchProvider.noPrizeType,
        value: 0,
        name: '谢谢参与',
      );
      provider.selectTicket(ticket);

      final outcome = await claim();

      expect(outcome.success, isTrue);
      expect(outcome.isWin, isFalse);
      await pointsProvider.reload();
      expect(pointsProvider.currentPoints, 100);
    });

    test('中奖按面额发放积分', () async {
      await pointsProvider.updatePoints(100);
      final ticket = await seedTicket(type: 'integral', value: 30, name: '30积分');
      provider.selectTicket(ticket);

      final outcome = await claim();

      expect(outcome.success, isTrue);
      expect(outcome.isWin, isTrue);
      await pointsProvider.reload();
      expect(pointsProvider.currentPoints, 130);
    });

    test('同一张票不会二次发放（幂等）', () async {
      await pointsProvider.updatePoints(100);
      final ticket = await seedTicket(type: 'integral', value: 30, name: '30积分');
      provider.selectTicket(ticket);

      final first = await claim();
      final second = await claim();

      expect(first.isWin, isTrue);
      expect(second.success, isFalse);
      expect(second.error, isNotNull);
      await pointsProvider.reload();
      // 只加过一次
      expect(pointsProvider.currentPoints, 130);
    });

    test('没有待结算票据时返回失败且不改动积分', () async {
      await pointsProvider.updatePoints(100);

      final outcome = await claim();

      expect(outcome.success, isFalse);
      expect(outcome.isWin, isFalse);
      await pointsProvider.reload();
      expect(pointsProvider.currentPoints, 100);
    });

    test('结算后复位即可再次购买（修复「只能买一次」）', () async {
      await pointsProvider.updatePoints(100);

      final firstBuy = await provider.buyTicket(100);
      expect(firstBuy, isTrue);
      expect(provider.currentTicket, isNotNull);

      // 走完揭晓 → 落盘 → 结算
      provider.startScratching();
      provider.revealPrize();
      await provider.saveLotteryResult();
      await claim();

      // 页面在结算完成后执行的复位
      provider.resetScratchCard();
      expect(provider.currentTicket, isNull);
      expect(provider.state, ScratchState.idle);

      await pointsProvider.reload();
      final secondBuy = await provider.buyTicket(pointsProvider.currentPoints);
      expect(secondBuy, isTrue, reason: '复位后应能继续购买下一张');
      expect(provider.currentTicket, isNotNull);
    });
  });
}