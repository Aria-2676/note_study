# 从 V5 原地更新到 V6：可行性评估

结论：**技术上能，而且不需要新写更新器**。V5 已经在用一套完整的
「检查清单 → 下载 APK → 拉起系统安装器」链路，发一个新包就会被它装上。
但有 **两个必须补的洞**，其中一个会让用户升完发现任务全没了。

评估时间：2026-10-27。基于当前 `main`（`ffbcb8a` + 本轮未提交改动）。

---

## 一、已经具备的（不用开发）

| 能力 | 现状 | 位置 |
|---|---|---|
| 检查更新 | 拉 `update.json`（jsDelivr 多节点 → raw → GitHub API 兜底） | `lib/core/updater/services/app_update_service.dart` |
| 版本判定 | 语义化比较，主版本变化默认弹窗，支持强制更新 `minSupported` | `.../app_update_decider.dart` |
| 下载 | 多源回退 + sha256 + 大小校验，失败换源 | `.../app_update_launcher.dart`、`core/services/multi_source_downloader.dart` |
| 安装 | 下载到 cache → FileProvider → 系统安装器 | 同上 + `AndroidManifest.xml` 的 `REQUEST_INSTALL_PACKAGES`、`FileProvider` |
| 分发 | GitHub Releases（APK 超 20MB，不走 jsDelivr，已实测 403） | `update.json` 顶部注释有完整踩坑记录 |

也就是说：**用户当前的 5.5.26 就是这么装上去的**，这条路已经跑通。

## 二、四个硬条件（逐条核对）

| 条件 | 状态 | 说明 |
|---|---|---|
| 包名相同 | ✅ `com.noteapp.taskmaster` | 覆盖安装，不会并存两个 App |
| 签名相同 | ✅ 有 `android/key.properties`，keystore 在仓库外 | 必须用**同一把钥匙**构建，否则 `INSTALL_FAILED_UPDATE_INCOMPATIBLE` |
| 安装权限 | ✅ 已声明 + FileProvider 已配 | Android 8+ 首次会要求用户允许"安装未知应用" |
| versionCode 递增 | ⚠️ **需要改** | 见下 |

### versionCode 是唯一可能卡住安装的点

`pubspec.yaml` 现在是 `version: 5.5.26+0`，也就是 **versionCode = 0**。
Android 只认整数版本号，新包必须严格大于旧包才能覆盖。

发 V6 时把版本写成 `6.0.0+6000`（或任何 ≥1 的数）。这一步没做的话，
表现是"下载完成 → 安装失败 → 用户以为是包坏了"，而且错误提示不会说明原因。

> 无法从代码判断历史发布包用的是多少 —— 如果以前用 `--build-number` 覆盖过，
> 需要看一眼已发布 APK 的实际值。给一个明显大的数最稳。

## 三、洞一：数据不会跟过来（必须补）

v5 用 `v5_tasks.db`，v6 用 `v6_tasks.db`（刻意分库，避免 v6 误读 v5 结构）。
覆盖安装后 v5 的库**还在**，但 v6 完全不看它 —— 用户看到的是**一个空的任务列表**。

### 好消息：结构差异极小

| v5 表 | v6 表 | 处理 |
|---|---|---|
| `tasks`（13 列） | `tasks`（12 列） | 11 列同名直搬；`estimated_minutes` 补 null；丢弃 `reward_points` / `is_deducted` |
| `recycled_tasks`（15 列） | `recycled_tasks`（16 列） | 直搬；`tag_ids` 补 null（任务已删，关联已级联清掉） |
| `tags` | `tags` | 同构直搬（`name` 有 UNIQUE，冲突时保留旧 id） |
| `task_tags` | `task_tags` | 同构直搬 |
| `settings` | `settings` | **不搬**。v5 是 camelCase（`themeMode` / `taskCreateMode`），v6 是 `ui.*`，两边语义也不同（v6 的字段开关、编辑形态是 v5 没有的概念）。用 v6 默认值更干净 |

### 不迁移的表（属于已移出主包的能力）

`shop_items` / `user_points` / `points_records` / `purchased_items` /
`custom_prize_pool` / `lottery_records` / `pomodoro_records` / `pomodoro_settings`

这些在 v6 里分别是商城、刮刮乐、番茄钟插件的数据。**v5 库保留不删**，
将来看插件要不要做一次性导入。升级时至少要告诉用户一句：
"积分和历史记录还在旧库里，装了对应插件后可以导入"，否则等于默认他丢了东西。

### 迁移实现要点

1. **触发时机**：v6 打开自己的库之后、渲染第一帧之前（迁移完再进首页，避免闪一下空列表）
2. **幂等**：成功后写 `settings['sys.migrated_from_v5'] = <时间戳>`；有这个键就永不重跑
3. **单事务**：要么全进要么全不进，不做"迁了一半"
4. **源库只读打开**：绝不 `UPDATE`/`DELETE` v5 库，也**不删**它
5. **失败不阻断启动**：迁移报错 → 记日志、照常进 v6（空列表），并留一个"从旧版本导入"的手动入口
6. **不覆盖已有数据**：v6 库里已经有任务时跳过（防止重复导入）

## 四、洞二：V6 自己不会更新（发出去就绝版）

`lib/app/` 里没有任何 updater 引用 —— v6 外壳只负责界面。
如果新包的入口直接 `runApp(V6App())`，用户装上之后**再也收不到更新**。

补法很小：入口先建 `AppUpdateProvider`，用 `ChangeNotifierProvider.value` 提供，
再用 `AppUpdatePromptHost` 包住 `MainShell`（v5 的 `main.dart` 就是这么接的）。
`AppUpdatePromptHost` 只依赖 `context.read<AppUpdateProvider>()`，不需要整套 Provider 树。

## 五、实施顺序（每步可单独验收）

| 步 | 内容 | 产出 | 风险 |
|---|---|---|---|
| 1 | 写 `V5Migration`：读 v5 库 → 写 v6 库，事务 + 幂等 + 只读源库 | 纯 Dart 模块，可单测（造一个 v5 结构的库） | 低 |
| 2 | 把更新器接到 v6 入口 | 新包装完还能继续更新 | 低 |
| 3 | 发 `6.0.0+6000`：改 pubspec、`update.json`、GitHub Release | 用户在 V5 里点更新即可 | 中（versionCode / 签名） |

第 1 步是唯一有真实工作量的部分，也是最该先做的 —— 它决定"升级"是"换了个界面"
还是"数据没了"。

## 六、风险清单

- **签名换了就装不上**：构建机换了、keystore 丢了 → 老用户只能卸载重装（数据全丢）。
  发布前必须确认 `key.properties` 指向的是原来那把钥匙。
- **迁移错了没有后悔药**：所以源库不删、迁移前不动源库，出问题最多重装 v5。
- **用户不会主动点更新**：v5 已经有后台检查 + 通知栏提醒，沿用即可。
- **首次启动会慢一点**：迁移几千条任务大约几百毫秒，可以接受；不要在迁移期间弹引导页。
- **降级不可能**：Android 不允许 versionCode 回退，用户要回 v5 只能卸载重装。
  这是"不要求可回退"的代价，需要在更新说明里写清楚。

## 七、需要拍板的三件事

1. **积分 / 商城 / 番茄钟旧数据怎么处理**：
   a) 只留一句提示，插件以后自己导入（推荐，成本最低）
   b) v6 内置一个只读页，显示"你有 N 积分 / M 条番茄记录"
   c) 直接不管
2. **是否保留 v5 库**：建议保留（几十 KB~几 MB），删掉就没有任何退路。
3. **V6 包要不要同时保留 v5 界面入口**：建议不保留，否则两套代码都要维护。
