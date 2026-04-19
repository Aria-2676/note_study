import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../providers/shop_provider.dart';
import '../../../providers/points_provider.dart';
import '../../../providers/scratch_provider.dart';
import '../models/scratch_model.dart';
import '../models/scratch_state.dart';
import '../adapters/scratch_statistic_adapter.dart';
import './mixins/scratch_card_logic_mixin.dart';
import './widgets/ticket_wallet_widget.dart';
import './widgets/lottery_records_widget.dart';
import './widgets/prize_pool_editor_widget.dart';
import './widgets/probability_info_widget.dart';
import './widgets/cost_selector_widget.dart';
import './widgets/scratch_action_buttons_widget.dart';
import './widgets/points_display_widget.dart';
import './widgets/scratch_card_widget.dart';

class ScratchCardPage extends StatefulWidget {
  const ScratchCardPage({super.key});

  @override
  State<ScratchCardPage> createState() => _ScratchCardPageState();
}

class _ScratchCardPageState extends State<ScratchCardPage>
    with WidgetsBindingObserver, ScratchCardLogicMixin {
  final GlobalKey _scratchKey = GlobalKey();
  final List<Offset> _scratchPoints = [];
  final ScratchStatisticAdapter _statisticAdapter = ScratchStatisticAdapter();
  Offset? _lastPosition;
  bool _showPrizePool = false;
  bool _showRecords = false;
  bool _showTicketWallet = false;

  static const int _gridSize = 30;
  static const double _revealThreshold = 0.4;
  static const double _scratchRadius = 20;
  static const double _minSwipeDistance = 3.0;

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
      _scratchPoints.clear();
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

  void _startScratching() {
    final scratchProvider = Provider.of<ScratchProvider>(
      context,
      listen: false,
    );
    if (scratchProvider.currentTicket == null) return;
    setState(() {
      _scratchPoints.clear();
      _lastPosition = null;
    });
    scratchProvider.startScratching();
    _statisticAdapter.reportStartScratch();
    HapticFeedback.mediumImpact();
  }

  void _exitScratching() {
    final scratchProvider = Provider.of<ScratchProvider>(
      context,
      listen: false,
    );
    _scratchPoints.clear();
    _lastPosition = null;
    scratchProvider.exitScratching();
  }

  void _handleScratchStart(DragStartDetails details) {
    _handleScratchPosition(details.globalPosition);
  }

  void _handleScratch(DragUpdateDetails details) {
    _handleScratchPosition(details.globalPosition);
  }

  void _handleScratchEnd(DragEndDetails details) {
    _lastPosition = null;
  }

  void _handleScratchPosition(Offset globalPosition) {
    final scratchProvider = Provider.of<ScratchProvider>(
      context,
      listen: false,
    );
    if (!scratchProvider.state.isScratching) return;

    final box = _scratchKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;

    final position = box.globalToLocal(globalPosition);

    if (position.dx < 0 ||
        position.dx > box.size.width ||
        position.dy < 0 ||
        position.dy > box.size.height) {
      return;
    }

    if (_lastPosition != null) {
      final distance = (position - _lastPosition!).distance;
      if (distance < _minSwipeDistance) return;
    }

    setState(() {
      _scratchPoints.add(position);
      _lastPosition = position;
    });

    _checkReveal();
  }

  double _calculateScratchedPercentage() {
    if (_scratchPoints.isEmpty) return 0.0;

    final box = _scratchKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return 0.0;

    final size = box.size;
    final cellWidth = size.width / _gridSize;
    final cellHeight = size.height / _gridSize;

    final grid = List.generate(
      _gridSize,
      (_) => List.generate(_gridSize, (_) => false),
    );

    final radiusCells = (_scratchRadius / cellWidth).ceil();

    for (final point in _scratchPoints) {
      final centerGridX = (point.dx / cellWidth).floor();
      final centerGridY = (point.dy / cellHeight).floor();

      for (int dx = -radiusCells; dx <= radiusCells; dx++) {
        for (int dy = -radiusCells; dy <= radiusCells; dy++) {
          final gridX = (centerGridX + dx).clamp(0, _gridSize - 1);
          final gridY = (centerGridY + dy).clamp(0, _gridSize - 1);

          final cellCenterX = (gridX + 0.5) * cellWidth;
          final cellCenterY = (gridY + 0.5) * cellHeight;
          final distance = sqrt(
            pow(point.dx - cellCenterX, 2) + pow(point.dy - cellCenterY, 2),
          );

          if (distance <= _scratchRadius) {
            grid[gridY][gridX] = true;
          }
        }
      }
    }

    int scratchedCount = 0;
    for (final row in grid) {
      for (final cell in row) {
        if (cell) scratchedCount++;
      }
    }

    return scratchedCount / (_gridSize * _gridSize);
  }

  void _checkReveal() {
    final percentage = _calculateScratchedPercentage();
    if (percentage >= _revealThreshold) {
      _revealPrize();
    }
  }

  void _revealPrize() {
    final scratchProvider = Provider.of<ScratchProvider>(
      context,
      listen: false,
    );
    if (!scratchProvider.state.isScratching) return;

    scratchProvider.revealPrize();
    scratchProvider.saveLotteryResult();
    _claimPrize();
  }

  void _quickReveal() {
    final scratchProvider = Provider.of<ScratchProvider>(
      context,
      listen: false,
    );
    if (!scratchProvider.state.isScratching) return;

    _revealPrize();
  }

  Future<void> _claimPrize() async {
    final scratchProvider = Provider.of<ScratchProvider>(
      context,
      listen: false,
    );
    final pointsProvider = Provider.of<PointsProvider>(context, listen: false);
    final shopProvider = Provider.of<ShopProvider>(context, listen: false);

    await claimPrize(
      context: context,
      scratchProvider: scratchProvider,
      pointsProvider: pointsProvider,
      shopProvider: shopProvider,
    );
  }

  void _resetScratchCard() {
    final scratchProvider = Provider.of<ScratchProvider>(
      context,
      listen: false,
    );
    setState(() {
      _scratchPoints.clear();
      _lastPosition = null;
    });
    scratchProvider.resetScratchCard();
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
                          onStartScratch: _startScratching,
                          onClose: () {
                            setState(() {
                              _showTicketWallet = false;
                            });
                          },
                          onSelectTicket: _selectTicket,
                        ),
                      if (!_showTicketWallet) ...[
                        ScratchCardWidget(
                          scratchKey: _scratchKey,
                          ticket: scratchProvider.currentTicket,
                          isScratching: scratchProvider.state.isScratching,
                          isRevealed: scratchProvider.state.isRevealed,
                          scratchPoints: _scratchPoints,
                          onPanStart: _handleScratchStart,
                          onPanUpdate: _handleScratch,
                          onPanEnd: _handleScratchEnd,
                        ),
                        const SizedBox(height: 20),
                        if (isScratching) ...[
                          _buildExitButton(colorScheme),
                          const SizedBox(height: 8),
                          _buildQuickRevealButton(scratchProvider, colorScheme),
                        ],
                        if (scratchProvider.state.isRevealed)
                          _buildContinueButton(colorScheme),
                        if (!isScratching &&
                            !scratchProvider.state.isRevealed &&
                            scratchProvider.currentTicket != null)
                          _buildStartScratchButton(colorScheme),
                        const SizedBox(height: 20),
                        CostSelectorWidget(
                          scratchProvider: scratchProvider,
                          onCostChanged: _setCost,
                        ),
                        const SizedBox(height: 20),
                        _buildMainButton(
                          pointsProvider,
                          scratchProvider,
                          colorScheme,
                        ),
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
              if (isScratching)
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
            ],
          ),
        );
      },
    );
  }

  Widget _buildExitButton(ColorScheme colorScheme) {
    return ElevatedButton.icon(
      onPressed: _exitScratching,
      icon: const Icon(Icons.exit_to_app),
      label: const Text('退出刮奖'),
      style: ElevatedButton.styleFrom(
        backgroundColor: colorScheme.secondary,
        foregroundColor: colorScheme.onSecondary,
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
      ),
    );
  }

  Widget _buildStartScratchButton(ColorScheme colorScheme) {
    return Column(
      children: [
        ElevatedButton.icon(
          onPressed: _startScratching,
          icon: const Icon(Icons.touch_app),
          label: const Text('开始刮奖'),
          style: ElevatedButton.styleFrom(
            backgroundColor: colorScheme.primary,
            foregroundColor: colorScheme.onPrimary,
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(30),
            ),
          ),
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: _resetScratchCard,
          child: Text(
            '取消选择',
            style: TextStyle(
              color: colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildQuickRevealButton(
    ScratchProvider scratchProvider,
    ColorScheme colorScheme,
  ) {
    return TextButton.icon(
      onPressed: _quickReveal,
      icon: const Icon(Icons.visibility),
      label: const Text('一键揭晓'),
      style: TextButton.styleFrom(foregroundColor: colorScheme.primary),
    );
  }

  Widget _buildContinueButton(ColorScheme colorScheme) {
    return ElevatedButton.icon(
      onPressed: _resetScratchCard,
      icon: const Icon(Icons.check_circle),
      label: const Text('继续'),
      style: ElevatedButton.styleFrom(
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
      ),
    );
  }

  Widget _buildMainButton(
    PointsProvider pointsProvider,
    ScratchProvider scratchProvider,
    ColorScheme colorScheme,
  ) {
    final canAfford = scratchProvider.canAfford(pointsProvider.currentPoints);
    final isProcessing = scratchProvider.isProcessing;
    final hasTicket = scratchProvider.currentTicket != null;
    final isRevealed = scratchProvider.state.isRevealed;

    String buttonText;
    if (isRevealed) {
      buttonText = '刮奖完成';
    } else if (hasTicket && !scratchProvider.state.isScratching) {
      buttonText = '已选择彩票，点击开始刮奖';
    } else {
      buttonText = '购买彩票';
    }

    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: (canAfford && !isProcessing && !hasTicket && !isRevealed)
            ? () async {
                final success = await scratchProvider.buyTicket(
                  pointsProvider.currentPoints,
                );
                if (success) {
                  await pointsProvider.deductPointsWithRecord(
                    points: scratchProvider.selectedCost,
                    type: 'scratch_cost',
                    description: '购买刮刮卡',
                  );
                  _startScratching();
                }
              }
            : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
          disabledBackgroundColor: colorScheme.surfaceContainerHighest,
          disabledForegroundColor: colorScheme.onSurface.withValues(
            alpha: 0.38,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
        ),
        child: isProcessing
            ? SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: colorScheme.onPrimary,
                ),
              )
            : Text(
                buttonText,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
      ),
    );
  }
}
