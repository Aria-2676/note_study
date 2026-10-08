import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:v5_app/core/services/database/database_service.dart';
import 'package:v5_app/modules/scratch/models/default_prize_pools.dart';
import 'package:v5_app/modules/scratch/repositories/scratch_free_ticket_repository.dart';
import 'package:v5_app/providers/points_provider.dart';
import 'package:v5_app/providers/scratch_provider.dart';

/// 每日免费刮奖：按自然日一次、固定最低档、不消耗积分。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
  setUpAll(() async {
    final dir = Directory.systemTemp.createTempSync('v5_scratch_free_test');
    await databaseFactory.setDatabasesPath(dir.path);
  });

  group('ScratchFreeTicketRepository 每日一次语义', () {
    test('首次可用，领取后当天不可用', () async {
      SharedPreferences.setMockInitialValues({});
      final repository = ScratchFreeTicketRepository();

      expect(await repository.isFreeAvailable(), isTrue);
      await repository.markUsed();
      expect(await repository.isFreeAvailable(), isFalse);
    });

    test('跨自然日重新可用', () async {
      SharedPreferences.setMockInitialValues({
        'scratch_free_ticket_last_date': '2000-01-01',
      });
      final repository = ScratchFreeTicketRepository();

      expect(await repository.isFreeAvailable(), isTrue);
    });
  });

  group('ScratchProvider.claimFreeTicket', () {
    late ScratchProvider provider;
    late PointsProvider pointsProvider;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await DatabaseService.instance.clearAllData();
      provider = ScratchProvider();
      pointsProvider = PointsProvider();
      await pointsProvider.reload();
      await provider.initialize(const []);
    });

    test('领取成功、不消耗积分、票据票价为 0', () async {
      await pointsProvider.updatePoints(0);

      final ok = await provider.claimFreeTicket();

      expect(ok, isTrue);
      expect(provider.currentTicket, isNotNull);
      expect(provider.currentTicket!.costPoints, 0);
      expect(provider.freeTicketAvailable, isFalse);
      await pointsProvider.reload();
      expect(pointsProvider.currentPoints, 0);
    });

    test('同一天不能重复领取', () async {
      expect(await provider.claimFreeTicket(), isTrue);
      provider.resetScratchCard();

      expect(await provider.claimFreeTicket(), isFalse);
      expect(provider.freeTicketAvailable, isFalse);
    });

    test('免费刮奖使用最低档奖池', () async {
      expect(ScratchProvider.freeTicketCost, 10);

      await provider.claimFreeTicket();
      final values = defaultPrizePoolsByCost[ScratchProvider.freeTicketCost]!
          .map((p) => p.value)
          .toSet();

      expect(values.contains(provider.currentTicket!.prizeValue), isTrue);
    });
  });
}