# CLAUDE.md — 任务管家（V5）

**本文件只讲「怎么干活」：项目事实、验证命令、环境坑、操作纪律。**
**不写编码规范** —— 规则只有一份，在 `.trae/rules/`，动手前先读
[`.trae/rules/README.md`](.trae/rules/README.md) 找该读哪张卡。

> 设计取舍与历史原因在 [`docs/decisions.md`](docs/decisions.md)。
> 三者**不再互相复述**：规则改动只改 `.trae/rules/`，本文件不需跟着改。

> **📌 2026-10 平台化改造进行中** —— 动手前先读 [`docs/INDEX.md`](docs/INDEX.md)（文档地图）
> 与 [`docs/main-package.md`](docs/main-package.md)（主包/插件边界）。
> 本文描述的是**当前 v5 代码**的事实；主包重写后，§1 的库表版本、§4 的分发细节、
> `.trae/rules` 的「依赖方向」都会随之变化，届时以新代码为准并同步本文。

---

## 1. 这是什么项目

Flutter 应用「任务管家」：任务管理 + 积分 + 番茄钟 + 商城 + 统计 + 小游戏中心。
**纯本地存储、无后端**。内容分发（小游戏包、App 更新包）靠公开 GitHub 仓库
`Aria-2676/note_study` 经 jsDelivr CDN 分发。**自签名分发给小圈子，不上应用商店。**

| 项 | 值 |
|---|---|
| 仓库 | `D:\Dev\V5`（分支 `main`） |
| 包名 / applicationId | `v5_app` / `com.noteapp.taskmaster` |
| 平台 | 目录含 6 个平台，**实际只构建并验证 Android**（自签分发）；iOS 从未 `pod install` |
| 数据库 | sqflite，`v5_tasks.db`，`AppConfig.dbVersion = 3` |
| 规模 | lib ~210 个 Dart 文件、test ~50 个 |
| 版本 | 见 `pubspec.yaml`，与最近提交号一致 |

架构与目录见规则「依赖方向」；Provider 清单见规则「Provider」；统计见规则「统计」。

---

## 2. 构建与验证

### 正常路径

```bash
flutter pub get
flutter analyze                          # 改到 test/ 也要用它，不是只分析 lib
flutter test --no-pub --reporter compact
flutter build apk --release
```

### ⚠️ 本机环境坑：analyze / test 可能完全起不来

本机 Dart 运行时**偶发**无法 `CreatePipe`（`ERROR_PIPE_BUSY` 231），
导致 `flutter analyze` / `dart analyze` / `flutter test` / `dart test` **全部启动失败**。
这是**环境问题，不是项目问题** —— 别去改代码。`dart pub get` 不受影响。

判断：`flutter --version` 若报 `CreateFile failed 231` 即已中招。
处置顺序：**重启电脑 → 排查安全软件/EDR 白名单 → 完全重启 IDE**。

### ⚠️ flutter test 报 WebSocket 握手失败 —— 先查代理变量（已验证）

报错：`Unable to connect to flutter_tester process: WebSocketException:
Invalid WebSocket upgrade request`

**多数不是安全软件，是环境里设了 HTTP 代理。** flutter_tester 用本地 WebSocket 与被测进程
通信，请求被路由到代理上，握手必然失败。

```bash
env -u HTTP_PROXY -u HTTPS_PROXY -u http_proxy -u https_proxy \
    NO_PROXY="127.0.0.1,localhost" flutter test --no-pub --reporter compact
```

实测清掉后立即恢复（21 个用例全过）。**这条与上面的 CreatePipe 231 是两个不同的坑**：
前者是代理劫持回环，后者是进程创建失败，别混为一谈。

### ⚠️ Android 构建：JDK 必须是 21，不能是 25（2026-10-22 已处置）

Android Studio 自带的 JBR 已升到 **Java 25**，而项目用的 Gradle 8.14 只支持到 Java 24 →
**任何 android 构建在编译代码之前就失败**，报 `Java/Gradle incompatibility`。

处置（已完成，可复现）：

```bash
curl -L -o D:/Dev/SDK/jdk/microsoft-jdk-21.zip \
  https://aka.ms/download-jdk/microsoft-jdk-21-windows-x64.zip
powershell -Command "Expand-Archive D:/Dev/SDK/jdk/microsoft-jdk-21.zip -DestinationPath D:/Dev/SDK/jdk"
flutter config --jdk-dir="D:/Dev/SDK/jdk/jdk-21.0.12.1+1"
```

- 便携版：解压即用、删目录即还原，**不动系统 JAVA_HOME**
- **不要**为了匹配 Java 25 去升 Gradle/AGP —— 那是 ROADMAP 里 v5.5.30 的独立任务，
  不该被一次环境故障逼着做
- `winget install` 在这台机器上会失败（`InternetOpenUrl() failed 0x80072efd`，
  winget 的下载器不走系统代理），必须用 curl

### ⚠️ sqlite3 的 build hook 要联网下载原生库，直连 GitHub 必失败

构建报 `By default, this package downloads a pre-compiled SQLite library. This failed`，
URL 指向 `github.com/simolus3/sqlite3.dart/releases/...`。来源是 dev 依赖
`sqflite_common_ffi` 带进来的 `sqlite3` 包，在 Flutter 的 native assets 阶段执行；
hook 用 Dart HttpClient，**不走系统代理**，所以 GitHub 直连不通就整个构建失败。

处置：用镜像把四个 ABI 的库放进 hook 缓存目录。目录名 = 期望 sha256 的前 8 位，
文件名固定 `libsqlite3.so`，hook 校验哈希对上就直接复用、不再联网。

```bash
BASE=https://ghfast.top/https://github.com/simolus3/sqlite3.dart/releases/download/sqlite3-3.5.2
DEST=.dart_tool/hooks_runner/shared/sqlite3/build
# 哈希清单：pub-cache/hosted/pub.dev/sqlite3-<ver>/lib/src/hook/asset_hashes.dart
mkdir -p $DEST/download-0c2d3bfc
curl -L -o $DEST/download-0c2d3bfc/libsqlite3.so $BASE/libsqlite3.arm64.android.so
```

四个 ABI（arm / arm64 / ia32 / x64）都要补。**升级 sqlite3 版本后这份缓存要重做**。

**替代验证（环境坏时用，两条互补）：**

```bash
cd /d/Dev/V5

# ① 静态分析：进程内 analyzer，不 spawn 子进程
dart --packages=".dart_tool/package_config.json" \
  "$TEMP/wb_analyze.dart" "D:/Dev/V5/lib" "D:/Dev/V5/test"
#    期望：FILES=<n> ERRORS=0 WARNINGS=0

# ② 行为自检：最小包替身 + package_config 覆盖层，跑真实实现
dart --packages=.dart_tool/wb_pc.json .dart_tool/wb_verify.dart
#    期望末行 RESULT=PASS

# ③ 完整端到端（把 CDN 指向本机，启用安装链路自检）
dart --packages=.dart_tool/wb_pc.json \
  -DGAME_CDN_BASE=http://127.0.0.1:38471 \
  -DGAME_CDN_SHA_BASE=http://127.0.0.1:38471 \
  .dart_tool/wb_verify.dart
```

这几个脚本在 `.dart_tool/`（已 gitignore），**不要提交**。
完整配方见 skill `flutter-offline-verification`；环境坑清单见
`windows-agent-env-workarounds`。

**诚实边界**：替代验证覆盖不到**平台插件层**（path_provider / open_filex /
url_launcher / package_info_plus）与 **UI 层**；这两层只有静态分析。
报告结论时必须说明，不能用「全部通过」含糊带过。

---

## 3. 提交

规则见规则「提交、版本与兼容性」。最易踩坑的三条：

1. **中文提交信息必须写成 UTF-8 文件后 `git commit -F <文件>`**，
   禁止 `-m "中文"`（会被控制台编码破坏）。
2. **暂存用限定路径**：`git add lib test`，不要 `git add -A`。
3. 提交后对齐 `pubspec.yaml` 的 `version`。

```bash
cd /d/Dev/V5
git add lib test
git commit -F "$TEMP/v5_msg.txt"          # 消息文件用 Write 工具写，放 $TEMP
git cat-file commit HEAD | head -20       # 字节级回读确认中文未坏
```

---

## 4. 分发与更新体系

托管仓库 `Aria-2676/note_study`：`update.json`（仓库根）、`releases/`、
`game_center/`。**CDN 基址唯一来源是 `lib/core/config/cdn_bases.dart`**。
**小文件**（清单、游戏 zip，<20MB）走 jsDelivr 多节点（gcore 主，
testingcf/cdn/raw 依次回退）；**APK 必走 GitHub Releases**（jsDelivr 单文件
20MB 硬上限，fat 包 62MB 必然 403）。

**及时性链路（2026-10 改造，三层保证「发布后尽快被发现」）：**

1. 清单候选顺序：gcore → testingcf → cdn → raw.githubusercontent →
   **GitHub Contents API 兜底**（`AppUpdateService.manifestApiUrl`，读仓库
   实时内容、无 jsDelivr 最长 12h 缓存，拆 76 列 base64 信封；未认证
   60 次/小时/IP 限速，自签小圈子用不完）；全部请求带 `Cache-Control: no-cache`。
2. 前台自动检查间隔 1 小时（`AppUpdateSettings`），回前台到点也查
   （`AppUpdatePromptHost`）。
3. 后台 WorkManager 周期任务（`BackgroundUpdateWorker`，仅 Android，
   uniqueId `v5-app-update-periodic-check`，keep/update 策略幂等注册）：
   后台拉清单 → 复用同一把决策尺 → 命中发本地通知，**同版本只通知一次**
   （闸门是纯函数 `shouldNotifyInBackground`，必须有测试）。后台读
   SharedPreferences 环境快照，不碰 package_info/getprop。

**五档决策**（`AppUpdateDecider`，纯函数）：
`minSupported` 更高 → `forced`（免疫跳过与关闭提醒）；正式包更高且未被
「跳过/关闭提醒」抑制 → **一律 `optional` 并弹窗**（自签分发无商店兜底，
patch 也可能是紧急修复；2026-10 起不再只让 major 弹窗）；被抑制 → `available`
（设置页可见不打扰）；仅资源包且 build 更高 → `assetsOnly`；其余 → `none`。

| | 整包更新 | 资源热更 |
|---|---|---|
| 是否打扰 | **任何整包版本都弹窗**，可跳过/抑制 | **完全不打扰**，后台静默 |
| 落地 | 多源下载 APK → sha256/大小校验 → 唤起安装器 | 下载 zip → 校验 → **原子替换**目录 |
| 实现 | `AppUpdateLauncher` + `MultiSourceDownloader` | `AppAssetApplier` |
| 失败 | 换下一个源，全失败才提示用户 | **只记日志**，下次重试 |

**APK 多源下载**（`DownloadMirrors.expand` + `MultiSourceDownloader`，
平台无关逻辑在 `core/services/` 必须可主机单测）：

- 候选顺序：清单 `mirrors` 显式热下发源 → 内置公益镜像前缀
  （`ghfast.top` → `gh-proxy.com`，顺序按实测吞吐排）→ GitHub 直连兜底。
  直连置最后：实测它可能连续数小时不可达，先试纯浪费超时；自动去重。
- 每个源独立临时文件，sha256 或大小不符立即删包换源、进度归零；
  超时拆三段（连接 15s / 响应头 30s / **数据块间隔** 60s，慢而稳可继续，
  静默假死快速判死），别用一个总时长超时。
- 镜像不可信没关系：端到端 sha256 校验把住内容，多源只增可用性。

打包、发版清单、字段坑（`downloads` / `sizeBytes` / `minSupported` 在顶层 /
`assets` 是单个对象）见 skill `v5-update-distribution`。

**发版动作：一条命令，`tool/publish_release.ps1 -Version x.y.z`（幂等可重跑）。**
前置：pubspec 改版本 → `tool/build_apk.ps1 -Flavor both`（fat+3 split 缺一不可）
→ 代码先提交。工具自动完成：tag → push（无限重试）→ 建/取 Release →
资产 size+digest 核对、不符删后重传、422 靠下一轮 list 自愈 → 重写
`update.json`（version/updatedAt/url/sha256/sizeBytes/mirrors，notes 用
`-Notes` 传或保留原文）→ UTF-8 文件 `-F` 单独提交清单 → push →
purge.jsdelivr.net。token 只认 `$env:GITHUB_TOKEN`，不落盘。

手工发版时踩过、工具已固化的坑（勿回退）：① PS5.1 给 curl.exe 内联 `-d`
JSON 会被剥双引号 → 400，必须临时文件 `--data-binary "@file"`；
② sha256 一律运行时 `Get-FileHash` 现算，手写进脚本会丢字符（63/64 位
肉眼分不出），会造成「正确上传被循环删除」；③ Release 不存在时
下载 URL 返回 404 HTML，会被存成 .apk 表现为「包损坏」，必须先 Release
后清单。

### 4.1 热更资源的消费端（读入口）

`HotAssetStore`（`core/updater/services/`）是 `hot_assets/` 的**唯一读入口**。
放在 `core/` 是被铁律逼出来的：`core` 不能 import `modules/*`，读取逻辑若写在
某个业务模块里，其他模块就没法复用。约定「**同名文件以热更目录为准，缺失回落
包内**」，所以业务改造永远是「先问 store，拿不到再用自带」，没有热更包也不会坏。

- 目录只解析一次并缓存（UI 的 `build()` 可能每帧查询，逐次查盘会掉帧）；
- `AppAssetApplier.apply()` 成功后**必须**调 `HotAssetStore.instance.invalidate()`，
  否则旧文件被记住「不存在」，新素材要等冷启动才生效；
- 路径做了**两道**越界校验（`_sanitize` 拒 `..`/绝对路径/盘符 + `p.relative` 复核），
  与 `GameAssetServer._resolveTarget` 同一套纵深防御。

目前的消费者：

| 消费者 | 热更约定路径 | 说明 |
|---|---|---|
| `GameAssetServer` | `games/<gameId>/…` | `overlayDir` 优先命中，整目录同构叠加 |
| `GameCardWidget` | `games/icons/<gameId>.png` | 游戏中心图标，缺图回落字形 |
| `MaterialApp` 主题 | `theme.json` | 种子色/亮度/主色/圆角，**启动时读一次** |

新模块接入时：先在那个模块里定好子目录约定，再用 `HotAssetStore.instance`
读取；**不要**各自 `new HotAssetStore()`（缓存会分散，`invalidate` 失效不彻底）。

---

## 5. ⚠️ Android 签名（最高风险）

**更新包必须与已安装包同一密钥签名**，否则 `INSTALL_FAILED_UPDATE_INCOMPATIBLE`，
老用户**只能卸载重装（丢数据）**。

- 密钥库 `D:\Dev\keystore\taskmaster-release.jks`（**刻意在仓库外**，仓库是公开的）
- 生成：`tool/setup_android_keystore.ps1`（交互式输密码，**推荐**）
  或 `tool/setup_android_keystore_auto.ps1`（脚本自生成口令——口令会外露，**仅本机测试用**）
- 备份：`tool/backup_android_keystore.ps1` → 生成含密钥库+口令+恢复说明的 zip，须拷到本机之外
- `android/app/build.gradle.kts` 读 `android/key.properties`，缺失回落 debug
- `.gitignore` 已排除 `key.properties` / `*.jks` / `*.keystore` / `PASSWORD.txt` /
  `**/taskmaster-signing-*.zip` 等（纵深防御；真正的密钥库本就在仓库外）

**纪律**：绝不生成、记录或输出签名口令；密钥库与口令丢失不可恢复，须存密码管理器。

**Windows 坑**：`keytool -v` 把进度打到 stderr，PowerShell 5.1 会把原生 stderr
升级成 `NativeCommandError`，脚本顶层 `$ErrorActionPreference='Stop'` 会因此在
**写 `key.properties` 之前中断**（密钥库其实已生成，但配置没写、脚本报失败）。
两个脚本都已在该调用点降级 preference 并改判退出码——改这段代码时别改回去。

---

## 6. 干活时的纪律

- **改之前先读**：本文件的表格是快照会过时，涉及目录/Provider/约定时先 `Read` 真实文件。
- **验证要能失败**：只报「没报错」不算验证；写测试时故意破坏一次实现确认变红。
- **不夸大验证范围**：见 §2 末尾的诚实边界。
- **临时文件放 `$TEMP`**，不要放仓库；做过 scratch 实验后确认已删除。
- **不提交** `.dart_tool/`、`build/`、`*.log`、`.flutter_tool_state`。
- 环境类问题先查 skill `windows-agent-env-workarounds`，别改项目代码。

---

## 7. skill 索引

| skill | 用途 |
|---|---|
| `windows-agent-env-workarounds` | 本机环境坑与绕过（管道 231 / 编码 / 删除 / 提交回读） |
| `flutter-offline-verification` | 环境坏时的等价验证（进程内 analyzer + 最小替身 + 覆盖层） |
| `v5-update-distribution` | 更新清单契约、五档决策、CDN、发版清单、签名 |
| `v5-module-dev-conventions` | 项目强制编码规则速查 |
| `dart-large-file-splitting` | 超限 Dart 文件的安全拆分手册 |
