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

  ScratchState get state => _state;
  List<PrizeItem> get customPrizePool => _customPrizePool;
  List<LotteryRecord> get lotteryRecords => _lotteryRecords;
  List<ScratchTicket> get ticketWallet => _ticketWallet;
  ScratchTicket? get currentTicket => _currentTicket;
  int get selectedCost => _selectedCost;
  bool get isProcessing => _isProcessing;
  String? get errorMessage => _errorMessage;
  int get unscratchedCount =>
      _ticketWallet.where((t) => !t.isRevealed).length;
  
  List<ScratchTicket> get unscratchedTickets =>
      _ticketWallet.where((t) => !t.isRevealed).toList();

  bool canAfford(int userPoints) => userPoints >= _selectedCost;

  List<PrizeItem> get completePrizePool {
    final prizes = _customPrizePool.toList();
    final integralPrizes = [
      PrizeItem(id: 'int_5', name: '5积分', type: 'integral', value: 5),
      PrizeItem(id: 'int_10', name: '10积分', type: 'integral', value: 10),
      PrizeItem(id: 'int_20', name: '20积分', type: 'integral', value: 20),
      PrizeItem(id: 'int_30', name: '30积分', type: 'integral', value: 30),
      PrizeItem(id: 'int_50', name: '50积分', type: 'integral', value: 50),
      PrizeItem(id: 'int_100', name: '100积分', type: 'integral', value: 100),
    ];
    for (final prize in integralPrizes) {
      if (!prizes.any((p) => p.id == prize.id)) {
        prizes.add(prize);
      }
    }
    return prizes;
  }

  Future<void> initialize(List<ShopItem> shopItems) async {
    try {
      await _repository.initializePrizePoolFromShopItems(shopItems);
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
    final prizes = completePrizePool;
    final probabilities = _calculateProbabilities(prizes);
    final random = Random.secure();
    final randomValue = random.nextDouble();

    double cumulative = 0;
    for (int i = 0; i < prizes.length; i++) {
      cumulative += probabilities[i];
      if (randomValue <= cumulative) {
        return prizes[i];
      }
    }
    return prizes.last;
  }

  List<double> _calculateProbabilities(List<PrizeItem> prizes) {
    final weights = <double>[];
    final bonusMultiplier = _selectedCost / 10.0;

    for (final prize in prizes) {
      final adjustedValue = prize.value / bonusMultiplier;
      weights.add(1.0 / (adjustedValue * 0.1 + 1));
    }

    final totalWeight = weights.fold(0.0, (sum, w) => sum + w);
    return weights.map((w) => w / totalWeight).toList();
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
      await _repository.resetPrizePoolToDefault();
      _customPrizePool = await _repository.getCustomPrizePool();
      notifyListeners();
    } catch (e) {
      _errorMessage = '重置抽奖池失败: $e';
      notifyListeners();
    }
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}
