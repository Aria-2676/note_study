import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:v5_app/core/services/database/database_gateway.dart';
import 'package:v5_app/core/services/database/database_scratch_mixin.dart';
import 'package:v5_app/modules/scratch/models/scratch_model.dart';

/// 被测数据库：把 [DatabaseScratchMixin] 组合到内存 SQLite 上。
///
/// 建表直接复用生产方法 `createScratchTables`。
class _TestDb with DatabaseScratchMixin implements DatabaseGateway {
  @override
  final String dbName = 'test.db';

  Future<Database>? _opening;

  @override
  Future<Database> get database => _opening ??= _open();

  Future<Database> _open() => databaseFactoryFfi.openDatabase(
    inMemoryDatabasePath,
    options: OpenDatabaseOptions(version: 3, onCreate: _create),
  );

  @override
  Future<T> transaction<T>(Future<T> Function(Transaction txn) action) async =>
      (await database).transaction(action);

  Future<void> close() async {
    final db = await _opening;
    await db?.close();
    _opening = null;
  }

  Future<void> _create(Database db, int version) async {
    await createScratchTables(db, version);
  }
}

PrizeItem _prize(String id, {String name = 'p', int value = 5, bool isDefault = false}) =>
    PrizeItem(id: id, name: name, type: 'integral', value: value, isDefault: isDefault);

LotteryRecord _lottery({
  DateTime? drawTime,
  String prizeName = '5积分',
  int costPoints = 10,
  int prizeValue = 5,
}) => LotteryRecord(
  drawTime: drawTime ?? DateTime(2026, 9, 20, 10),
  prizeName: prizeName,
  prizeType: 'integral',
  prizeValue: prizeValue,
  costPoints: costPoints,
);

ScratchTicket _ticket({int? id, bool isRevealed = false, bool isScratched = false}) =>
    ScratchTicket(
      id: id,
      costPoints: 10,
      prizeId: 'prize_5',
      prizeName: '5积分',
      prizeType: 'integral',
      prizeValue: 5,
      isRevealed: isRevealed,
      isScratched: isScratched,
    );

void main() {
  sqfliteFfiInit();

  late _TestDb db;

  setUp(() => db = _TestDb());
  tearDown(() => db.close());

  group('DatabaseScratchMixin', () {
    test('should create the scratch tables', () async {
      expect(await db.getCustomPrizePool(), isEmpty);
      expect(await db.getLotteryRecords(), isEmpty);
      expect(await db.getAllScratchTickets(), isEmpty);
    });

    test('should replace the custom prize pool on save', () async {
      await db.saveCustomPrizePool([_prize('a', name: 'A'), _prize('b', name: 'B')]);
      expect((await db.getCustomPrizePool()).length, 2);

      await db.saveCustomPrizePool([_prize('c', name: 'C')]);
      final pool = await db.getCustomPrizePool();
      expect(pool.length, 1);
      expect(pool.single['name'], 'C');
    });

    test('should insert lottery records and list by draw time desc', () async {
      await db.insertLotteryRecord(_lottery(drawTime: DateTime(2026, 9, 20, 8)));
      await db.insertLotteryRecord(_lottery(drawTime: DateTime(2026, 9, 20, 12)));

      final records = await db.getLotteryRecords();
      expect(records.length, 2);
      expect(records.first.drawTime, DateTime(2026, 9, 20, 12));
    });

    test('should return the id from insertLotteryRecordWithId', () async {
      final id = await db.insertLotteryRecordWithId(_lottery());
      expect(id, greaterThan(0));
      expect((await db.getLotteryRecords()).single.id, id);
    });

    test('should update a lottery record', () async {
      await db.insertLotteryRecord(_lottery(prizeName: 'old'));
      final record = (await db.getLotteryRecords()).single;

      await db.updateLotteryRecord(
        LotteryRecord(
          id: record.id,
          drawTime: record.drawTime,
          prizeName: 'new',
          prizeType: record.prizeType,
          prizeValue: record.prizeValue,
          costPoints: record.costPoints,
          createdAt: record.createdAt,
        ),
      );
      expect((await db.getLotteryRecords()).single.prizeName, 'new');
    });

    test('should delete a single lottery record', () async {
      final id = await db.insertLotteryRecordWithId(_lottery());
      await db.insertLotteryRecord(_lottery());

      final deleted = await db.deleteLotteryRecord(id);
      expect(deleted, 1);
      expect((await db.getLotteryRecords()).length, 1);
    });

    test('should clear and delete all lottery records', () async {
      await db.insertLotteryRecord(_lottery());
      await db.insertLotteryRecord(_lottery());

      expect(await db.clearLotteryRecords(), 2);
      expect(await db.getLotteryRecords(), isEmpty);

      await db.insertLotteryRecord(_lottery());
      expect(await db.deleteAllLotteryRecords(), 1);
    });

    test('should insert scratch tickets and list unscratched ones', () async {
      await db.insertScratchTicket(_ticket());
      await db.insertScratchTicket(_ticket(isRevealed: true));

      expect((await db.getAllScratchTickets()).length, 2);
      final unscratched = await db.getUnscratchedTickets();
      expect(unscratched.length, 1);
      expect(unscratched.single.isRevealed, isFalse);
    });

    test('should update a ticket so it leaves the unscratched list', () async {
      final id = await db.insertScratchTicket(_ticket());
      final ticket = (await db.getAllScratchTickets()).single;

      await db.updateScratchTicket(
        ticket.copyWith(isRevealed: true, isScratched: true),
      );
      expect(await db.getUnscratchedTickets(), isEmpty);

      final updated = (await db.getAllScratchTickets()).single;
      expect(updated.id, id);
      expect(updated.isScratched, isTrue);
    });

    test('should delete one ticket and all revealed tickets', () async {
      final id = await db.insertScratchTicket(_ticket());
      await db.insertScratchTicket(_ticket(isRevealed: true));
      await db.insertScratchTicket(_ticket(isRevealed: true));

      expect(await db.deleteRevealedTickets(), 2);
      expect((await db.getAllScratchTickets()).length, 1);

      expect(await db.deleteScratchTicket(id), 1);
      expect(await db.getAllScratchTickets(), isEmpty);
    });
  });
}