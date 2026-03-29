# 任务管家 V5

一个带积分系统的任务管理应用，帮助用户通过完成任务获得积分，兑换奖励。

## 功能特点

- ✅ 任务管理：创建、编辑、删除任务
- ✅ 积分系统：完成任务获得积分，兑换奖励
- ✅ 商城系统：用积分兑换各种奖励
- ✅ 桌面小组件：快速查看和完成任务
- ✅ 主题切换：支持亮色/暗色模式
- ✅ 多平台支持：Android、iOS、Web、Windows、macOS、Linux

## 技术栈

- **框架**：Flutter 3.11+
- **语言**：Dart
- **状态管理**：Provider
- **数据库**：SQLite (sqflite)
- **桌面小组件**：home_widget
- **存储**：shared_preferences

## 运行方式

1. 确保已安装 Flutter SDK
2. 克隆项目
3. 运行 `flutter pub get` 安装依赖
4. 运行 `flutter run` 启动应用

## 项目结构

```
lib/
├── models/          # 数据模型
├── pages/           # 页面
├── providers/       # 状态管理
├── services/        # 服务
└── main.dart        # 入口文件
```

## 版本历史

- **V5.0.3** (2026-03-29)
  - 更新项目规则，添加版本备份流程要求
  - 清理配置文件中的版本信息
  - 重命名配置文件：`v3_app.iml` → `taskmaster.iml`
  - 使用方法：Git 提交记录、文件重命名

- **V5.0.2** (2026-03-29)
  - 统一版本管理，创建 `VersionUtils` 工具类
  - 清理硬编码版本号，实现动态版本读取
  - 统一应用名称为"任务管家"
  - 跨平台统一：Android、iOS、Web、macOS、Windows
  - 使用方法：从 `pubspec.yaml` 读取版本号

- **V5.0.1** (2026-03-29)
  - 新增统计和其他页面
  - 更新底部导航栏
  - 优化界面布局
  - 使用方法：Flutter 页面开发、导航栏配置

- **V5.0.0** (2026-03-29)
  - 初始版本
  - 核心功能：任务管理、积分系统、商城系统
  - 多平台支持：Android、iOS、Web、Windows、macOS、Linux
  - 使用方法：Flutter 框架开发