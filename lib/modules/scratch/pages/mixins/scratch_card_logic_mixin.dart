import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../providers/scratch_provider.dart';
import '../../../../providers/points_provider.dart';
import '../../../../providers/shop_provider.dart';
import '../../models/scratch_model.dart';
import '../../models/scratch_state.dart';
import '../../adapters/scratch_statistic_adapter.dart';

mixin ScratchCardLogicMixin<T extends StatefulWidget> on State<T> {
  static const int _debounceMs = 500;
  DateTime? _lastTapTime;
  final ScratchStatisticAdapter _statisticAdapter = ScratchStatisticAdapter();

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

  /// 购买一张刮刮卡，返回是否购买成功。
  ///
  /// 这是**唯一的购买入口**（含确认弹窗与统计上报），由主按钮调用。
  Future<bool> buyTicket({
    required BuildContext context,
    required ScratchProvider scratchProvider,
    required PointsProvider pointsProvider,
  }) async {
    if (isDebounced()) return false;

    if (!scratchProvider.state.canStartScratch) return false;

    if (!scratchProvider.canAfford(pointsProvider.currentPoints)) {
      showInsufficientPointsDialog(
        context,
        pointsProvider.currentPoints,
        scratchProvider.selectedCost,
      );
      return false;
    }

    final confirmed = await showConfirmDialog(
      context,
      scratchProvider.selectedCost,
    );
    if (!confirmed) return false;

    final success = await scratchProvider.buyTicket(
      pointsProvider.currentPoints,
    );

    if (success && mounted) {
      // 扣分已在购买事务内完成，这里只需刷新积分显示。
      // （原实现在这里补扣分，一旦等待期间页面被销毁会被 mounted 判定跳过，
      //   造成「票已入库但积分未扣」的白嫖，因此不再依赖 UI 层扣分。）
      await pointsProvider.reload();
      _statisticAdapter.reportBuyTicket(scratchProvider.selectedCost);
      _statisticAdapter.reportCost(scratchProvider.selectedCost);
      HapticFeedback.mediumImpact();
      // ignore: use_build_context_synchronously
      showBuySuccessDialog(context);
    }
    return success;
  }

  /// 结算并发奖。
  ///
  /// 发奖属于业务逻辑，已下沉到 [ScratchProvider.claimPrize]；
  /// 本方法只负责触发结算与展示结果。
  Future<void> claimPrize({
    required BuildContext context,
    required ScratchProvider scratchProvider,
    required PointsProvider pointsProvider,
    required ShopProvider shopProvider,
  }) async {
    final ticket = scratchProvider.currentTicket;
    if (ticket == null) return;

    final outcome = await scratchProvider.claimPrize(
      pointsProvider: pointsProvider,
      shopProvider: shopProvider,
    );

    if (outcome.isWin) {
      _statisticAdapter.reportWin(ticket.prizeValue, ticket.prizeType);
    }
    if (mounted) {
      // ignore: use_build_context_synchronously
      showPrizeDialog(context, ticket, outcome);
    }
  }

  /// 展示发奖结果：中奖 / 谢谢参与（空奖）/ 发放失败。
  void showPrizeDialog(
    BuildContext context,
    ScratchTicket ticket,
    ScratchClaimOutcome outcome,
  ) {
    final isWin = outcome.isWin;
    final isNoPrize = outcome.success && !outcome.isWin;

    final IconData icon;
    final Color iconColor;
    final String title;
    if (isWin) {
      icon = Icons.celebration;
      iconColor = Colors.amber;
      title = '恭喜中奖！';
    } else if (isNoPrize) {
      icon = Icons.sentiment_dissatisfied;
      iconColor = Colors.grey;
      title = '谢谢参与';
    } else {
      icon = Icons.error_outline;
      iconColor = Colors.red;
      title = '发放失败';
    }

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 64, color: iconColor),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            if (isWin) ...[
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
            ] else if (isNoPrize) ...[
              const Text(
                '这次没有中奖，下次再来～',
                style: TextStyle(color: Colors.grey),
              ),
            ] else ...[
              Text(
                '已自动退还 ${ticket.costPoints} 积分',
                style: const TextStyle(color: Colors.grey),
              ),
              if (outcome.error != null)
                Text(
                  outcome.error!,
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

    if (isWin) {
      HapticFeedback.heavyImpact();
    }
  }
}