import 'dart:math';
import 'package:flutter/material.dart';
import '../modules/scratch/models/scratch_model.dart';
import '../modules/scratch/models/scratch_state.dart';
import '../modules/scratch/models/default_prize_pools.dart';
import '../modules/scratch/repositories/scratch_repository.dart';
import '../modules/shop/models/shop_model.dart';

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

  static const int maxPrizeValueMultiplier = 10;
}
