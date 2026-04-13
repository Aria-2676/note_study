import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/shop_provider.dart';
import '../../../providers/points_provider.dart';
import '../../../data/models/shop/shop_model.dart';
import '../../../data/models/scratch/scratch_model.dart';
import '../../../core/services/database_service.dart';

class ScratchCardPage extends StatefulWidget {
  const ScratchCardPage({super.key});

  @override
  State<ScratchCardPage> createState() => _ScratchCardPageState();
}

class _ScratchCardPageState extends State<ScratchCardPage> {
  bool _isScratching = false;
  bool _isRevealed = false;
  Offset? _lastPosition;
  final GlobalKey _scratchKey = GlobalKey();
  final List<Offset> _scratchPoints = [];
  PrizeItem? _currentPrize;
  List<PrizeItem> _customPrizePool = [];
  List<LotteryRecord> _lotteryRecords = [];
  bool _showPrizePool = false;
  bool _showRecords = false;
  int _selectedCost = 10;
  final List<int> _costOptions = [10, 20, 50];
  int? _currentRecordId;

  @override
  void initState() {
    super.initState();
    _loadCustomPrizePool();
    _loadLotteryRecords();
  }

  Future<void> _loadCustomPrizePool() async {
    final shopProvider = Provider.of<ShopProvider>(context, listen: false);
    final pool = await DatabaseService.instance.getCustomPrizePool();
    List<PrizeItem> prizeItems = [];

    if (pool.isEmpty) {
      for (final item in shopProvider.shopItems) {
        prizeItems.add(PrizeItem.fromShopItem(item));
      }
      await DatabaseService.instance.saveCustomPrizePool(prizeItems);
    } else {
      for (final item in pool) {
        prizeItems.add(PrizeItem.fromMap(item));
      }
    }

    setState(() {
      _customPrizePool = prizeItems;
    });
  }

  Future<void> _loadLotteryRecords() async {
    try {
      final records = await DatabaseService.instance.getLotteryRecords();
      setState(() {
        _lotteryRecords = records;
      });
    } catch (e) {
      // ignore
    }
  }

  Future<void> _saveLotteryRecord() async {
    final prize = _currentPrize;
    if (prize == null) return;

    try {
      if (_currentRecordId != null) {
        final record = LotteryRecord(
          id: _currentRecordId,
          drawTime: DateTime.now(),
          prizeName: prize.name,
          prizeType: prize.type,
          prizeValue: prize.value,
          costPoints: _selectedCost,
        );
        await DatabaseService.instance.updateLotteryRecord(record);
      } else {
        final record = LotteryRecord(
          drawTime: DateTime.now(),
          prizeName: prize.name,
          prizeType: prize.type,
          prizeValue: prize.value,
          costPoints: _selectedCost,
        );
        await DatabaseService.instance.insertLotteryRecord(record);
      }
      await _loadLotteryRecords();
    } catch (e) {
      // ignore
    }
  }

  Future<void> _deleteLotteryRecord(int id) async {
    try {
      final affectedRows = await DatabaseService.instance.deleteLotteryRecord(id);
      if (affectedRows == 0) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('删除失败，记录不存在')));
        }
      } else {
        await _loadLotteryRecords();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('删除失败: ${e.toString()}')));
      }
    }
  }

  Future<void> _startScratch(PointsProvider pointsProvider) async {
    if (_isScratching || _isRevealed) {
      if (_isRevealed) {
        _resetScratchCard();
      }
      return;
    }

    if (pointsProvider.currentPoints < _selectedCost) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('积分不足，需要$_selectedCost积分才能抽奖'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认抽奖'),
        content: Text('确定要消耗$_selectedCost积分进行刮刮乐抽奖吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('确认'),
          ),
        ],
      ),
    );

    if (confirmed != true) {
      return;
    }

    try {
      await pointsProvider.deductPoints(_selectedCost);

      final tempRecord = LotteryRecord(
        drawTime: DateTime.now(),
        prizeName: '未刮开',
        prizeType: 'unknown',
        prizeValue: 0,
        costPoints: _selectedCost,
      );
      final recordId = await DatabaseService.instance.insertLotteryRecordWithId(tempRecord);
      setState(() {
        _currentRecordId = recordId;
      });

      final prize = _drawPrize();
      setState(() {
        _currentPrize = prize;
        _isScratching = true;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('抽奖失败: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
      if (_currentRecordId != null) {
        try {
          await DatabaseService.instance.deleteLotteryRecord(_currentRecordId!);
        } catch (deleteEx) {
          // ignore
        }
      }
    }
  }

  List<PrizeItem> _getCompletePrizePool() {
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
      final exists = prizes.any((p) => p.id == prize.id);
      if (!exists) {
        prizes.add(prize);
      }
    }

    return prizes;
  }

  PrizeItem _drawPrize() {
    final prizes = _getCompletePrizePool();
    final probabilities = _calculateProbabilities(prizes, _selectedCost);
    final random = Random();
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

  List<double> _calculateProbabilities(List<PrizeItem> prizes, int cost) {
    final List<double> weights = [];
    final bonusMultiplier = cost / 10.0;

    for (final prize in prizes) {
      final weight = _calculateInverseWeight(prize.value, bonusMultiplier);
      weights.add(weight);
    }

    final totalWeight = weights.fold(0.0, (sum, w) => sum + w);
    return weights.map((w) => w / totalWeight).toList();
  }

  double _calculateInverseWeight(int value, [double bonusMultiplier = 1.0]) {
    final safeMultiplier = bonusMultiplier <= 0 ? 1.0 : bonusMultiplier;
    final adjustedValue = value / safeMultiplier;
    return 1.0 / (adjustedValue * 0.1 + 1);
  }

  void _handleScratch(DragUpdateDetails details) {
    if (!_isScratching || _isRevealed) return;

    final box = _scratchKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;

    final position = box.globalToLocal(details.globalPosition);
    setState(() {
      _scratchPoints.add(position);
      _lastPosition = position;
    });

    _checkReveal();
  }

  void _checkReveal() {
    if (_scratchPoints.length > 50) {
      setState(() {
        _isRevealed = true;
        _isScratching = false;
      });
      _saveLotteryRecord();
      _claimPrize();
    }
  }

  Future<void> _claimPrize() async {
    final prize = _currentPrize;
    if (prize == null) return;

    final pointsProvider = Provider.of<PointsProvider>(context, listen: false);
    final shopProvider = Provider.of<ShopProvider>(context, listen: false);

    try {
      if (prize.type == 'integral') {
        await pointsProvider.addPoints(prize.value);
      } else if (prize.type == 'goods') {
        final items = shopProvider.shopItems.where((i) => i.name == prize.name);
        if (items.isEmpty) {
          throw Exception('商品不存在');
        }
        final item = items.first;
        if (item.id == null) {
          throw Exception('商品ID为空');
        }
        final purchasedItem = PurchasedItem(
          shopItemId: item.id!,
          name: item.name,
          description: item.description,
          price: item.price,
          iconName: item.iconName,
          colorValue: item.colorValue,
        );
        await shopProvider.addPurchasedItem(purchasedItem);
      }
    } catch (e) {
      try {
        await pointsProvider.addPoints(_selectedCost);
      } catch (addEx) {
        // ignore
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('奖品发放失败，已退回积分: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _resetScratchCard() {
    setState(() {
      _isScratching = false;
      _isRevealed = false;
      _scratchPoints.clear();
      _lastPosition = null;
      _currentPrize = null;
      _currentRecordId = null;
    });
  }

  void _togglePrizePool() {
    setState(() {
      _showPrizePool = !_showPrizePool;
      _showRecords = false;
    });
  }

  void _toggleRecords() {
    setState(() {
      _showRecords = !_showRecords;
      _showPrizePool = false;
    });
  }

  Future<void> _updatePrizePool(bool add, PrizeItem prize) async {
    setState(() {
      if (add) {
        _customPrizePool.add(prize);
      } else {
        _customPrizePool.removeWhere((p) => p.id == prize.id);
      }
    });
    await DatabaseService.instance.saveCustomPrizePool(_customPrizePool);
  }

  @override
  Widget build(BuildContext context) {
    final pointsProvider = Provider.of<PointsProvider>(context);
    final shopProvider = Provider.of<ShopProvider>(context);
    final availableItems = shopProvider.shopItems
        .where((item) => !_customPrizePool.any((p) => p.id == item.id.toString()))
        .map((item) => PrizeItem.fromShopItem(item))
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('刮刮乐'),
        centerTitle: true,
        backgroundColor: const Color(0xFFFF6B6B),
      ),
      body: SingleChildScrollView(
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
              Container(
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
              ),
              const SizedBox(height: 30),

              Container(
                key: _scratchKey,
                width: 300,
                height: 200,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: Colors.grey.shade300),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withValues(alpha: 30),
                      blurRadius: 10,
                    ),
                  ],
                ),
                child: Stack(
                  children: [
                    _buildPrizeContent(),
                    if (!_isRevealed && _currentPrize != null)
                      _buildScratchOverlay(),
                    if (_currentPrize == null)
                      const Center(
                        child: Text(
                          '点击下方按钮开始抽奖',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 30),

              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(15),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withValues(alpha: 10),
                      blurRadius: 10,
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    const Text(
                      '选择抽奖档位',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Color(0xFFFF6B6B),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: _costOptions
                          .map((cost) => Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 8),
                                child: ElevatedButton(
                                  onPressed: () => setState(() => _selectedCost = cost),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: _selectedCost == cost
                                        ? const Color(0xFFFF6B6B)
                                        : Colors.grey.shade200,
                                    foregroundColor: _selectedCost == cost
                                        ? Colors.white
                                        : Colors.black,
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 24, vertical: 12),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                  ),
                                  child: Text('$cost积分'),
                                ),
                              ))
                          .toList(),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '当前选择: $_selectedCost积分档位',
                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              ElevatedButton(
                onPressed: () => _startScratch(pointsProvider),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF6B6B),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 60, vertical: 16),
                  textStyle: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                  shadowColor: Colors.red.withValues(alpha: 30),
                  elevation: 8,
                ),
                child: Text(_isRevealed ? '再来一次' : '开始刮奖'),
              ),
              const SizedBox(height: 20),

              _buildProbabilityInfo(),
              const SizedBox(height: 20),

              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton(
                    onPressed: _togglePrizePool,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _showPrizePool
                          ? const Color(0xFFFF6B6B)
                          : Colors.grey.shade200,
                      foregroundColor: _showPrizePool ? Colors.white : Colors.black,
                    ),
                    child: const Text('自定义抽奖池'),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton(
                    onPressed: _toggleRecords,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _showRecords
                          ? const Color(0xFFFF6B6B)
                          : Colors.grey.shade200,
                      foregroundColor: _showRecords ? Colors.white : Colors.black,
                    ),
                    child: const Text('抽奖记录'),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              if (_showPrizePool) _buildPrizePoolEditor(availableItems),
              if (_showRecords) _buildLotteryRecords(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPrizeContent() {
    if (_currentPrize == null) {
      return const SizedBox();
    }

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
            _currentPrize!.type == 'integral' ? Icons.star : Icons.card_giftcard,
            size: 64,
            color: Colors.amber,
          ),
          const SizedBox(height: 16),
          Text(
            _currentPrize!.name,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1B5E20),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _currentPrize!.type == 'integral' ? '积分奖励' : '商品奖励',
            style: const TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildScratchOverlay() {
    return GestureDetector(
      onPanUpdate: _handleScratch,
      child: CustomPaint(
        painter: ScratchPainter(_scratchPoints, _lastPosition),
        size: const Size(300, 200),
      ),
    );
  }

  Widget _buildProbabilityInfo() {
    final prizes = _getCompletePrizePool();
    final probabilities = _calculateProbabilities(prizes, _selectedCost);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(color: Colors.grey.withValues(alpha: 10), blurRadius: 10),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '📊 概率说明',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: Color(0xFFFF6B6B),
            ),
          ),
          const SizedBox(height: 8),
          const Text('• 概率基于奖品积分价值计算（负相关）'),
          const Text('• 价值越高的奖品，抽取概率越低'),
          const SizedBox(height: 8),
          const Text('• 积分奖励档位：5/10/20/30/50/100积分'),
          const SizedBox(height: 8),
          Text('• 当前档位: $_selectedCost积分（档位越高，高价值奖品概率越大）'),
          const SizedBox(height: 12),
          const Text(
            '当前抽奖池奖品概率分布:',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Column(
            children: List.generate(prizes.length, (index) {
              final prize = prizes[index];
              final probability = probabilities[index];
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(prize.name),
                    Text('${(probability * 100).toStringAsFixed(1)}%'),
                  ],
                ),
              );
            }),
          ),
          const SizedBox(height: 12),
          const Text('🎯 算法说明:', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text('• 权重公式: weight = 1 / (value * 0.1 + 1)'),
          const Text('• 概率 = 物品权重 / 所有权重总和'),
          const Text('• 所有奖品概率总和 = 100%'),
        ],
      ),
    );
  }

  Widget _buildPrizePoolEditor(List<PrizeItem> availableItems) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(color: Colors.grey.withValues(alpha: 10), blurRadius: 10),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '🎁 自定义抽奖池',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: Color(0xFFFF6B6B),
            ),
          ),
          const SizedBox(height: 12),
          const Text('已添加的奖品:'),
          const SizedBox(height: 8),
          _customPrizePool.isEmpty
              ? const Text('暂无奖品，请从下方添加', style: TextStyle(color: Colors.grey))
              : Column(
                  children: _customPrizePool
                      .map((prize) => ListTile(
                            title: Text(prize.name),
                            subtitle: Text('价值: ${prize.value}积分'),
                            trailing: IconButton(
                              icon: const Icon(Icons.remove_circle, color: Colors.red),
                              onPressed: () => _updatePrizePool(false, prize),
                            ),
                          ))
                      .toList(),
                ),
          const SizedBox(height: 12),
          const Text('可添加的商品:'),
          const SizedBox(height: 8),
          availableItems.isEmpty
              ? const Text('所有商品已添加', style: TextStyle(color: Colors.grey))
              : Column(
                  children: availableItems
                      .map((prize) => ListTile(
                            title: Text(prize.name),
                            subtitle: Text('价格: ${prize.value}积分'),
                            trailing: IconButton(
                              icon: const Icon(Icons.add_circle, color: Colors.green),
                              onPressed: () => _updatePrizePool(true, prize),
                            ),
                          ))
                      .toList(),
                ),
          const SizedBox(height: 8),
          const Text(
            '• 积分奖励(10/20/30/50/100积分)已默认加入抽奖池',
            style: TextStyle(color: Colors.grey, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildLotteryRecords() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(color: Colors.grey.withValues(alpha: 10), blurRadius: 10),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '📝 抽奖记录',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: Color(0xFFFF6B6B),
            ),
          ),
          const SizedBox(height: 12),
          _lotteryRecords.isEmpty
              ? const Text('暂无抽奖记录', style: TextStyle(color: Colors.grey))
              : Column(
                  children: _lotteryRecords
                      .map((record) => ListTile(
                            leading: Icon(
                              record.prizeType == 'integral' ? Icons.star : Icons.card_giftcard,
                              color: record.prizeType == 'integral' ? Colors.amber : Colors.green,
                            ),
                            title: Text(record.prizeName),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '消耗: ${record.costPoints}积分 | 获得: ${record.prizeValue}积分价值',
                                  style: const TextStyle(fontSize: 12),
                                ),
                                Text(
                                  _formatDateTime(record.drawTime.toIso8601String()),
                                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                                ),
                              ],
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () {
                                if (record.id != null) {
                                  _deleteLotteryRecord(record.id!);
                                } else {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('记录ID异常，无法删除')),
                                  );
                                }
                              },
                            ),
                          ))
                      .toList(),
                ),
          const SizedBox(height: 12),
          if (_lotteryRecords.isNotEmpty)
            ElevatedButton(
              onPressed: () async {
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('确认清空'),
                    content: const Text('确定要清空所有抽奖记录吗？'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(ctx).pop(false),
                        child: const Text('取消'),
                      ),
                      ElevatedButton(
                        onPressed: () => Navigator.of(ctx).pop(true),
                        child: const Text('确认'),
                      ),
                    ],
                  ),
                );
                if (confirmed == true) {
                  try {
                    final affectedRows =
                        await DatabaseService.instance.deleteAllLotteryRecords();
                    if (affectedRows >= 0) {
                      await _loadLotteryRecords();
                    } else {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('清空失败')));
                      }
                    }
                  } catch (_) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('清空失败')),
                      );
                    }
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.grey.shade200,
                foregroundColor: Colors.black,
              ),
              child: const Text('清空所有记录'),
            ),
        ],
      ),
    );
  }

  String _formatDateTime(String dateTimeString) {
    final dateTime = DateTime.parse(dateTimeString);
    return '${dateTime.month}月${dateTime.day}日 ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
}

class ScratchPainter extends CustomPainter {
  final List<Offset> points;
  final Offset? lastPosition;

  ScratchPainter(this.points, this.lastPosition);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.grey.shade300
      ..style = PaintingStyle.fill;

    canvas.drawRect(Offset.zero & size, paint);

    final clearPaint = Paint()
      ..blendMode = BlendMode.clear
      ..strokeWidth = 30
      ..strokeCap = StrokeCap.round;

    if (points.length == 1) {
      canvas.drawCircle(points[0], 15, clearPaint);
    } else {
      for (int i = 1; i < points.length; i++) {
        canvas.drawLine(points[i - 1], points[i], clearPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant ScratchPainter oldDelegate) {
    return points.length != oldDelegate.points.length ||
        lastPosition != oldDelegate.lastPosition;
  }
}