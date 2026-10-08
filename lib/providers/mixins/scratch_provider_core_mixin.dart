part of '../scratch_provider.dart';

/// 刮刮乐的共享状态与基础视图。
///
/// 其余 mixin 都声明 `on ScratchProviderCoreMixin`，从而共享这里的私有字段。
mixin ScratchProviderCoreMixin on ChangeNotifier {
  final ScratchRepository _repository = ScratchRepository();

  /// 每日免费刮奖的领取记录。
  final ScratchFreeTicketRepository _freeTicketRepository =
      ScratchFreeTicketRepository();

  ScratchState _state = ScratchState.idle;
  List<PrizeItem> _customPrizePool = [];
  List<LotteryRecord> _lotteryRecords = [];
  List<ScratchTicket> _ticketWallet = [];
  ScratchTicket? _currentTicket;
  int _selectedCost = 10;
  bool _isProcessing = false;
  bool _freeTicketAvailable = false;
  String? _errorMessage;

  ScratchState get state => _state;
  List<PrizeItem> get customPrizePool => _customPrizePool;
  List<LotteryRecord> get lotteryRecords => _lotteryRecords;
  List<ScratchTicket> get ticketWallet => _ticketWallet;
  ScratchTicket? get currentTicket => _currentTicket;
  int get selectedCost => _selectedCost;
  bool get isProcessing => _isProcessing;

  /// 今日是否还有一次免费刮奖机会。
  bool get freeTicketAvailable => _freeTicketAvailable;
  String? get errorMessage => _errorMessage;
  int get unscratchedCount => _ticketWallet.where((t) => !t.isRevealed).length;

  List<ScratchTicket> get unscratchedTickets =>
      _ticketWallet.where((t) => !t.isRevealed).toList();

  bool canAfford(int userPoints) => userPoints >= _selectedCost;

  Future<void> initialize(List<ShopItem> shopItems) async {
    try {
      // 清理上次会话遗留的已揭晓票据，避免 scratch_tickets 无限增长；
      // 开奖历史保存在 lottery_records 中，不受影响。
      await _repository.deleteRevealedTickets();
      _customPrizePool = await _repository.getCustomPrizePool();
      _lotteryRecords = await _repository.getLotteryRecords();
      _lotteryRecords.sort((a, b) => b.drawTime.compareTo(a.drawTime));
      _ticketWallet = await _repository.getUnscratchedTickets();
      _freeTicketAvailable = await _freeTicketRepository.isFreeAvailable();
      notifyListeners();
    } catch (e) {
      _errorMessage = '初始化失败: $e';
      notifyListeners();
    }
  }

  void setCost(int cost) {
    if (_state.canChangeCost && ScratchProvider.costOptions.contains(cost)) {
      _selectedCost = cost;
      notifyListeners();
    }
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}
