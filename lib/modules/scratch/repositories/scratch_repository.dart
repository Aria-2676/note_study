import '../../../core/services/database/database_service.dart';
import '../models/scratch_model.dart';

class ScratchRepository {
  final DatabaseService _dbService = DatabaseService.instance;

  Future<List<PrizeItem>> getCustomPrizePool() async {
    final pool = await _dbService.getCustomPrizePool();
    return pool.map((m) => PrizeItem.fromMap(m)).toList();
  }

  Future<void> saveCustomPrizePool(List<PrizeItem> items) async {
    await _dbService.saveCustomPrizePool(items);
  }

  Future<void> clearCustomPrizePool() async {
    await _dbService.saveCustomPrizePool([]);
  }

  Future<List<LotteryRecord>> getLotteryRecords() async {
    return await _dbService.getLotteryRecords();
  }

  Future<int> insertLotteryRecord(LotteryRecord record) async {
    return await _dbService.insertLotteryRecordWithId(record);
  }

  Future<void> updateLotteryRecord(LotteryRecord record) async {
    await _dbService.updateLotteryRecord(record);
  }

  Future<int> deleteLotteryRecord(int id) async {
    return await _dbService.deleteLotteryRecord(id);
  }

  Future<int> deleteAllLotteryRecords() async {
    return await _dbService.deleteAllLotteryRecords();
  }

  Future<int> insertScratchTicket(ScratchTicket ticket) async {
    return await _dbService.insertScratchTicket(ticket);
  }

  /// 原子购买刮刮卡：同一事务内完成「扣积分 + 写积分记录 + 出票」。
  ///
  /// 余额不足时返回 null 且不做任何写入。返回新票据 id 表示已整体提交。
  Future<int?> purchaseTicket(ScratchTicket ticket, int cost) async {
    return await _dbService.purchaseScratchTicket(ticket: ticket, cost: cost);
  }

  Future<List<ScratchTicket>> getUnscratchedTickets() async {
    return await _dbService.getUnscratchedTickets();
  }

  Future<List<ScratchTicket>> getAllScratchTickets() async {
    return await _dbService.getAllScratchTickets();
  }

  Future<void> updateScratchTicket(ScratchTicket ticket) async {
    await _dbService.updateScratchTicket(ticket);
  }

  Future<int> deleteScratchTicket(int id) async {
    return await _dbService.deleteScratchTicket(id);
  }

  Future<int> deleteRevealedTickets() async {
    return await _dbService.deleteRevealedTickets();
  }
}
