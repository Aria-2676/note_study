# CLAUDE.md — 任务管家（V5）

本文件是 **AI 助手在本仓库工作的首要上下文**。读它比读代码快，但它**不替代**权威规范：
架构与编码规则的完整版在 [`docs/重构后项目开发规范.md`](docs/重构后项目开发规范.md)。
两者事实性内容必须一致；若发现冲突，**以代码为准**，并同时修正两份文档。

---

## 0. 一句话概览

Flutter 应用「任务管家」：带积分系统的任务管理 + 番茄钟 + 商城 + 统计 + 小游戏中心。
**纯本地存储、无后端**。内容分发（小游戏包、App 更新包）靠一个公开 GitHub 仓库
经 jsDelivr CDN 分发。发行方式是**自签名分发给小圈子用户**，不上应用商店。

---

## 1. 项目基本盘

| 项 | 值 |
|---|---|
| 仓库 | `D:\Dev\V5`（远程 `Aria-2676/note_study`，分支 `main`） |
| 包名 / applicationId | `v5_app` / `com.noteapp.taskmaster` |
| 平台 | android / ios / linux / macos / web / windows |
| Dart SDK | `^3.11.1` |
| 数据库 | sqflite，`v5_tasks.db`，`AppConfig.dbVersion = 3` |
| 本地缓存 | `SharedPreferences` |
| 规模 | ~208 个 Dart 文件（lib）、47 个测试文件 |

**当前版本**：见 `pubspec.yaml` 的 `version`（形如 `5.5.11+0`）。它与最近的提交号保持一致。

---

## 2. 架构与目录（依赖方向是铁律）

```
lib/
├── core/                     # 基础设施，禁止 import 任何 modules/*
│   ├── config/               # app_config.dart（常量、DB 名/版本）、cdn_bases.dart（CDN 基址唯一来源）
│   ├── errors/               # app_error / error_handler / result
│   ├── models/               # base_model、statistic_data
│   ├── router/               # app_router
│   ├── services/             # database/（按域拆 mixin）、widget_service、statistic_service、file_downloader
│   ├── storage/              # storage_manager
│   ├── updater/              # 更新引擎（models / services / providers / widgets / pages）
│   └── utils/                # version_utils、date_utils、num_utils、string_utils、task_sort_utils…
├── modules/<业务>/           # 业务模块，自成一个世界
│   └── models/ services/ repositories/ providers/ pages/ widgets/ adapters/ utils/
├── providers/  ui/           # 历史位置；新代码优先放模块内
└── main.dart                 # 服务初始化 + MultiProvider + 路由
```

**铁律**：`modules/* → core/*` 单向依赖。**`core` 内出现任何 `modules` 的 import 都是 bug。**

现有模块：`tasks` `points` `shop` `tag` `calendar` `pomodoro` `statistics` `scratch`
`games` `profile` `help` `others`。

**11 个 Provider**（全部在 `main.dart` 的 `MultiProvider` 集中注册）：
`AppStateProvider` `SettingsProvider` `PointsProvider` `TagProvider` `PomodoroProvider`
`ScratchProvider` `StatisticsProvider` `AppUpdateProvider`（无依赖）
`ShopProvider` `GameProvider` `TaskProvider`（依赖 `PointsProvider`，走 `ChangeNotifierProxyProvider`）。

注册顺序要求：**被依赖者在前**。

---

## 3. 构建与验证命令

### 3.1 正常路径（环境健康时）

```bash
flutter pub get
flutter analyze            # 全项目；改到 test/ 也要用它，而不是只分析 lib
flutter test --no-pub --reporter compact
flutter build apk --release
```

### 3.2 ⚠️ 本机环境坑：`flutter analyze` / `test` 可能完全起不来

本机 Dart 运行时**偶发**无法 `CreatePipe`（`ERROR_PIPE_BUSY` 231），
导致 `flutter analyze` / `dart analyze` / `flutter test` / `dart test` **全线启动失败**，
报错落在 `runtime/bin/process_win.cc`。这是**环境问题，不是项目问题**，别去改代码。

**`dart pub get` 不受影响**（它不 spawn 子进程），所以依赖管理始终可用。

判断是否中招：`flutter --version` 若报 `CreateFile failed 231` 即已中招。
处置顺序：**重启电脑 → 排查安全软件/EDR 白名单 → 完全重启 IDE**。

**替代验证（环境坏时用，两条互补）：**

```bash
# ① 静态分析：进程内跑 package:analyzer，不 spawn 子进程
dart "C:/Users/<你>/AppData/Local/Temp/wb_analyze.dart" D:/Dev/V5/lib D:/Dev/V5/test
#    输出形如：FILES=257 ERRORS=0 WARNINGS=0 INFOS=0

# ② 行为自检：最小包替身 + package_config 覆盖层，在纯 Dart VM 跑真实实现
cd /d/Dev/V5 && dart --packages=.dart_tool/wb_pc.json .dart_tool/wb_verify.dart
#    输出末行：RESULT=PASS / RESULT=FAIL
```

- 覆盖层 `wb_pc.json` 把 `flutter` 与 `path_provider` 指向 `.dart_tool/wbshim/` 里的最小替身；
  `wb_verify.dart` 是被 gitignore 的离线自检脚本（不属于项目代码）。
- 这两样都在 `.dart_tool/` 下（已被 gitignore），**不要提交**。
- 完整配方与重建步骤见 skill **`flutter-offline-verification`**；环境坑清单见
  skill **`windows-agent-env-workarounds`**。

**诚实边界**：上述替代验证**覆盖不到平台插件层**（`path_provider`、`open_filex`、
`url_launcher`、`package_info_plus` 相关的 settings/launcher/provider/UI）。
这部分**只有静态分析覆盖**，必须在环境恢复后用 `flutter test` 补测。报告结论时要说清这一点。

---

## 4. 提交规范（强制，极易踩坑）

1. 标题：`V5.<minor>.<patch>: 简短描述`，概括用户可见变化。
2. 正文：中文，写清 **改了什么 / 为什么 / 怎么验证的**。
3. **中文提交信息必须写成 UTF-8 文件，然后 `git commit -F <文件>`。**
   `git commit -m "中文"` 会被控制台编码破坏 —— **禁止使用**。
   提交后 `git cat-file commit HEAD` 字节级回读确认（它不含 `%`，不会被安全过滤器拦）。
4. 暂存用**限定路径**：`git add lib test`，别用 `git add -A`（会混入工具产物）。
5. 提交后把 `pubspec.yaml` 的 `version` 对齐提交号。
6. 一次提交只做一件事。

```bash
# 参考流程
cd /d/Dev/V5
git add lib test
git commit -F "$TEMP/v5_commit_msg.txt"     # 消息文件用 Write 工具写，放 $TEMP，别放仓库
git cat-file commit HEAD | head -20         # 回读校验中文未损坏
git add pubspec.yaml && git commit -F "$TEMP/ver.txt"
```

---

## 5. 内容分发与更新体系（自建、无后端）

托管仓库：**`Aria-2676/note_study`**（公开），经 jsDelivr 镜像分发。

| 路径 | 内容 |
|---|---|
| `game_center/manifest.json` | 小游戏清单 |
| `game_center/packages/*.zip` | 小游戏包 |
| `game_center/src/<id>/index.html` | 小游戏入口 |
| `releases/` | App 安装包（APK 等） |
| `update.json`（**仓库根目录**） | App 更新清单 |

### 5.1 CDN 基址

`lib/core/config/cdn_bases.dart` 是**唯一来源**，游戏包与更新包共用：

- 清单类小文件 → `cdn.jsdelivr.net`
- **大文件（.zip / .apk）→ `gcore.jsdelivr.net` 优先**，回退 `testingcf` → 源站。

> 坑：`cdn.jsdelivr.net` 对 `.zip` / `.apk` 会 **301 跳 `raw.githubusercontent.com`**，
> 该域名在国内常被 reset。所以大文件不要走它。

构建期可用 `--dart-define` 覆盖：
`GAME_CDN_BASE=` / `GAME_CDN_SHA_BASE=`（**变量名沿用旧的，不要改名**，否则构建脚本会失效）。

### 5.2 更新决策（五档）

`AppUpdateDecider` 是**无副作用纯函数**，判定顺序：

1. `minSupported` 高于当前 → **forced**（强制，免疫「跳过」与「关闭通知」）
2. 正式包更高 → **optional**（仅当大版本且未被跳过）或 **available**
3. 只有资源包且 `build` 更高 → **assetsOnly**
4. 否则 → **none**

平台无对应下载目标时**降级**为 `assetsOnly` / `none`，不报错。

### 5.3 关键约定

- **资源包用单调递增整数 `build`，不用版本号**（一天可能重打多次，整数不会撞号）。
- 版本比较必须**数值逐位**（`1.0.10 > 1.0.9`），不能用字符串比较 → 用 `VersionUtils`。
- 下载 URL 只接受 `http` / `https`；**先校验 sha256 再安装/解压**。
- `update.json` 手工维护，自带 `_comment` 说明。改完务必确认非目标平台不会误触发。

> **字段名易错备忘**（以 `app_update_manifest.dart` 为准）：
> `minSupported` 在**顶层**而非 `latest` 内；平台映射键是 **`downloads`**（不是 targets）；
> 大小字段是 **`sizeBytes`**（不是 size）；`notes` 是**数组**；另有可选 `level`
> 与 `schemaVersion` / `updatedAt` / `publishedAt`。

详见 skill **`v5-update-distribution`**。

---

## 6. ⚠️ Android 签名不变量（最高风险项）

**APK 自更新要求更新包与已安装包由同一密钥签名。**
签名不一致 ⇒ `INSTALL_FAILED_UPDATE_INCOMPATIBLE` ⇒ 老用户**只能卸载重装（丢数据）**。

- 密钥库：`D:\Dev\keystore\taskmaster-release.jks`（**刻意放在仓库之外**，因为仓库是公开的）
- 生成脚本：`tool/setup_android_keystore.ps1`（交互式，**需用户自己输入口令**）
- `android/app/build.gradle.kts` 读 `android/key.properties`；缺失时回落 debug 并打印警告
- `.gitignore` 已排除 `key.properties` / `*.jks` / `*.keystore`

**纪律**：
1. **绝不生成、记录、或输出签名口令**（会触发敏感审批，也不该进对话日志）。
   脚本必须让用户在本机终端交互输入。
2. 密钥库与口令丢失 = 不可恢复，必须提醒用户备份到密码管理器。
3. `open_filex` 自带 FileProvider，**App 侧不要再声明重复的 provider**。

---

## 7. 编码纪律（写代码前必读）

1. **行数上限**：文件 500 / 类 300 / 方法 50，超出必须拆（见 skill `dart-large-file-splitting`）。
2. **异常**：禁止空 catch；跨层委托要**转换异常类型**保持调用方 catch 有效；
   解析外部数据用 **fail-soft**（顶层结构错 → 抛；单字段错 → 只丢该字段）。
3. **安全**：URL 白名单、先校验哈希再动作、拒绝 `file:` 等危险 scheme。
4. `notifyListeners()` 只在业务状态真变化时调；高频回调（如进度）要做**去重**，
   否则会 UI 重建风暴。
5. 新增 Provider 前先问「能否并入既有 Provider」。
6. 详细条款见 `docs/重构后项目开发规范.md`；摘要见 skill `v5-module-dev-conventions`。

---

## 8. 本仓库的 AI 操作纪律

- **改之前先读**：涉及目录约定、Provider 注册、提交历史时，先 `Read` 真实文件/`git log`，
  不要凭记忆或凭本文件断言。本文件的表格是**快照**，会过时。
- **验证要能失败**：只报「没报错」不算验证。写测试时故意破坏一次实现确认测试变红。
- **不夸大验证范围**：平台插件层只有静态分析覆盖时必须明说。
- **临时文件放 `$TEMP`**，不要放仓库目录（会污染 `git status`）。
  仓库里做过 scratch 实验后，交付前确认已删除。
- **不要提交** `.dart_tool/`、`build/`、`*.log`、`.flutter_tool_state` 等产物。
- 环境类问题先查 skill `windows-agent-env-workarounds`，**别去改项目代码**。

---

## 9. 相关 skill 索引

| skill | 用途 |
|---|---|
| `windows-agent-env-workarounds` | 本机环境坑清单与绕过（管道/编码/删除/提交回读/管道 231） |
| `flutter-offline-verification` | 环境坏时的替代验证：进程内 analyzer + 最小替身 + 覆盖层 |
| `v5-update-distribution` | 更新清单契约、五档决策、CDN 镜像、发版清单 |
| `v5-module-dev-conventions` | 项目强制编码规则（行数/Provider/异常/fail-soft/命名） |
| `dart-large-file-splitting` | 超限 Dart 文件的安全拆分手册 |
