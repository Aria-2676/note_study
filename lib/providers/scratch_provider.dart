import 'dart:math';
import 'package:flutter/material.dart';
import '../modules/scratch/models/scratch_model.dart';
import '../modules/scratch/models/scratch_state.dart';
import '../modules/scratch/models/default_prize_pools.dart';
import '../modules/scratch/repositories/scratch_repository.dart';
import '../modules/scratch/repositories/scratch_free_ticket_repository.dart';
import '../modules/shop/models/shop_model.dart';
import 'points_provider.dart';
import 'shop_provider.dart';

part 'mixins/scratch_provider_core_mixin.dart';
part 'mixins/scratch_prize_pool_mixin.dart';
part 'mixins/scratch_play_mixin.dart';

/// 刮刮乐的状态管理。
///
/// 实现按职责拆分到 `mixins/` 下的 part 文件（同一 library，可共享私有状态）：
/// - [ScratchProviderCoreMixin]：共享状态与基础视图
/// - [ScratchPrizePoolMixin]：抽奖池与概率
/// - [ScratchPlayMixin]：刮奖流程与记录管理
///
/// 默认奖池数据见 `models/default_prize_pools.dart`。
class ScratchProvider extends ChangeNotifier
    with ScratchProviderCoreMixin, ScratchPrizePoolMixin, ScratchPlayMixin {
  static const List<int> costOptions = [10, 20, 50];

  /// 奖项面额上限相对票价的倍数（头奖 = 100 × 票价）。
  static const int maxPrizeValueMultiplier = 100;

  /// 目标返奖率，对齐即开型彩票官方口径
  /// （体彩顶呱刮 / 福彩刮刮乐均为 65%：奖金 65% + 公益金 20% + 发行费 15%）。
  static const double targetReturnRate = 0.65;

  /// 空奖（未中奖）的类型标识。
  static const String noPrizeType = 'none';

  /// 每日免费刮奖固定使用的档位（最低档）。
  ///
  /// 免费机会不跟随用户选中的档位：否则用户选 50 档即可每天白拿期望 32.5 积分，
  /// 变成持续水龙头。
  static const int freeTicketCost = 10;
}
