# 刮刮乐重做方案（对齐真实彩票模型）

## Context

刮刮乐当前"交互逻辑和概率算法都不行"。经代码核查，这不是手感问题，而是**存在多个确定性缺陷**，其中最严重的是**概率算法在数值上错误**，会把积分经济刷穿：

- [scratch_prize_pool_mixin.dart](file:///d:/Dev/V5/lib/providers/mixins/scratch_prize_pool_mixin.dart#L29-L46) 把权重硬算为 `1/value` 再归一化。由此可推出 `概率_i × 价值_i` 对每个奖项恒等，于是**期望回报 = 奖项数 ÷ Σ(1/价值)**，与票价无关。

实算三档默认奖池：

| 票价 | 期望回报 | 回报率 |
|---|---|---|
| 10 | ≈ 14.3 | **143%** |
| 20 | ≈ 29.1 | **145%** |
| 50 | ≈ 59.6 | **119%** |

即**每档都稳赚**，玩家可无限刷积分，商城与积分体系失去意义。

其他已确认缺陷：

1. **`PrizeItem.weight` 完全无效**([scratch_model.dart:9](file:///d:/Dev/V5/lib/modules/scratch/models/scratch_model.dart#L9))：`getPrizeProbabilities()` 用 `1/value` 覆盖它。奖池编辑器的权重输入、`updatePrizeWeight()`、`fromShopItem` 的 `100/(price+10)` 全部**不影响抽奖**。
2. **`expectedReturnValue` 返回票价**([第14-16行](file:///d:/Dev/V5/lib/providers/mixins/scratch_prize_pool_mixin.dart#L14-L16))，不是真实期望值，把上面的 bug 藏住了。
3. **购买入口有两条不一致路径**：主按钮 [scratch_card_page.dart:318](file:///d:/Dev/V5/lib/modules/scratch/pages/scratch_card_page.dart#L317-L326) 直接调用 `provider.buyTicket`（**无确认弹窗、无统计上报、无成功提示**）；而带确认弹窗+统计+提示的 [ScratchCardLogicMixin.buyTicket](file:///d:/Dev/V5/lib/modules/scratch/pages/mixins/scratch_card_logic_mixin.dart#L85-L124) **无任何调用方，是死代码**。
4. **发奖逻辑在 UI 层**：[claimPrize](file:///d:/Dev/V5/lib/modules/scratch/pages/mixins/scratch_card_logic_mixin.dart#L126-L191) 直接调用 `PointsProvider` / `ShopProvider` 发放奖品，违反规范 1/3（业务应下沉到 Provider/Service）。
5. `saveLotteryResult()` **未被 await**([gesture:176](file:///d:/Dev/V5/lib/modules/scratch/pages/mixins/scratch_card_gesture_mixin.dart#L168-L178))，记录写入与发奖竞态。
6. `deleteRevealedTickets()` **无调用方**，已揭晓票据永久堆积。
7. `is_scratched` 列**从未参与任何查询**（查询统一用 `is_revealed`），冗余双标记。

**目标**：按真实彩票（即开型）模型重做——**返奖率固定 65%**，引入空奖，概率由系统按奖级结构生成，且用户不改代码就能看懂概率公示。

## 真实彩票基准（官方口径）

| 彩种 | 返奖率 |
|---|---|
| **即开型（刮刮乐/顶呱刮）** | **65%**（奖金 65% + 公益金 20% + 发行费 15%） |
| 双色球（乐透型） | 51% |

因本功能即刮刮乐，取 **65%**。真实刮刮乐的关键性质：**票价越高 → 头奖金额越大，但返奖率三档一致、头奖概率同样极低**。

## 概率模型（核心改动）

对每档票价 `C`，返奖率 `R = 0.65`：

1. 奖池奖项面额随票价**等比放大**（沿用现有默认奖池的"上限 = 10×票价"思路），并**新增空奖「谢谢参与」**（`value = 0`）。
2. 每个非空奖项带一个**相对权重 `w_i`**（`PrizeItem.weight` 真正生效，替代当前写死的 `1/value`）。
3. 归一化得"中奖条件下的分布" `p_i|win = w_i / Σw`，并算 `S = Σ p_i|win · v_i`。
4. **中奖率由返奖率反解**：`q = min(1, R·C / S)`；空奖概率 `= 1 - q`。
5. 最终概率 `p_i = q · p_i|win`。

该式天然满足 `Σ p_i·v_i = R·C`。由于面额与分子分母同时随 `C` 等比缩放，**三档中奖率 `q` 一致、头奖金额随票价放大**，与真实彩票行为吻合。

约束与校验：`q` 需落在合理区间（约 20%~40%），头奖权重设得极小（万分之几）。若 `q` 越界，说明奖池面额结构需调整——由单测断言守住。

**权重 UI 决策**：按"和真实彩票一个逻辑"，概率表由系统生成，**移除用户手调权重的入口**（`updatePrizeWeight` 与编辑器权重输入），改为在概率公示中**只读展示**。自定义奖池的"增删奖品"保留。

## 改动清单

### 1. 概率与奖池（Provider 层）
- [scratch_prize_pool_mixin.dart](file:///d:/Dev/V5/lib/providers/mixins/scratch_prize_pool_mixin.dart)：重写 `getPrizeProbabilities()` 按上式实现（使用 `weight`、支持 `value == 0` 的空奖、按 `R=0.65` 反解 `q`）；`_drawPrize()` 保持按累计概率抽取；删除/修正 `expectedReturnValue`，改为返回真实期望值并新增 `winProbability` 供 UI 展示；移除 `updatePrizeWeight()`。
- [default_prize_pools.dart](file:///d:/Dev/V5/lib/modules/scratch/models/default_prize_pools.dart)：三档各新增「谢谢参与」空奖；按奖级重排面额与权重（头奖极小权重）；保持"面额随票价等比"。

### 2. 发奖下沉 + 空奖处理（Provider/Service 层）
- 把 [scratch_card_logic_mixin.dart](file:///d:/Dev/V5/lib/modules/scratch/pages/mixins/scratch_card_logic_mixin.dart) 的 `claimPrize` 发奖逻辑**下沉**到 `ScratchProvider`（或 `scratch_service.dart`），UI 只负责展示结果。
- **空奖分支**：`prizeType == 'none'` 时不发放任何积分/商品，弹窗文案改为「谢谢参与」，**不再走"恭喜中奖"分支**。
- 发奖幂等：以票据 `is_revealed` 为唯一判据，已揭晓票据不得再次发放。

### 3. 交互一致性
- **统一购买路径**：主按钮改走带确认弹窗的路径（保留确认弹窗 + 统计上报 + 成功提示），消除"死代码 + 无确认"的分裂；[scratch_card_page.dart:317-326](file:///d:/Dev/V5/lib/modules/scratch/pages/scratch_card_page.dart#L317-L326) 与 logic mixin 二选一，**保留 logic mixin 那份并接线**。
- `_revealPrize()` 中 `saveLotteryResult()` 改为 `await`，保证记录与发奖同序。
- 揭晓后调用 `deleteRevealedTickets()`（或设定保留上限），避免 `scratch_tickets` 无限增长。
- 清理 `is_scratched` 的语义歧义：统一以 `is_revealed` 为准，废弃冗余列（仅在迁移代价可接受时删除，否则注释标明废弃）。

### 4. 概率公示（UI）
- [probability_info_widget.dart](file:///d:/Dev/V5/lib/modules/scratch/pages/widgets/probability_info_widget.dart)：删除"权重 = 1 / 价值"的错误说明；新增**空奖行**与**中奖率**展示；期望收益/回报率改为读 provider 计算，修好后应显示约 **65%**。

### 5. 测试（规范 5）
新增/扩展测试，断言：
- 三档返奖率均 ≈ 65%（容差 ±1%）；
- 三档中奖率 `q` 一致且落在 20%~40%；
- 空奖概率 = `1 - q`，且 `value == 0` 不产生除零/inf；
- 头奖概率极低；
- 空奖不发积分/商品；
- 已揭晓票据重复调用不二次发放。

## 验证

```powershell
dart analyze          # 期望 No issues found
flutter test          # 期望全绿（含新增概率/发奖用例）
flutter build apk --debug
```

人工验证：
1. 概率公示页显示返奖率 ≈65%、三档一致、头奖极低。
2. 连续购买同一档位若干次，"谢谢参与"为高频结果；**长期积分不增长**（不再稳赚）。
3. 空奖时不发积分、提示为「谢谢参与」。
4. 购买主流程出现确认弹窗，统计埋点有 `click_scratch_buy_ticket`。
5. 已揭晓票据不再留在彩票夹，且 `scratch_tickets` 不无限增长。

## 影响面与风险

- 仅涉及 `lib/providers/mixins/scratch_*`、`lib/modules/scratch/**`；不改 DB schema（除非废弃 `is_scratched`）。
- 存量数据：已购未刮的票据其奖项是旧算法抽定的，**保持原样即可**，无需迁移。
- 抽奖属商店审核高风险项，本方案的概率公示与"返奖率固定"设计**同时服务于可上架**。