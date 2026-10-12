# CLAUDE.md — 任务管家（V5）

**本文件只讲「怎么干活」：项目事实、验证命令、环境坑、操作纪律。**
**不写编码规范** —— 规则只有一份，在 `.trae/rules/`，动手前先读
[`.trae/rules/README.md`](.trae/rules/README.md) 找该读哪张卡。

> 设计取舍与历史原因在 [`docs/decisions.md`](docs/decisions.md)。
> 三者**不再互相复述**：规则改动只改 `.trae/rules/`，本文件不需跟着改。

---

## 1. 这是什么项目

Flutter 应用「任务管家」：任务管理 + 积分 + 番茄钟 + 商城 + 统计 + 小游戏中心。
**纯本地存储、无后端**。内容分发（小游戏包、App 更新包）靠公开 GitHub 仓库
`Aria-2676/note_study` 经 jsDelivr CDN 分发。**自签名分发给小圈子，不上应用商店。**

| 项 | 值 |
|---|---|
| 仓库 | `D:\Dev\V5`（分支 `main`） |
| 包名 / applicationId | `v5_app` / `com.noteapp.taskmaster` |
| 平台 | android / ios / linux / macos / web / windows |
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
`game_center/`。**CDN 基址唯一来源是 `lib/core/config/cdn_bases.dart`**，
大文件（.zip/.apk）必须走 `gcore.jsdelivr.net`（`cdn.jsdelivr.net` 会 301 到
国内常被 reset 的 raw）。

**五档决策**（`AppUpdateDecider`，纯函数）：
`minSupported` 更高 → `forced`（免疫跳过与关闭提醒）；正式包更高 →
大版本且未跳过 → `optional`，否则 `available`；仅资源包且 build 更高 →
`assetsOnly`；其余 → `none`。

| | 整包更新 | 资源热更 |
|---|---|---|
| 是否打扰 | 大版本弹窗，可跳过 | **完全不打扰**，后台静默 |
| 落地 | 下载 APK → 唤起安装器 | 下载 zip → 校验 → **原子替换**目录 |
| 实现 | `AppUpdateLauncher` | `AppAssetApplier` |
| 失败 | 提示用户 | **只记日志**，下次重试 |

打包、发版清单、字段坑（`downloads` / `sizeBytes` / `minSupported` 在顶层 /
`assets` 是单个对象）见 skill `v5-update-distribution`。

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
