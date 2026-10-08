import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/shop_provider.dart';
import '../../../providers/points_provider.dart';
import '../../../providers/scratch_provider.dart';
import '../models/scratch_model.dart';
import '../models/scratch_state.dart';
import '../adapters/scratch_statistic_adapter.dart';
import './mixins/scratch_card_logic_mixin.dart';
import './mixins/scratch_card_gesture_mixin.dart';
import './widgets/ticket_wallet_widget.dart';
import './widgets/lottery_records_widget.dart';
import './widgets/prize_pool_editor_widget.dart';
import './widgets/probability_info_widget.dart';
import './widgets/cost_selector_widget.dart';
import './widgets/scratch_action_buttons_widget.dart';
import './widgets/points_display_widget.dart';
import './widgets/scratch_reveal_overlay_widget.dart';
import './widgets/scratch_main_button_widget.dart';

class ScratchCardPage extends StatefulWidget {
  const ScratchCardPage({super.key});

  @override
  State<ScratchCardPage> createState() => _ScratchCardPageState();
}

/// 刮刮乐主页面。
///
/// 各关注点已经拆分（规范 6：单个 Widget ≤300 行）：
/// - 弹窗/购买/中奖发放：[ScratchCardLogicMixin]
/// - 刮奖手势与揭晓：[ScratchCardGestureMixin]
/// - 居中刮奖浮层：[ScratchRevealOverlayWidget]
/// - 主操作按钮：[ScratchMainButtonWidget]
class _ScratchCardPageState extends State<ScratchCardPage>
    with WidgetsBindingObserver, ScratchCardLogicMixin, ScratchCardGestureMixin {
  final ScratchStatisticAdapter _statisticAdapter = ScratchStatisticAdapter();
  bool _showPrizePool = false;
  bool _showRecords = false;
  bool _showTicketWallet = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _statisticAdapter.reportPageViewHome();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeProvider();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _saveCurrentState();
    } else if (state == AppLifecycleState.resumed) {
      _restoreState();
    }
  }

  void _saveCurrentState() {}

  void _restoreState() {
    final provider = Provider.of<ScratchProvider>(context, listen: false);
    if (provider.state.isScratching) {
      scratchPoints.clear();
      provider.exitScratching();
    }
  }

  Future<void> _initializeProvider() async {
    final shopProvider = Provider.of<ShopProvider>(context, listen: false);
    final scratchProvider = Provider.of<ScratchProvider>(
      context,
      listen: false,
    );
    await scratchProvider.initialize(shopProvider.shopItems);
  }

  void _setCost(int cost) {
    final scratchProvider = Provider.of<ScratchProvider>(
      context,
      listen: false,
    );
    scratchProvider.setCost(cost);
  }

  void _selectTicket(ScratchTicket ticket) {
    final scratchProvider = Provider.of<ScratchProvider>(
      context,
      listen: false,
    );
    scratchProvider.selectTicket(ticket);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = colorScheme.brightness == Brightness.dark;

    return Consumer3<PointsProvider, ScratchProvider, ShopProvider>(
      builder: (context, pointsProvider, scratchProvider, shopProvider, _) {
        final isScratching = scratchProvider.state.isScratching;

        return Scaffold(
          appBar: AppBar(
            title: const Text('刮刮乐'),
            centerTitle: true,
            actions: [
              Stack(
                alignment: Alignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.confirmation_num_outlined),
                    onPressed: () {
                      setState(() {
                        _showTicketWallet = !_showTicketWallet;
                        _showPrizePool = false;
                        _showRecords = false;
                      });
                      if (!_showTicketWallet) {
                        _statisticAdapter.reportPageViewWallet();
                      }
                    },
                  ),
                  if (scratchProvider.unscratchedCount > 0)
                    Positioned(
                      right: 8,
                      top: 8,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: colorScheme.error,
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          '${scratchProvider.unscratchedCount}',
                          style: TextStyle(
                            color: colorScheme.onError,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
          body: Stack(
            children: [
              SingleChildScrollView(
                physics: isScratching
                    ? const NeverScrollableScrollPhysics()
                    : const AlwaysScrollableScrollPhysics(),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: isDark
                          ? [
                              colorScheme.surface,
                              colorScheme.surfaceContainerHighest,
                            ]
                          : [
                              colorScheme.primaryContainer.withValues(
                                alpha: 0.3,
                              ),
                              colorScheme.surface,
                            ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      PointsDisplayWidget(
                        currentPoints: pointsProvider.currentPoints,
                      ),
                      const SizedBox(height: 30),
                      if (_showTicketWallet)
                        TicketWalletWidget(
                          scratchProvider: scratchProvider,
                          onStartScratch: startScratching,
                          onClose: () {
                            setState(() {
                              _showTicketWallet = false;
                            });
                          },
                          onSelectTicket: _selectTicket,
                        ),
                      if (!_showTicketWallet) ...[
                        const SizedBox(height: 20),
                        CostSelectorWidget(
                          scratchProvider: scratchProvider,
                          onCostChanged: _setCost,
                        ),
                        const SizedBox(height: 20),
                        _buildMainButton(pointsProvider, scratchProvider),
                        const SizedBox(height: 20),
                        ProbabilityInfoWidget(scratchProvider: scratchProvider),
                        const SizedBox(height: 20),
                        ScratchActionButtonsWidget(
                          scratchProvider: scratchProvider,
                          onTogglePrizePool: () {
                            setState(() {
                              _showPrizePool = !_showPrizePool;
                              _showRecords = false;
                              _showTicketWallet = false;
                            });
                          },
                          onToggleRecords: () {
                            setState(() {
                              _showRecords = !_showRecords;
                              _showPrizePool = false;
                              _showTicketWallet = false;
                            });
                            if (_showRecords) {
                              _statisticAdapter.reportPageViewRecords();
                            }
                          },
                        ),
                        const SizedBox(height: 20),
                        if (_showPrizePool)
                          PrizePoolEditorWidget(
                            scratchProvider: scratchProvider,
                            shopProvider: shopProvider,
                          ),
                        if (_showRecords)
                          LotteryRecordsWidget(
                            scratchProvider: scratchProvider,
                          ),
                      ],
                    ],
                  ),
                ),
              ),
              if (isScratching && !scratchProvider.state.isRevealed)
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      vertical: 8,
                      horizontal: 16,
                    ),
                    color: colorScheme.primaryContainer,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.info_outline,
                          size: 16,
                          color: colorScheme.onPrimaryContainer,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '刮奖模式：滑动刮开遮罩',
                          style: TextStyle(
                            fontSize: 12,
                            color: colorScheme.onPrimaryContainer,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              if (showCenteredOverlay && scratchProvider.currentTicket != null)
                ScratchRevealOverlayWidget(
                  scratchKey: scratchKey,
                  ticket: scratchProvider.currentTicket,
                  isScratching: scratchProvider.state.isScratching,
                  isRevealed: scratchProvider.state.isRevealed,
                  scratchPoints: scratchPoints,
                  onPanStart: handleScratchStart,
                  onPanUpdate: handleScratch,
                  onPanEnd: handleScratchEnd,
                  onExit: exitScratching,
                  onQuickReveal: quickReveal,
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMainButton(
    PointsProvider pointsProvider,
    ScratchProvider scratchProvider,
  ) {
    final canAfford = scratchProvider.canAfford(pointsProvider.currentPoints);
    final isProcessing = scratchProvider.isProcessing;
    final hasTicket = scratchProvider.currentTicket != null;
    final isRevealed = scratchProvider.state.isRevealed;
    final freeAvailable = scratchProvider.freeTicketAvailable;

    String buttonText;
    if (isRevealed) {
      buttonText = '刮奖完成';
    } else if (hasTicket && !scratchProvider.state.isScratching) {
      buttonText = '已选择彩票，点击开始刮奖';
    } else if (freeAvailable) {
      buttonText = '今日免费刮奖（每天 1 次）';
    } else {
      buttonText = '购买彩票';
    }

    return ScratchMainButtonWidget(
      enabled:
          !isProcessing &&
          !hasTicket &&
          !isRevealed &&
          (freeAvailable || canAfford),
      isProcessing: isProcessing,
      buttonText: buttonText,
      onPressed: () async {
        if (freeAvailable) {
          final ok = await scratchProvider.claimFreeTicket();
          if (!mounted) return;
          if (ok) {
            _statisticAdapter.reportFreeTicket();
            startScratching();
          } else {
            final message = scratchProvider.errorMessage;
            if (message != null) {
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text(message)));
            }
          }
          return;
        }
        // 统一走逻辑层的购买入口：含确认弹窗、统计上报与成功提示。
        final success = await buyTicket(
          context: context,
          scratchProvider: scratchProvider,
          pointsProvider: pointsProvider,
        );
        if (success && mounted) {
          startScratching();
        }
      },
    );
  }
}
