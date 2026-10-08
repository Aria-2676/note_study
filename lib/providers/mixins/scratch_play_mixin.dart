part of '../scratch_provider.dart';

/// 刮奖流程（购票 / 选票 / 开始 / 退出 / 揭晓）与开奖记录、彩票的管理。
mixin ScratchPlayMixin on ScratchProviderCoreMixin, ScratchPrizePoolMixin {
  /// 已结算过的票据 id，用于幂等保护（不重复发奖、也不重复退款）。
  final Set<int> _claimedTicketIds = {};

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

  /// 领取当日免费刮奖机会。
  ///
  /// 固定按**最低档**（[ScratchProvider.freeTicketCost]）抽奖且不扣积分。
  /// 票据的 `costPoints` 记为 0，因此发奖失败退款时不会凭空加分。
  Future<bool> claimFreeTicket() async {
    if (_isProcessing) return false;
    if (!_freeTicketAvailable) return false;
    if (!_state.canStartScratch) return false;

    _isProcessing = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final prize = _drawPrize(cost: ScratchProvider.freeTicketCost);
      final ticket = ScratchTicket(
        costPoints: 0,
        prizeId: prize.id,
        prizeName: prize.name,
        prizeType: prize.type,
        prizeValue: prize.value,
      );

      final ticketId = await _repository.insertScratchTicket(ticket);
      _currentTicket = ticket.copyWith(id: ticketId);
      _ticketWallet = await _repository.getUnscratchedTickets();

      // 票据已入库后再标记已领取：万一标记失败，用户最多多得一次本地福利，
      // 而不是「标记了却没拿到票」。
      await _freeTicketRepository.markUsed();
      _freeTicketAvailable = false;

      _isProcessing = false;
      notifyListeners();
      return true;
    } catch (e) {
      _isProcessing = false;
      _errorMessage = '领取免费刮奖失败: $e';
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

  /// 结算当前票据并发奖。
  ///
  /// 发奖属于业务逻辑，因此放在 Provider 层而非 UI 层：
  /// - 空奖（[ScratchProvider.noPrizeType] 或面额为 0）不发放任何奖励；
  /// - 发放失败时自动退还票款；
  /// - 以票据 id 做幂等保护，同一张票不会二次发放或二次退款。
  Future<ScratchClaimOutcome> claimPrize({
    required PointsProvider pointsProvider,
    required ShopProvider shopProvider,
  }) async {
    final ticket = _currentTicket;
    if (ticket == null) {
      return const ScratchClaimOutcome(
        success: false,
        isWin: false,
        error: '没有待结算的彩票',
      );
    }

    final ticketId = ticket.id;
    if (ticketId == null || _claimedTicketIds.contains(ticketId)) {
      return const ScratchClaimOutcome(
        success: false,
        isWin: false,
        error: '该彩票已结算',
      );
    }

    // 空奖：不发放任何奖励，正常结束。
    if (ticket.prizeType == ScratchProvider.noPrizeType ||
        ticket.prizeValue <= 0) {
      _claimedTicketIds.add(ticketId);
      return const ScratchClaimOutcome(success: true, isWin: false);
    }

    try {
      if (ticket.prizeType == 'goods') {
        final matches = shopProvider.shopItems
            .where((item) => item.name == ticket.prizeName)
            .toList();
        if (matches.isEmpty || matches.first.id == null) {
          throw Exception('商品不存在');
        }
        final item = matches.first;
        await shopProvider.addPurchasedItem(
          PurchasedItem(
            shopItemId: item.id!,
            name: item.name,
            description: item.description,
            price: item.price,
            iconName: item.iconName,
            colorValue: item.colorValue,
          ),
        );
      } else {
        await pointsProvider.addPointsWithRecord(
          points: ticket.prizeValue,
          type: 'scratch_win',
          description: '刮刮乐中奖: ${ticket.prizeName}',
        );
      }
      _claimedTicketIds.add(ticketId);
      return const ScratchClaimOutcome(success: true, isWin: true);
    } catch (e) {
      await _refundTicket(pointsProvider, ticket.costPoints);
      _claimedTicketIds.add(ticketId);
      return ScratchClaimOutcome(
        success: false,
        isWin: false,
        error: e.toString(),
      );
    }
  }

  /// 退还票款（仅在发放失败时调用）。
  Future<void> _refundTicket(PointsProvider pointsProvider, int points) async {
    try {
      await pointsProvider.addPointsWithRecord(
        points: points,
        type: 'scratch_refund',
        description: '刮刮乐退款',
      );
    } catch (_) {
      // 退款本身失败时不再抛出，避免掩盖原始错误。
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
