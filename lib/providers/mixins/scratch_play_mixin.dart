part of '../scratch_provider.dart';

/// 刮奖流程（购票 / 选票 / 开始 / 退出 / 揭晓）与开奖记录、彩票的管理。
mixin ScratchPlayMixin on ScratchProviderCoreMixin, ScratchPrizePoolMixin {
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

      final ticketId = await _repository.purchaseTicket(ticket, _selectedCost);
      // 余额不足：事务内未做任何写入（不会出现「票已出但积分没扣」）
      if (ticketId == null) {
        _isProcessing = false;
        _errorMessage = '积分不足，需要$_selectedCost积分才能购买彩票';
        notifyListeners();
        return false;
      }
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
}
