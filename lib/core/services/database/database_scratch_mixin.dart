import 'package:sqflite/sqflite.dart';
import '../../../modules/scratch/models/scratch_model.dart';

mixin DatabaseScratchMixin {
  Future<Database> get database;
  String get dbName;

  Future<void> createScratchTables(Database db, int version) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS custom_prize_pool (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        type TEXT NOT NULL,
        value INTEGER NOT NULL,
        weight REAL DEFAULT 1.0,
        isDefault INTEGER DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS lottery_records (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        drawTime TEXT NOT NULL,
        prizeName TEXT NOT NULL,
        prizeType TEXT NOT NULL,
        prizeValue INTEGER NOT NULL,
        costPoints INTEGER NOT NULL,
        createdAt TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS scratch_tickets (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        costPoints INTEGER NOT NULL,
        prizeId TEXT NOT NULL,
        prizeName TEXT NOT NULL,
        prizeType TEXT NOT NULL,
        prizeValue INTEGER NOT NULL,
        createdAt TEXT NOT NULL,
        isScratched INTEGER DEFAULT 0,
        isRevealed INTEGER DEFAULT 0
      )
    ''');
  }

  Future<List<Map<String, dynamic>>> getCustomPrizePool() async {
    final db = await database;
    return await db.query('custom_prize_pool');
  }

  Future<void> saveCustomPrizePool(List<PrizeItem> items) async {
    final db = await database;
    await db.delete('custom_prize_pool');
    for (final item in items) {
      await db.insert('custom_prize_pool', item.toMap());
    }
  }

  Future<void> insertLotteryRecord(LotteryRecord record) async {
    final db = await database;
    await db.insert('lottery_records', record.toMap());
  }

  Future<int> insertLotteryRecordWithId(LotteryRecord record) async {
    final db = await database;
    return await db.insert('lottery_records', record.toMap());
  }

  Future<List<LotteryRecord>> getLotteryRecords() async {
    final db = await database;
    final result = await db.query('lottery_records', orderBy: 'drawTime DESC');
    return result.map((m) => LotteryRecord.fromMap(m)).toList();
  }

  Future<void> updateLotteryRecord(LotteryRecord record) async {
    final db = await database;
    await db.update(
      'lottery_records',
      record.toMap(),
      where: 'id = ?',
      whereArgs: [record.id],
    );
  }

  Future<int> deleteLotteryRecord(int id) async {
    final db = await database;
    return await db.delete('lottery_records', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> clearLotteryRecords() async {
    final db = await database;
    return await db.delete('lottery_records');
  }

  Future<int> deleteAllLotteryRecords() async {
    return await clearLotteryRecords();
  }

  Future<int> insertScratchTicket(ScratchTicket ticket) async {
    final db = await database;
    return await db.insert('scratch_tickets', ticket.toMap());
  }

  Future<List<ScratchTicket>> getUnscratchedTickets() async {
    final db = await database;
    final result = await db.query(
      'scratch_tickets',
      where: 'isRevealed = ?',
      whereArgs: [0],
      orderBy: 'createdAt DESC',
    );
    return result.map((m) => ScratchTicket.fromMap(m)).toList();
  }

  Future<List<ScratchTicket>> getAllScratchTickets() async {
    final db = await database;
    final result = await db.query('scratch_tickets', orderBy: 'createdAt DESC');
    return result.map((m) => ScratchTicket.fromMap(m)).toList();
  }

  Future<void> updateScratchTicket(ScratchTicket ticket) async {
    final db = await database;
    await db.update(
      'scratch_tickets',
      ticket.toMap(),
      where: 'id = ?',
      whereArgs: [ticket.id],
    );
  }

  Future<int> deleteScratchTicket(int id) async {
    final db = await database;
    return await db.delete('scratch_tickets', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> deleteRevealedTickets() async {
    final db = await database;
    return await db.delete(
      'scratch_tickets',
      where: 'isRevealed = ?',
      whereArgs: [1],
    );
  }
}
