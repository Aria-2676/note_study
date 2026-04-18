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
import './mixins/scratch_card_logic_mixin.dart';
import './widgets/ticket_wallet_widget.dart';
import './widgets/lottery_records_widget.dart';
import './widgets/prize_pool_editor_widget.dart';
import './widgets/probability_info_widget.dart';
import './widgets/cost_selector_widget.dart';
import './widgets/scratch_action_buttons_widget.dart';

class ScratchCardPage extends StatefulWidget {
  const ScratchCardPage({super.key});

  @override
  State<ScratchCardPage> createState() => _ScratchCardPageState();
}

class _ScratchCardPageState extends State<ScratchCardPage>
    with WidgetsBindingObserver, ScratchCardLogicMixin {
  final GlobalKey _scratchKey = GlobalKey();
  final List<Offset> _scratchPoints = [];
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
    return Consumer3<PointsProvider, ScratchProvider, ShopProvider>(
      builder: (context, pointsProvider, scratchProvider, shopProvider, _) {
        final isScratching = scratchProvider.state.isScratching;

        return Scaffold(
          appBar: AppBar(
            title: const Text('刮刮乐'),
            centerTitle: true,
            backgroundColor: const Color(0xFFFF6B6B),
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
                    },
                  ),
                  if (scratchProvider.unscratchedCount > 0)
                    Positioned(
                      right: 8,
                      top: 8,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          '${scratchProvider.unscratchedCount}',
                          style: const TextStyle(
                            color: Colors.white,
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
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFFFFE6E6), Color(0xFFFFF5F5)],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      _buildPointsDisplay(pointsProvider),
                      const SizedBox(height: 30),
                      if (_showTicketWallet)
                        TicketWalletWidget(
                          scratchProvider: scratchProvider,
                          onStartScratch: _startScratching,
                          onSelectTicket: _selectTicket,
                        ),
                      if (!_showTicketWallet) ...[
                        _buildScratchCard(scratchProvider),
                        const SizedBox(height: 20),
                        if (isScratching) _buildExitButton(),
                        if (!isScratching &&
                            scratchProvider.currentTicket != null)
                          _buildStartScratchButton(),
                        if (!isScratching &&
                            scratchProvider.currentTicket == null)
                          _buildQuickRevealButton(scratchProvider),
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
                    color: Colors.orange.shade100,
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.info_outline, size: 16),
                        SizedBox(width: 8),
                        Text('刮奖模式：滑动刮开遮罩', style: TextStyle(fontSize: 12)),
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

  Widget _buildPointsDisplay(PointsProvider pointsProvider) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: Colors.amber.withValues(alpha: 30),
            blurRadius: 10,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.stars, color: Colors.amber, size: 24),
          const SizedBox(width: 10),
          Text(
            '当前积分: ${pointsProvider.currentPoints}',
            style: const TextStyle(
              color: Color(0xFFFF6B35),
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScratchCard(ScratchProvider scratchProvider) {
    final ticket = scratchProvider.currentTicket;
    final isScratching = scratchProvider.state.isScratching;
    final isRevealed = scratchProvider.state.isRevealed;

    return ClipRRect(
      borderRadius: BorderRadius.circular(15),
      child: Container(
        key: _scratchKey,
        width: 300,
        height: 200,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: Colors.grey.shade300),
          boxShadow: [
            BoxShadow(color: Colors.grey.withValues(alpha: 30), blurRadius: 10),
          ],
        ),
        child: Stack(
          children: [
            if (ticket != null) _buildPrizeContent(ticket),
            if (!isRevealed && ticket != null)
              Positioned.fill(
                child: GestureDetector(
                  onPanStart: isScratching ? _handleScratchStart : null,
                  onPanUpdate: isScratching ? _handleScratch : null,
                  onPanEnd: isScratching ? _handleScratchEnd : null,
                  child: ClipPath(
                    clipper: ScratchClipper(_scratchPoints),
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.grey.shade400, Colors.grey.shade300],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.touch_app,
                              size: 48,
                              color: Colors.grey.shade600,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              isScratching ? '刮开这里' : '准备刮奖',
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPrizeContent(ScratchTicket ticket) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: const BoxDecoration(
        color: Color(0xFFE8F5E9),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(15),
          topRight: Radius.circular(15),
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            ticket.prizeType == 'integral' ? Icons.star : Icons.card_giftcard,
            size: 64,
            color: Colors.amber,
          ),
          const SizedBox(height: 16),
          Text(
            ticket.prizeName,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1B5E20),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            ticket.prizeType == 'integral' ? '积分奖励' : '商品奖励',
            style: const TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildExitButton() {
    return ElevatedButton.icon(
      onPressed: _exitScratching,
      icon: const Icon(Icons.exit_to_app),
      label: const Text('退出刮奖'),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
      ),
    );
  }

  Widget _buildStartScratchButton() {
    return Column(
      children: [
        ElevatedButton.icon(
          onPressed: _startScratching,
          icon: const Icon(Icons.touch_app),
          label: const Text('开始刮奖'),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFFF6B6B),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(30),
            ),
          ),
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: _resetScratchCard,
          child: const Text('取消选择', style: TextStyle(color: Colors.grey)),
        ),
      ],
    );
  }

  Widget _buildQuickRevealButton(ScratchProvider scratchProvider) {
    if (!scratchProvider.state.isScratching) return const SizedBox.shrink();

    return TextButton.icon(
      onPressed: _quickReveal,
      icon: const Icon(Icons.visibility),
      label: const Text('一键揭晓'),
      style: TextButton.styleFrom(foregroundColor: const Color(0xFFFF6B6B)),
    );
  }

  Widget _buildMainButton(
    PointsProvider pointsProvider,
    ScratchProvider scratchProvider,
  ) {
    final canAfford = scratchProvider.canAfford(pointsProvider.currentPoints);
    final isProcessing = scratchProvider.isProcessing;
    final hasTicket = scratchProvider.currentTicket != null;

    String buttonText;
    if (hasTicket && !scratchProvider.state.isScratching) {
      buttonText = '已选择彩票，点击开始刮奖';
    } else {
      buttonText = '购买彩票';
    }

    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: (canAfford && !isProcessing && !hasTicket)
            ? () => buyTicket(
                context: context,
                scratchProvider: scratchProvider,
                pointsProvider: pointsProvider,
              )
            : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFFF6B6B),
          disabledBackgroundColor: Colors.grey.shade300,
          foregroundColor: Colors.white,
          disabledForegroundColor: Colors.grey,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
          elevation: canAfford ? 8 : 0,
        ),
        child: Text(
          isProcessing ? '处理中...' : buttonText,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}

class ScratchClipper extends CustomClipper<Path> {
  final List<Offset> points;
  static const double scratchRadius = 20;

  ScratchClipper(this.points);

  @override
  Path getClip(Size size) {
    Path fullPath = Path();
    fullPath.addRect(Rect.fromLTWH(0, 0, size.width, size.height));

    if (points.isEmpty) {
      return fullPath;
    }

    Path scratchPath = Path();
    for (final point in points) {
      scratchPath.addOval(
        Rect.fromCircle(center: point, radius: scratchRadius),
      );
    }

    return Path.combine(PathOperation.difference, fullPath, scratchPath);
  }

  @override
  bool shouldReclip(covariant ScratchClipper oldClipper) {
    return true;
  }
}
