import 'scratch_model.dart';

/// 各档位（10 / 20 / 50 积分）的默认奖池数据。
///
/// 设计对齐真实即开型彩票（返奖率固定 65%）：
/// - 每档含一个空奖「谢谢参与」（`value == 0`），承载未中奖结果；
/// - 奖项面额随票价**等比放大**（20 档 = 10 档 ×2，50 档 = ×5），
///   因此三档的中奖率一致，只是头奖金额随票价放大；
/// - `weight` 表示「相对稀有度」，实际概率由抽奖池按目标返奖率反解，
///   头奖权重设得极小（千分之一量级）以保证极低中奖率。
///
/// 按 10 档口径：Σweight ≈ 8.3，中奖率 ≈ 24.4%，
/// 返奖率恒为 65%，头奖概率约 0.003%（约 1/34000）。
///
/// 从 scratch_provider.dart 抽出（规范 6：单文件 ≤500 行）。这块数据量大且与业务
/// 逻辑无关，单独成文件更便于查阅与维护。
final Map<int, List<PrizeItem>> defaultPrizePoolsByCost = {
  10: [
    PrizeItem(
      id: 'none_10',
      name: '谢谢参与',
      type: 'none',
      value: 0,
      weight: 1.0,
      isDefault: true,
    ),
    PrizeItem(
      id: 'default_10_10',
      name: '10积分',
      type: 'integral',
      value: 10,
      weight: 2.0,
      isDefault: true,
    ),
    PrizeItem(
      id: 'default_10_20',
      name: '20积分',
      type: 'integral',
      value: 20,
      weight: 3.0,
      isDefault: true,
    ),
    PrizeItem(
      id: 'default_10_30',
      name: '30积分',
      type: 'integral',
      value: 30,
      weight: 2.0,
      isDefault: true,
    ),
    PrizeItem(
      id: 'default_10_50',
      name: '50积分',
      type: 'integral',
      value: 50,
      weight: 1.0,
      isDefault: true,
    ),
    PrizeItem(
      id: 'default_10_100',
      name: '100积分',
      type: 'integral',
      value: 100,
      weight: 0.3,
      isDefault: true,
    ),
    PrizeItem(
      id: 'default_10_1000',
      name: '1000积分(头奖)',
      type: 'integral',
      value: 1000,
      weight: 0.001,
      isDefault: true,
    ),
  ],
  20: [
    PrizeItem(
      id: 'none_20',
      name: '谢谢参与',
      type: 'none',
      value: 0,
      weight: 1.0,
      isDefault: true,
    ),
    PrizeItem(
      id: 'default_20_20',
      name: '20积分',
      type: 'integral',
      value: 20,
      weight: 2.0,
      isDefault: true,
    ),
    PrizeItem(
      id: 'default_20_40',
      name: '40积分',
      type: 'integral',
      value: 40,
      weight: 3.0,
      isDefault: true,
    ),
    PrizeItem(
      id: 'default_20_60',
      name: '60积分',
      type: 'integral',
      value: 60,
      weight: 2.0,
      isDefault: true,
    ),
    PrizeItem(
      id: 'default_20_100',
      name: '100积分',
      type: 'integral',
      value: 100,
      weight: 1.0,
      isDefault: true,
    ),
    PrizeItem(
      id: 'default_20_200',
      name: '200积分',
      type: 'integral',
      value: 200,
      weight: 0.3,
      isDefault: true,
    ),
    PrizeItem(
      id: 'default_20_2000',
      name: '2000积分(头奖)',
      type: 'integral',
      value: 2000,
      weight: 0.001,
      isDefault: true,
    ),
  ],
  50: [
    PrizeItem(
      id: 'none_50',
      name: '谢谢参与',
      type: 'none',
      value: 0,
      weight: 1.0,
      isDefault: true,
    ),
    PrizeItem(
      id: 'default_50_50',
      name: '50积分',
      type: 'integral',
      value: 50,
      weight: 2.0,
      isDefault: true,
    ),
    PrizeItem(
      id: 'default_50_100',
      name: '100积分',
      type: 'integral',
      value: 100,
      weight: 3.0,
      isDefault: true,
    ),
    PrizeItem(
      id: 'default_50_150',
      name: '150积分',
      type: 'integral',
      value: 150,
      weight: 2.0,
      isDefault: true,
    ),
    PrizeItem(
      id: 'default_50_250',
      name: '250积分',
      type: 'integral',
      value: 250,
      weight: 1.0,
      isDefault: true,
    ),
    PrizeItem(
      id: 'default_50_500',
      name: '500积分',
      type: 'integral',
      value: 500,
      weight: 0.3,
      isDefault: true,
    ),
    PrizeItem(
      id: 'default_50_5000',
      name: '5000积分(头奖)',
      type: 'integral',
      value: 5000,
      weight: 0.001,
      isDefault: true,
    ),
  ],
};