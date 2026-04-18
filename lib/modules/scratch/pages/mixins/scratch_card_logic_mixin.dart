import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../providers/scratch_provider.dart';
import '../../../../providers/points_provider.dart';
import '../../../../providers/shop_provider.dart';
import '../../../shop/models/shop_model.dart';
import '../../models/scratch_model.dart';
import '../../models/scratch_state.dart';

mixin ScratchCardLogicMixin<T extends StatefulWidget> on State<T> {
  static const int _debounceMs = 500;
  DateTime? _lastTapTime;

  bool isDebounced() {
    final now = DateTime.now();
    if (_lastTapTime != null &&
        now.difference(_lastTapTime!).inMilliseconds < _debounceMs) {
      return true;
    }
    _lastTapTime = now;
    return false;
  }

  Future<bool> showConfirmDialog(BuildContext context, int cost) async {
    return await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => ScaleTransition(
            scale: Tween<double>(begin: 0.8, end: 1.0).animate(
              CurvedAnimation(
                parent: ModalRoute.of(ctx)!.animation!,
                curve: Curves.easeOutBack,
              ),
            ),
            child: AlertDialog(
              title: const Text('确认购买'),
              content: Text('将消耗 $cost 积分购买 1 张刮刮卡，确定吗？'),
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
          ),
        ) ??
        false;
  }

  void showBuySuccessDialog(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('购买成功！彩票已存入彩票夹'),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 2),
      ),
    );
  }

  void showInsufficientPointsDialog(
    BuildContext context,
    int currentPoints,
    int requiredPoints,
  ) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('积分不足，需要$requiredPoints积分才能购买'),
        backgroundColor: Colors.red,
        action: SnackBarAction(
          label: '去获取',
          textColor: Colors.white,
          onPressed: () => Navigator.of(context).pop(),
        ),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<void> buyTicket({
    required BuildContext context,
    required ScratchProvider scratchProvider,
    required PointsProvider pointsProvider,
  }) async {
    if (isDebounced()) return;

    if (!scratchProvider.state.canStartScratch) return;

    if (!scratchProvider.canAfford(pointsProvider.currentPoints)) {
      showInsufficientPointsDialog(
        context,
        pointsProvider.currentPoints,
        scratchProvider.selectedCost,
      );
      return;
    }

    final confirmed = await showConfirmDialog(
      context,
      scratchProvider.selectedCost,
    );
    if (!confirmed) return;

    final success = await scratchProvider.buyTicket(
      pointsProvider.currentPoints,
    );

    if (success && mounted) {
      await pointsProvider.deductPointsWithRecord(
        points: scratchProvider.selectedCost,
        type: 'scratch_cost',
        description: '购买刮刮卡',
      );
      HapticFeedback.mediumImpact();
      // ignore: use_build_context_synchronously
      showBuySuccessDialog(context);
    }
  }

  Future<void> claimPrize({
    required BuildContext context,
    required ScratchProvider scratchProvider,
    required PointsProvider pointsProvider,
    required ShopProvider shopProvider,
  }) async {
    final ticket = scratchProvider.currentTicket;
    if (ticket == null) return;

    try {
      if (ticket.prizeType == 'integral') {
        await pointsProvider.addPointsWithRecord(
          points: ticket.prizeValue,
          type: 'scratch_win',
          description: '刮刮乐中奖: ${ticket.prizeName}',
        );
        if (mounted) {
          // ignore: use_build_context_synchronously
          showPrizeDialog(context, ticket, true);
        }
      } else if (ticket.prizeType == 'goods') {
        final items = shopProvider.shopItems.where(
          (i) => i.name == ticket.prizeName,
        );
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
        if (mounted) {
          // ignore: use_build_context_synchronously
          showPrizeDialog(context, ticket, true);
        }
      }
    } catch (e) {
      await refundPoints(pointsProvider, ticket.costPoints);
      if (mounted) {
        // ignore: use_build_context_synchronously
        showPrizeDialog(context, ticket, false, e.toString());
      }
    }
  }

  Future<void> refundPoints(PointsProvider pointsProvider, int points) async {
    try {
      await pointsProvider.addPointsWithRecord(
        points: points,
        type: 'scratch_refund',
        description: '刮刮乐退款',
      );
    } catch (e) {
      // ignore
    }
  }

  void showPrizeDialog(
    BuildContext context,
    ScratchTicket ticket,
    bool success, [
    String? error,
  ]) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              success ? Icons.celebration : Icons.error_outline,
              size: 64,
              color: success ? Colors.amber : Colors.red,
            ),
            const SizedBox(height: 16),
            Text(
              success ? '恭喜中奖！' : '发放失败',
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            if (success) ...[
              Text(
                ticket.prizeType == 'integral'
                    ? '+${ticket.prizeValue} 积分'
                    : '获得商品：${ticket.prizeName}',
                style: TextStyle(
                  fontSize: 18,
                  color: ticket.prizeType == 'integral'
                      ? Colors.orange
                      : Colors.green,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ] else ...[
              Text(
                '已自动退还 ${ticket.costPoints} 积分',
                style: const TextStyle(color: Colors.grey),
              ),
              if (error != null)
                Text(
                  error,
                  style: const TextStyle(fontSize: 12, color: Colors.red),
                ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );

    if (success) {
      HapticFeedback.heavyImpact();
    }
  }
}
