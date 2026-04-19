import 'package:flutter/material.dart';
import '../../../core/services/statistic_service.dart';
import '../../../core/models/statistic_data.dart';

/// 刮刮乐模块统计适配器
/// 封装刮刮乐相关的所有统计上报逻辑
class ScratchStatisticAdapter {
  final StatisticService _service = StatisticService();

  /// 上报刮刮乐页面访问
  Future<void> reportPageViewHome() async {
    try {
      await _service.report(
        StatisticData(
          key: StatisticKeys.pageViewScratchHome,
          type: StatisticType.pageView,
          value: DateTime.now().toUtc().toIso8601String(),
        ),
      );
    } catch (e, stack) {
      debugPrint('Scratch page view report failed: $e\n$stack');
    }
  }

  /// 上报购买彩票点击
  /// [cost] 彩票花费积分
  Future<void> reportBuyTicket(int cost) async {
    try {
      await _service.report(
        StatisticData(
          key: StatisticKeys.clickScratchBuyTicket,
          type: StatisticType.click,
          value: {'cost': cost},
        ),
      );
    } catch (e, stack) {
      debugPrint('Scratch buy ticket report failed: $e\n$stack');
    }
  }

  /// 上报开始刮奖点击
  Future<void> reportStartScratch() async {
    try {
      await _service.report(
        StatisticData(
          key: StatisticKeys.clickScratchStart,
          type: StatisticType.click,
          value: DateTime.now().toUtc().toIso8601String(),
        ),
      );
    } catch (e, stack) {
      debugPrint('Scratch start report failed: $e\n$stack');
    }
  }

  /// 上报中奖计数
  /// [prizeValue] 中奖积分
  /// [prizeType] 奖品类型
  Future<void> reportWin(int prizeValue, String prizeType) async {
    try {
      await _service.report(
        StatisticData(
          key: StatisticKeys.countScratchWin,
          type: StatisticType.count,
          value: {'prizeValue': prizeValue, 'prizeType': prizeType},
        ),
      );
    } catch (e, stack) {
      debugPrint('Scratch win report failed: $e\n$stack');
    }
  }

  /// 上报消耗积分计数
  /// [cost] 消耗积分数量
  Future<void> reportCost(int cost) async {
    try {
      await _service.report(
        StatisticData(
          key: StatisticKeys.countScratchCost,
          type: StatisticType.count,
          value: cost,
        ),
      );
    } catch (e, stack) {
      debugPrint('Scratch cost report failed: $e\n$stack');
    }
  }

  /// 上报彩票夹访问
  Future<void> reportPageViewWallet() async {
    try {
      await _service.report(
        StatisticData(
          key: StatisticKeys.pageViewScratchWallet,
          type: StatisticType.pageView,
          value: DateTime.now().toUtc().toIso8601String(),
        ),
      );
    } catch (e, stack) {
      debugPrint('Scratch wallet page view report failed: $e\n$stack');
    }
  }

  /// 上报抽奖记录访问
  Future<void> reportPageViewRecords() async {
    try {
      await _service.report(
        StatisticData(
          key: StatisticKeys.pageViewScratchRecords,
          type: StatisticType.pageView,
          value: DateTime.now().toUtc().toIso8601String(),
        ),
      );
    } catch (e, stack) {
      debugPrint('Scratch records page view report failed: $e\n$stack');
    }
  }
}
