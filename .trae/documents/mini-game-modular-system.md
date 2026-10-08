# 小游戏模块化系统 + 基础优化 实施方案

## Context

当前 `lib/modules/games/` 里的 2048 是**编译进包的 Dart 代码**（3 个文件），游戏中心硬编码一个 2048 卡片 + 两个"敬请期待"占位。用户希望小游戏**模块化、按需下载**，不固定在包内。

**Flutter release 是 AOT 编译，Dart 无运行时 eval、无官方动态代码加载**，因此"下载一段 Dart/Flutter 代码再运行"不可行。经确认采用业界标准做法：**内置通用 WebView 容器 + 外置 HTML5 游戏包**。游戏下载解压到应用私有目录后，由容器从本地加载，**完全离线可玩**（仅下载/更新需联网）。

已确认的产品决策：
- 计费：**按游戏配单价，进入即扣，中途退出不退还**
- 托管：游戏 zip + manifest 提交进 GitHub 仓库，走 **jsDelivr CDN** 分发（base 可用 `--dart-define` 覆盖）
- 首发：2048 转 HTML5，**移除 Dart 版**
- 附带工作流：基础优化（性能/规范/UI/测试）、缺陷审查迭代、文档更新 + 推送 origin

已排除：Android Play Feature Delivery（Flutter 支持差 + 仅 Play 分发有效，本项目侧载 APK）。

---

## 三个硬阻塞前置项（必须先做，否则功能必然失败）

已逐条实测确认：

| # | 问题 | 证据 | 处理 |
|---|---|---|---|
| 1 | **release 包无 INTERNET 权限** | [AndroidManifest.xml](file:///d:/Dev/V5/android/app/src/main/AndroidManifest.xml) 无 INTERNET，仅 [debug manifest](file:///d:/Dev/V5/android/app/src/debug/AndroidManifest.xml) 有 → release 下下载必失败 | main manifest 加 `<uses-permission android:name="android.permission.INTERNET"/>` |
| 2 | **明文回环被拦** | targetSdk=36（≥28），Android 默认禁 cleartext；WebView 加载 `http://127.0.0.1:port` 报 `ERR_CLEARTEXT_NOT_PERMITTED`；`webview_flutter` 未暴露开关 | 新增 `android/app/src/main/res/xml/network_security_config.xml`，仅对 `127.0.0.1`/`localhost` 放行明文（**不要**用全局 `usesCleartextTraffic`），并在 `<application>` 上引用 |
| 3 | minSdk 实为 24 | Flutter 3.47.2 `FlutterExtension.kt:26` → `minSdkVersion = 24` | webview_flutter 4.x 要求 SDK 24+，**刚好满足，无需抬高** |

依赖（`archive` 4.2.0 / `crypto` 3.0.7 已在 lock 中解析，仅 `webview_flutter` 需联网 pub get）。

---

## 阶段一：游戏模块化骨架

新增/改造文件（遵循 rule-3 目录规范，模块自包含）：

```
lib/modules/games/
├── models/
│   ├── game_manifest_model.dart      # 清单 + 单个游戏元数据
│   └── installed_game_model.dart     # 本地已安装状态
├── repositories/
│   ├── game_install_repository.dart  # installed_games.json 索引 + 目录管理
│   └── game_entry_repository.dart    # 原子扣费
├── services/
│   ├── game_asset_server.dart        # 127.0.0.1 静态文件服务
│   ├── game_installer.dart           # 下载/校验/解压
│   └── game_module_service.dart      # 安装/卸载/更新编排
├── utils/
│   ├── game_cdn_config.dart          # CDN base（可 dart-define 覆盖）
│   └── game_version_utils.dart       # 版本三元组比较
├── providers/mixins/ + game_provider.dart
├── adapters/game_statistic_adapter.dart
├── pages/
│   ├── game_center_page.dart         # 改造：可下载列表
│   └── game_host_page.dart           # WebView 容器
└── widgets/
    ├── game_card_widget.dart
    ├── game_download_dialog_widget.dart
    └── game_unsupported_placeholder_widget.dart
```

### 关键设计要点

**1. 本地静态服务**（`game_asset_server.dart`）
用 `dart:io HttpServer.bind(InternetAddress.loopbackIPv4, 0)` 端口自动分配；含 MIME 映射、目录穿越防护（`p.normalize` + `p.relative` 校验不逃出 root）、`start/stop` 生命周期。不用 `loadFile`，因为 `file://` origin 下游戏 `fetch`/`XHR` 子资源会被拦。
生命周期：`initState` 启动、`dispose` 停止；每次端口重分配，**必须用 start 返回的 URI**，不可缓存。

**2. JS Bridge**（`game_host_page.dart`）
`JavaScriptChannel('GameBridge')`，消息 JSON 约定：
- 游戏→Flutter：`ready` / `reportScore` / `getUserInfo` / `exit`
- Flutter→游戏：`userInfo` / `back` / `pause`（`runJavaScript` 注入）
解析失败与未知 type 一律兜底上报，**绝不抛异常**（rule-4）。
导航白名单：只允许 `http://127.0.0.1:<port>/`，阻止跳外网。
返回键用 `PopScope`，先给游戏拦截机会再 pop。

**3. 下载/校验/解压**（`game_installer.dart`）
`HttpClient` 流式下载 + 进度回调；`crypto` 流式 sha256 比对；`archive` 的 `ZipDecoder().decodeStream` 解压，**显式 zip-slip 防护**（绝对路径、`..`、symlink 一律整包拒绝，不用 archive 自带会静默跳过的 `extractFileToDisk`）；解压后断言 `index.html` 存在，再 `Directory.rename` 原子落位到 `games/<id>/<version>/`。
解压 + 哈希放 `Isolate.run`，避免低端机掉帧。

**4. 原子扣费**（`game_entry_repository.dart`）
**模块内实现，不改 core**：注入 `DatabaseGateway`，用 `gateway.transaction` 内 `rawUpdate('UPDATE user_points SET points = points - ? ... WHERE id = ? AND points >= ?')`，`updated == 0` 即余额不足 → **返回 false 且事务内零写入**；成功则同事务写 `points_records`（`type='game_entry'`, `points=-cost`, `relatedId=null`, description 含游戏名）。
与 `database_purchase_mixin.dart` 的 `purchaseShopItem`/`purchaseScratchTicket` 保持同一范式。

**5. 已安装索引：文件式 JSON（不用 sqflite 新表）**
`<ApplicationSupport>/games/installed_games.json`，原子写（写 `.tmp` 再 rename），损坏时扫描目录重建。
理由：① 真实源是文件系统，DB 无法与磁盘写入同事务，索引只作缓存可自愈；② 建表要动 core 的 schema/迁移/`clearAllData`/备份白名单，违反 rule-3 模块独立性；③ 游戏数量个位数，无聚合查询需求。

**6. Provider 注册**
`main.dart` 用 `ChangeNotifierProxyProvider<PointsProvider, GameProvider>`（照 `ShopProvider` 写法），注册在 `PointsProvider` 之后。

**7. 平台守卫**
`WebViewPlatform.instance` 在无实现平台（Windows 桌面）为 null，**必须在构造 `WebViewController` 之前**用 `defaultTargetPlatform` 拦截，降级为 `GameUnsupportedPlaceholder`。三处都要守：页面入口、下载/安装、服务启动。

**8. 统计**（rule-2）
`statistic_data.dart` 的 `StatisticKeys` **附加** Games 段：`page_view_games_center`、`click_games_download`、`click_games_launch`、`count_games_installed`、`count_games_points_spent`、`count_games_score`。适配器 `GameStatisticAdapter extends BaseStatisticAdapter`，照 `scratch_statistic_adapter.dart` 写法。

**9. 移除 Dart 版 2048**
删除 `lib/modules/games/game_2048/**`（3 文件）。影响面已核实：仅 `game_center_page.dart` import 它；`Game2048Provider` 未全局注册、无路由、无测试 → 低风险。
**最高分迁移**：沿用既有 SharedPreferences key `game_2048_best_score`，由 Flutter 侧持有并通过 bridge 的 `userInfo` 下发给游戏、通过 `reportScore` 回收持久化 → **老用户记录零丢失，无需迁移**。

---

## 阶段二：2048 HTML5 包 + CDN 发布链路

1. **编写 HTML5 2048**：自包含 `game_center/src/game_2048/`（`index.html` + `js` + `css` + 图标），实现 4×4 棋盘、滑动/方向键、分数、游戏结束、重开、响应式；接入 bridge：加载后发 `ready`，结束时发 `reportScore`，提供"退出"按钮发 `exit`；最高分从 `userInfo` 读取。
2. **打包脚本**：`tool/build_game_package.ps1` → 生成 `game_center/packages/game_2048_v1.0.0.zip`，计算 sha256，输出/更新 `game_center/manifest.json`。
3. **manifest schema**（`game_center/manifest.json`）：
```json
{
  "schemaVersion": 1,
  "updatedAt": "...",
  "games": [{
    "id": "2048", "name": "2048", "description": "经典数字合成游戏",
    "icon": "grid_on", "color": "#FF9800", "cost": 10,
    "latestVersion": "1.0.0",
    "package": { "path": "game_center/packages/game_2048_v1.0.0.zip",
                 "sha256": "...", "sizeBytes": 184320 },
    "entry": "index.html"
  }]
}
```
4. **CDN 策略**：manifest 走可变地址 `{base}/game_center/manifest.json`（默认 `https://cdn.jsdelivr.net/gh/Aria-2676/note_study@main`，jsDelivr 对 branch 缓存约 12h，可用 purge 接口刷新）；zip 走 **commit-SHA 不可变地址**（发布时注入 `--dart-define=GAME_CDN_SHA_BASE=...@<sha>`），保证"同名文件不被换内容"，使 sha256 校验有意义。
5. **发布流程**：得先 `git push`（当前本地领先 origin **8 个 commit 未推送**）。zip 随仓库提交，无需 Release、无需登录额外账号。
6. **国内可用性**：jsDelivr 在部分运营商可能超时。实现**有序回退 base 列表**（jsDelivr → 备用），全部失败时明确提示"离线可玩已下载的游戏"，不卡死报错。备选 Gitee raw 或对象存储。

---

## 阶段三：基础优化

- **性能与启动**：核查 `main()` 初始化串行 await 链（`WidgetService` / `StatisticService` / 番茄钟服务 / SettingsProvider）是否有可延迟项；确认月份缓存 LRU、SQL 索引命中。
- **代码规范合规**：复查 rule-1~6 符合度（Provider 职责隔离、非 Widget 层禁 listen:true、ProxyProvider update 不写业务、文件/类/方法行数上限、注释规范）。
- **UI/交互细节**：空态、错误提示、加载态、动画一致性。
- **测试覆盖补强**：补齐薄弱模块单测，目标覆盖率 ≥70%（rule-5）。

## 阶段四：缺陷审查迭代

对核心业务（任务结算可逆、积分原子性、番茄钟、回收站、备份恢复、循环任务）做一轮系统审查，列可疑点清单 → 逐条确认 → 修复 + 补回归测试。

## 阶段五：文档更新 + 推送

- 补写当前架构文档（mixin 拆分、db v3、结算可逆、游戏模块化）
- `git push origin main`（含既有 8 个 commit）

---

## 验证方案

**自动化**（本地终端，沙盒无法跑 flutter）：
```powershell
cd D:\Dev\V5
flutter pub get
dart analyze          # 期望 No issues found
flutter test          # 期望全绿
flutter build apk --debug
```

**新增测试**（rule-5）：

| 测试文件 | 覆盖点 |
|---|---|
| `test/models/game_manifest_model_test.dart` | 缺字段/类型错误/默认值/entry 校验 |
| `test/utils/game_version_utils_test.dart` | 版本三元组比较、`1.10.0 > 1.9.9`、非法串兜底 |
| `test/services/game_installer_test.dart` | sha256 一致/不一致、zip-slip 必抛、父目录创建 |
| `test/services/game_asset_server_test.dart` | 真起服务：`/../../etc/passwd`→403、MIME、404、stop 后不可连 |
| `test/repositories/game_entry_repository_test.dart` | 余额足则扣分+写流水；**余额不足返回 false 且两表零变化**（用 `sqflite_common_ffi` 真 SQL） |
| `test/services/game_module_service_test.dart` | 索引读写、损坏 JSON 重建、版本比对、卸载清目录 |
| `test/adapters/game_statistic_adapter_test.dart` | 照 `scratch_statistic_adapter_test.dart` 的 should-not-throw 风格 |

**设备人工验证**（OPPO Android 11）：
1. 游戏中心显示 2048 可下载（含大小、单价）
2. 下载 → 进度 → 安装完成 → 启动进入游戏
3. **飞行模式下仍可玩**（验证离线）
4. 积分不足时拒绝入场并提示，且积分与流水**无变化**
5. 入场后积分正确扣减、流水出现 `game_entry`
6. 卸载后目录与索引清理干净；再次下载可重装
7. 返回键、退出按钮、游戏结束后最高分持久化（关 App 重进仍在）
8. Windows 桌面构建下游戏入口显示"该平台暂不支持"

---

## 风险清单

| 风险 | 缓解 |
|---|---|
| jsDelivr 国内超时 | 回退 base 列表 + 明确离线提示；备选 Gitee/对象存储 |
| WebView 加载大音频无 Range 支持 | 简易服务不实现 206，2048 无音频可接受；后续需大音频再补 |
| 游戏脚本伪造高分 | manifest 下发随机 token 校验来源 + `reportScore` 增幅上限校验 |
| Windows 桌面不支持 WebView | 构造前平台守卫，降级占位页 |
| 新增 INTERNET 权限的隐私影响 | 仅用于游戏包下载，manifest 中说明；不放宽全局 cleartext |
| 全局 dbVersion 若再 bump | 本方案**不改 dbVersion**（索引走文件式），避免迁移风险 |

## 待定/可后置项

- **`points_records.related_key TEXT` 列**：现 `relatedId` 是 `int?`，游戏 id 是字符串，无法按游戏维度聚合消费。可后置单独一次提交加 v3→v4 迁移（`ALTER TABLE ADD COLUMN` + 索引），本轮为控制范围**暂不做**，先用 `description` 记录游戏名。