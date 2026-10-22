# 任务管家

一个带激励系统的任务管理应用：完成任务 → 获得能量/积分 → 兑换自我奖励。
当前版本 **v5.5.26**（v5 的最后一个功能版本）。

> **⚠️ 平台化改造准备期（2026-10）**
> v5 已冻结功能开发，v6 将重写为「轻主包 + 可安装插件」。
> 文档入口：[`docs/INDEX.md`](docs/INDEX.md) ｜ 主包与插件边界：[`docs/main-package.md`](docs/main-package.md)
>
> **实际分发形态**：仅 Android，自签 APK 小圈子分发，**不进应用商店**。
> 仓库里还留着 `ios/`、`web/`、`macos/`、`linux/`、`windows/` 目录，但**只有 Android 被真正构建与验证过**
> （`ios/` 无 `Podfile.lock`，从未执行过 `pod install`）。

## 功能特点

- ✅ 任务管理：创建、编辑、删除、循环任务、回收站
- ✅ 激励系统：完成任务获得能量/积分，兑换奖励
- ✅ 商城系统：用积分兑换自我奖励
- ✅ 桌面小组件：快速查看和完成任务
- ✅ 小游戏中心：游戏包按需下载，下载后离线可玩
- ✅ 主题切换：亮色 / 暗色
- ⚠️ 平台：**仅 Android 实际可用**

## 技术栈

- **框架**：Flutter 3.11+ / Dart
- **状态管理**：Provider
- **数据库**：SQLite（sqflite）
- **本地存储**：shared_preferences
- **小游戏容器**：webview_flutter（本地回环静态服务加载外置 HTML5 游戏包）
- **桌面小组件**：home_widget
- **分发**：GitHub + jsDelivr，应用内自更新（整包 + 资源热更）

## 运行方式

```bash
flutter pub get
flutter run
```

## 项目结构

```
lib/
├── core/            # 跨模块基础设施（服务、模型、路由、更新引擎）
├── modules/         # 业务模块，各自 pages/services/repositories/providers
├── providers/       # 跨模块状态（新代码请随模块走，不要往这里加）
├── ui/              # 全局 UI 组件与主题
└── main.dart        # 入口：服务初始化 + MultiProvider + 路由
```

v6 改造后，`modules/` 下大部分内容会作为插件迁出，主包只保留任务模式与能力层。

## 版本历史

| 版本 | 日期 | 主题 |
|---|---|---|
| v5.5.26 | 2026-10-17 | 资源/游戏断点续传 + 多源回退、仅 WiFi 自动下载、更新结果统计、恢复图标树摇 |
| v5.5.25 | 2026-10-16 | 弱网下载修复（可重试识别 + Range 续传）、残留临时包清理、API 推送通道与一键发版闭环 |
| v5.5.24 | 2026-10-16 | 分 ABI 构建、FileProvider 安装弹窗修复、多源镜像与下载进度通知 |

完整历史（V5.0.0 – V5.5.26）：[`docs/archive/README-version-history-v5.md`](docs/archive/README-version-history-v5.md)
