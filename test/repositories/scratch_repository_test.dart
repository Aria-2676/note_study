import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:v5_app/core/services/database/database_service.dart';
import 'package:v5_app/modules/scratch/models/scratch_model.dart';
import 'package:v5_app/modules/scratch/repositories/scratch_repository.dart';

PrizeItem _prize(String id, {String name = '奖品'}) =>
    PrizeItem(id: id, name: name, type: 'integral', value: 5);

LotteryRecord _lottery({
  DateTime? drawTime,
  String prizeName = '5积分',
  int costPoints = 10,
}) => LotteryRecord(
  drawTime: drawTime ?? DateTime(2026, 9, 20, 10),
  prizeName: prizeName,
  prizeType: 'integral',
  prizeValue: 5,
  costPoints: costPoints,
);

ScratchTicket _ticket({int? id, int cost = 10, bool isRevealed = false}) =>
    ScratchTicket(
      id: id,
      costPoints: cost,
      prizeId: 'prize_5',
      prizeName: '5积分',
      prizeType: 'integral',
      prizeValue: 5,
      isRevealed: isRevealed,
    );

void main() {
  sqfliteFfiInit();

  late Directory dbDir;
  late ScratchRepository repository;

  setUpAll(() async {
    // 为本次测试文件单独指定一个 ffi 数据库目录，避免与其他测试文件并发
    // 共用同一个 .dart_tool 数据库文件。
    dbDir = Directory.systemTemp.createTempSync('v5_scratch_repo_');
    await databaseFactoryFfi.setDatabasesPath(dbDir.path);
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    repository = ScratchRepository();
    // DatabaseService 是单例，测试间通过清表保证隔离
    final db = await DatabaseService.instance.database;
    await db.delete('custom_prize_pool');
    await db.delete('lottery_records');
    await db.delete('scratch_tickets');
    await db.delete('points_records');
    await db.update(
      'user_points',
      {'points': 0, 'updated_at': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [1],
    );
  });

  tearDownAll(() async {
    await DatabaseService.instance.close();
    try {
      dbDir.deleteSync(recursive: true);
    } catch (_) {}
  });

  group('ScratchRepository', () {
    test('should start empty and replace the custom prize pool on save',
        () async {
      expect(await repository.getCustomPrizePool(), isEmpty);

      await repository.saveCustomPrizePool([_prize('a'), _prize('b')]);
      expect((await repository.getCustomPrizePool()).length, 2);

      await repository.saveCustomPrizePool([_prize('c', name: 'C')]);
      final pool = await repository.getCustomPrizePool();
      expect(pool.length, 1);
      expect(pool.single.id, 'c');
      expect(pool.single.name, 'C');

      await repository.clearCustomPrizePool();
      expect(await repository.getCustomPrizePool(), isEmpty);
    });

    test('should insert and list lottery records by draw time desc', () async {
      await repository.insertLotteryRecord(
        _lottery(drawTime: DateTime(2026, 9, 20, 8)),
      );
      final id = await repository.insertLotteryRecord(
        _lottery(drawTime: DateTime(2026, 9, 20, 12)),
      );

      final records = await repository.getLotteryRecords();
      expect(records.length, 2);
      expect(records.first.drawTime, DateTime(2026, 9, 20, 12));
      expect(records.first.id, id);
    });

    test('should update and delete a single lottery record', () async {
      final id = await repository.insertLotteryRecord(_lottery());
      final record = (await repository.getLotteryRecords()).single;

      await repository.updateLotteryRecord(
        LotteryRecord(
          id: record.id,
          drawTime: record.drawTime,
          prizeName: '新奖品',
          prizeType: record.prizeType,
          prizeValue: record.prizeValue,
          costPoints: record.costPoints,
          createdAt: record.createdAt,
        ),
      );
      expect((await repository.getLotteryRecords()).single.prizeName, '新奖品');

      expect(await repository.deleteLotteryRecord(id), 1);
      expect(await repository.getLotteryRecords(), isEmpty);
    });

    test('should delete all lottery records', () async {
      await repository.insertLotteryRecord(_lottery());
      await repository.insertLotteryRecord(_lottery());

      expect(await repository.deleteAllLotteryRecords(), 2);
      expect(await repository.getLotteryRecords(), isEmpty);
    });

    test('should insert, update and delete scratch tickets', () async {
      final id = await repository.insertScratchTicket(_ticket());
      await repository.insertScratchTicket(_ticket(isRevealed: true));

      expect((await repository.getAllScratchTickets()).length, 2);
      expect((await repository.getUnscratchedTickets()).length, 1);

      final unscratched = (await repository.getUnscratchedTickets()).single;
      await repository.updateScratchTicket(
        unscratched.copyWith(isRevealed: true, isScratched: true),
      );
      expect(await repository.getUnscratchedTickets(), isEmpty);

      expect(await repository.deleteScratchTicket(id), 1);
      expect((await repository.getAllScratchTickets()).length, 1);

      expect(await repository.deleteRevealedTickets(), 1);
      expect(await repository.getAllScratchTickets(), isEmpty);
    });

    test('should purchase a ticket only when points are sufficient', () async {
      await DatabaseService.instance.getUserPoints();
      await DatabaseService.instance.updateUserPoints(100);

      final ticketId = await repository.purchaseTicket(_ticket(cost: 30), 30);
      expect(ticketId, isNotNull);
      expect((await repository.getUnscratchedTickets()).length, 1);
      expect((await DatabaseService.instance.getUserPoints()).points, 70);

      final record = (await DatabaseService.instance.getPointsRecords()).single;
      expect(record.points, -30);
      expect(record.type, 'scratch_cost');
      expect(record.relatedId, ticketId);
    });

    test('should write nothing when points are insufficient', () async {
      await DatabaseService.instance.getUserPoints();
      await DatabaseService.instance.updateUserPoints(10);

      final ticketId = await repository.purchaseTicket(_ticket(cost: 30), 30);

      expect(ticketId, isNull);
      expect(await repository.getAllScratchTickets(), isEmpty);
      expect((await DatabaseService.instance.getUserPoints()).points, 10);
    });
  });
}