import 'dart:math';
import 'package:flutter/material.dart';
import '../modules/scratch/models/scratch_model.dart';
import '../modules/scratch/models/scratch_state.dart';
import '../modules/scratch/repositories/scratch_repository.dart';
import '../modules/shop/models/shop_model.dart';

class ScratchProvider extends ChangeNotifier {
  final ScratchRepository _repository = ScratchRepository();

  ScratchState _state = ScratchState.idle;
  List<PrizeItem> _customPrizePool = [];
  List<LotteryRecord> _lotteryRecords = [];
  List<ScratchTicket> _ticketWallet = [];
  ScratchTicket? _currentTicket;
  int _selectedCost = 10;
  bool _isProcessing = false;
  String? _errorMessage;

  static const List<int> costOptions = [10, 20, 50];

  static final Map<int, List<PrizeItem>> _defaultPrizePoolsByCost = {
    10: [
      PrizeItem(
        id: 'default_10_5',
        name: '5积分',
        type: 'integral',
        value: 5,
        weight: 1.0,
        isDefault: true,
      ),
      PrizeItem(
        id: 'default_10_8',
        name: '8积分',
        type: 'integral',
        value: 8,
        weight: 1.0,
        isDefault: true,
      ),
      PrizeItem(
        id: 'default_10_10',
        name: '10积分',
        type: 'integral',
        value: 10,
        weight: 1.0,
        isDefault: true,
      ),
      PrizeItem(
        id: 'default_10_12',
        name: '12积分',
        type: 'integral',
        value: 12,
        weight: 1.0,
        isDefault: true,
      ),
      PrizeItem(
        id: 'default_10_15',
        name: '15积分',
        type: 'integral',
        value: 15,
        weight: 1.0,
        isDefault: true,
      ),
      PrizeItem(
        id: 'default_10_20',
        name: '20积分',
        type: 'integral',
        value: 20,
        weight: 1.0,
        isDefault: true,
      ),
      PrizeItem(
        id: 'default_10_30',
        name: '30积分',
        type: 'integral',
        value: 30,
        weight: 1.0,
        isDefault: true,
      ),
      PrizeItem(
        id: 'default_10_50',
        name: '50积分',
        type: 'integral',
        value: 50,
        weight: 1.0,
        isDefault: true,
      ),
      PrizeItem(
        id: 'default_10_80',
        name: '80积分',
        type: 'integral',
        value: 80,
        weight: 1.0,
        isDefault: true,
      ),
      PrizeItem(
        id: 'default_10_100',
        name: '100积分',
        type: 'integral',
        value: 100,
        weight: 1.0,
        isDefault: true,
      ),
    ],
    20: [
      PrizeItem(
        id: 'default_20_10',
        name: '10积分',
        type: 'integral',
        value: 10,
        weight: 1.0,
        isDefault: true,
      ),
      PrizeItem(
        id: 'default_20_15',
        name: '15积分',
        type: 'integral',
        value: 15,
        weight: 1.0,
        isDefault: true,
      ),
      PrizeItem(
        id: 'default_20_20',
        name: '20积分',
        type: 'integral',
        value: 20,
        weight: 1.0,
        isDefault: true,
      ),
      PrizeItem(
        id: 'default_20_25',
        name: '25积分',
        type: 'integral',
        value: 25,
        weight: 1.0,
        isDefault: true,
      ),
      PrizeItem(
        id: 'default_20_30',
        name: '30积分',
        type: 'integral',
        value: 30,
        weight: 1.0,
        isDefault: true,
      ),
      PrizeItem(
        id: 'default_20_50',
        name: '50积分',
        type: 'integral',
        value: 50,
        weight: 1.0,
        isDefault: true,
      ),
      PrizeItem(
        id: 'default_20_80',
        name: '80积分',
        type: 'integral',
        value: 80,
        weight: 1.0,
        isDefault: true,
      ),
      PrizeItem(
        id: 'default_20_100',
        name: '100积分',
        type: 'integral',
        value: 100,
        weight: 1.0,
        isDefault: true,
      ),
      PrizeItem(
        id: 'default_20_150',
        name: '150积分',
        type: 'integral',
        value: 150,
        weight: 1.0,
        isDefault: true,
      ),
      PrizeItem(
        id: 'default_20_200',
        name: '200积分',
        type: 'integral',
        value: 200,
        weight: 1.0,
        isDefault: true,
      ),
    ],
    50: [
      PrizeItem(
        id: 'default_50_20',
        name: '20积分',
        type: 'integral',
        value: 20,
        weight: 1.0,
        isDefault: true,
      ),
      PrizeItem(
        id: 'default_50_30',
        name: '30积分',
        type: 'integral',
        value: 30,
        weight: 1.0,
        isDefault: true,
      ),
      PrizeItem(
        id: 'default_50_40',
        name: '40积分',
        type: 'integral',
        value: 40,
        weight: 1.0,
        isDefault: true,
      ),
      PrizeItem(
        id: 'default_50_50',
        name: '50积分',
        type: 'integral',
        value: 50,
        weight: 1.0,
        isDefault: true,
      ),
      PrizeItem(
        id: 'default_50_80',
        name: '80积分',
        type: 'integral',
        value: 80,
        weight: 1.0,
        isDefault: true,
      ),
      PrizeItem(
        id: 'default_50_100',
        name: '100积分',
        type: 'integral',
        value: 100,
        weight: 1.0,
        isDefault: true,
      ),
      PrizeItem(
        id: 'default_50_150',
        name: '150积分',
        type: 'integral',
        value: 150,
        weight: 1.0,
        isDefault: true,
      ),
      PrizeItem(
        id: 'default_50_200',
        name: '200积分',
        type: 'integral',
        value: 200,
        weight: 1.0,
        isDefault: true,
      ),
      PrizeItem(
        id: 'default_50_300',
        name: '300积分',
        type: 'integral',
        value: 300,
        weight: 1.0,
        isDefault: true,
      ),
      PrizeItem(
        id: 'default_50_500',
        name: '500积分',
        type: 'integral',
        value: 500,
        weight: 1.0,
        isDefault: true,
      ),
    ],
  };

  List<PrizeItem> get defaultPrizePool {
    return _defaultPrizePoolsByCost[_selectedCost] ??
        _defaultPrizePoolsByCost[10]!;
  }

  ScratchState get state => _state;
  List<PrizeItem> get customPrizePool => _customPrizePool;
  List<LotteryRecord> get lotteryRecords => _lotteryRecords;
  List<ScratchTicket> get ticketWallet => _ticketWallet;
  ScratchTicket? get currentTicket => _currentTicket;
  int get selectedCost => _selectedCost;
  bool get isProcessing => _isProcessing;
  String? get errorMessage => _errorMessage;
  int get unscratchedCount => _ticketWallet.where((t) => !t.isRevealed).length;

  List<ScratchTicket> get unscratchedTickets =>
      _ticketWallet.where((t) => !t.isRevealed).toList();

  bool canAfford(int userPoints) => userPoints >= _selectedCost;

  List<PrizeItem> get completePrizePool {
    return [...defaultPrizePool, ..._customPrizePool];
  }

  double get expectedReturnValue {
    return _selectedCost.toDouble();
  }

  static const int maxPrizeValueMultiplier = 10;

  bool canAddToPrizePool(PrizeItem prize) {
    return prize.value <= _selectedCost * maxPrizeValueMultiplier;
  }

  List<PrizeItem> get availablePrizePool {
    final maxAllowedValue = _selectedCost * maxPrizeValueMultiplier;
    return completePrizePool.where((p) => p.value <= maxAllowedValue).toList();
  }

  Map<PrizeItem, double> getPrizeProbabilities() {
    final prizes = availablePrizePool;
    if (prizes.isEmpty) return {};

    final weights = <PrizeItem, double>{};
    for (final prize in prizes) {
      weights[prize] = 1.0 / prize.value.toDouble();
    }

    final totalWeight = weights.values.fold(0.0, (sum, w) => sum + w);

    final result = <PrizeItem, double>{};
    for (final entry in weights.entries) {
      result[entry.key] = entry.value / totalWeight;
    }

    return result;
  }

  Future<void> initialize(List<ShopItem> shopItems) async {
    try {
      _customPrizePool = await _repository.getCustomPrizePool();
      _lotteryRecords = await _repository.getLotteryRecords();
      _lotteryRecords.sort((a, b) => b.drawTime.compareTo(a.drawTime));
      _ticketWallet = await _repository.getUnscratchedTickets();
      notifyListeners();
    } catch (e) {
      _errorMessage = '初始化失败: $e';
      notifyListeners();
    }
  }

  void setCost(int cost) {
    if (_state.canChangeCost && costOptions.contains(cost)) {
      _selectedCost = cost;
      notifyListeners();
    }
  }

  Future<bool> buyTicket(int userPoints) async {
    if (_isProcessing) return false;
    if (!_state.canStartScratch) return false;

    if (!canAfford(userPoints)) {
      _errorMessage = '积分不足，需要$_selectedCost积分才能购买彩票';
      notifyListeners();
      return false;
    }

    _isProcessing = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final prize = _drawPrize();
      final ticket = ScratchTicket(
        costPoints: _selectedCost,
        prizeId: prize.id,
        prizeName: prize.name,
        prizeType: prize.type,
        prizeValue: prize.value,
      );

      final ticketId = await _repository.insertScratchTicket(ticket);
      _currentTicket = ticket.copyWith(id: ticketId);
      _ticketWallet = await _repository.getUnscratchedTickets();

      _isProcessing = false;
      notifyListeners();
      return true;
    } catch (e) {
      _isProcessing = false;
      _errorMessage = '购买失败: $e';
      notifyListeners();
      return false;
    }
  }

  void selectTicket(ScratchTicket ticket) {
    if (_state != ScratchState.idle) return;
    _currentTicket = ticket;
    notifyListeners();
  }

  void startScratching() {
    if (_currentTicket == null) return;
    _state = ScratchState.scratching;
    notifyListeners();
  }

  void exitScratching() {
    _state = ScratchState.idle;
    notifyListeners();
  }

  PrizeItem _drawPrize() {
    final probabilities = getPrizeProbabilities();

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

  void revealPrize() {
    if (_state.isScratching && _currentTicket != null) {
      _state = ScratchState.revealed;
      _currentTicket = _currentTicket!.copyWith(isRevealed: true);
      notifyListeners();
    }
  }

  Future<void> saveLotteryResult() async {
    if (_currentTicket == null) return;

    try {
      await _repository.updateScratchTicket(_currentTicket!);

      final record = LotteryRecord(
        drawTime: DateTime.now(),
        prizeName: _currentTicket!.prizeName,
        prizeType: _currentTicket!.prizeType,
        prizeValue: _currentTicket!.prizeValue,
        costPoints: _currentTicket!.costPoints,
      );
      await _repository.insertLotteryRecord(record);

      _lotteryRecords = await _repository.getLotteryRecords();
      _lotteryRecords.sort((a, b) => b.drawTime.compareTo(a.drawTime));
      _ticketWallet = await _repository.getUnscratchedTickets();
      notifyListeners();
    } catch (e) {
      _errorMessage = '保存记录失败: $e';
      notifyListeners();
    }
  }

  void resetScratchCard() {
    _state = ScratchState.idle;
    _currentTicket = null;
    _errorMessage = null;
    notifyListeners();
  }

  Future<void> deleteRecord(int id) async {
    try {
      await _repository.deleteLotteryRecord(id);
      _lotteryRecords = await _repository.getLotteryRecords();
      _lotteryRecords.sort((a, b) => b.drawTime.compareTo(a.drawTime));
      notifyListeners();
    } catch (e) {
      _errorMessage = '删除失败: $e';
      notifyListeners();
    }
  }

  Future<void> clearAllRecords() async {
    try {
      await _repository.deleteAllLotteryRecords();
      _lotteryRecords = [];
      notifyListeners();
    } catch (e) {
      _errorMessage = '清空失败: $e';
      notifyListeners();
    }
  }

  Future<void> deleteTicket(int id) async {
    try {
      await _repository.deleteScratchTicket(id);
      _ticketWallet = await _repository.getUnscratchedTickets();
      if (_currentTicket?.id == id) {
        _currentTicket = null;
      }
      notifyListeners();
    } catch (e) {
      _errorMessage = '删除彩票失败: $e';
      notifyListeners();
    }
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

  Future<void> updatePrizeWeight(String prizeId, double newWeight) async {
    final index = _customPrizePool.indexWhere((p) => p.id == prizeId);
    if (index != -1) {
      _customPrizePool[index] = _customPrizePool[index].copyWith(
        weight: newWeight,
      );
      await _repository.saveCustomPrizePool(_customPrizePool);
      notifyListeners();
    }
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}
