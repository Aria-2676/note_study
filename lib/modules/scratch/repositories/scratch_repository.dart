import '../../../core/services/database/database_service.dart';
import '../models/scratch_model.dart';
import '../../shop/models/shop_model.dart';

class ScratchRepository {
  final DatabaseService _dbService = DatabaseService.instance;

  Future<List<PrizeItem>> getCustomPrizePool() async {
    final pool = await _dbService.getCustomPrizePool();
    return pool.map((m) => PrizeItem.fromMap(m)).toList();
  }

  Future<void> saveCustomPrizePool(List<PrizeItem> items) async {
    await _dbService.saveCustomPrizePool(items);
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

  Future<void> initializePrizePoolFromShopItems(
    List<ShopItem> shopItems,
  ) async {
    final existingPool = await getCustomPrizePool();
    if (existingPool.isEmpty) {
      final prizeItems = _getDefaultPrizeItems();
      await saveCustomPrizePool(prizeItems);
    }
  }

  Future<void> resetPrizePoolToDefault() async {
    final prizeItems = _getDefaultPrizeItems();
    await saveCustomPrizePool(prizeItems);
  }

  List<PrizeItem> _getDefaultPrizeItems() {
    return [
      PrizeItem(id: 'int_10', name: '10积分', type: 'points', value: 10, probability: 0.3),
      PrizeItem(id: 'int_20', name: '20积分', type: 'points', value: 20, probability: 0.25),
      PrizeItem(id: 'int_50', name: '50积分', type: 'points', value: 50, probability: 0.2),
      PrizeItem(id: 'int_100', name: '100积分', type: 'points', value: 100, probability: 0.15),
      PrizeItem(id: 'int_200', name: '200积分', type: 'points', value: 200, probability: 0.07),
      PrizeItem(id: 'int_500', name: '500积分', type: 'points', value: 500, probability: 0.03),
    ];
  }

  Future<int> insertScratchTicket(ScratchTicket ticket) async {
    return await _dbService.insertScratchTicket(ticket);
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
