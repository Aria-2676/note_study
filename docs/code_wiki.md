# 任务管家 V5 — Code Wiki

> 本文档为「任务管家 V5」项目的结构化代码 Wiki，覆盖项目整体架构、各层职责、关键类与函数、依赖关系、数据库设计、桌面小组件机制及运行方式。
> 项目版本：`5.2.1+21`（见 [pubspec.yaml](file:///workspace/pubspec.yaml)）。

---

## 目录

1. [项目概述](#1-项目概述)
2. [技术栈与依赖](#2-技术栈与依赖)
3. [项目结构](#3-项目结构)
4. [整体架构](#4-整体架构)
5. [入口层 main.dart](#5-入口层-maindart)
6. [状态管理层 providers](#6-状态管理层-providers)
7. [业务用例层 use_cases](#7-业务用例层-use_cases)
8. [数据访问层 repositories](#8-数据访问层-repositories)
9. [服务层 services](#9-服务层-services)
10. [数据模型层 models](#10-数据模型层-models)
11. [UI 页面层 pages](#11-ui-页面层-pages)
12. [组件层 components](#12-组件层-components)
13. [工具层 utils](#13-工具层-utils)
14. [数据库设计](#14-数据库设计)
15. [桌面小组件架构](#15-桌面小组件架构)
16. [依赖关系图](#16-依赖关系图)
17. [核心数据流](#17-核心数据流)
18. [项目运行方式](#18-项目运行方式)
19. [多平台支持](#19-多平台支持)

---

## 1. 项目概述

**任务管家 V5** 是一款带积分系统的跨平台任务管理应用，帮助用户通过完成任务获得积分、兑换奖励，从而形成正向激励循环。

核心能力：

- **任务管理**：创建/编辑/删除任务、按日期查看、任务优先级（红/橙/黄/蓝/白）、循环任务（daily/weekly/monthly）、任务回收站、过期未完成扣分。
- **积分系统**：完成任务奖励积分、过期未完成扣除半数积分、积分持久化。
- **商城与仓库**：积分兑换奖励、查看已购买商品、默认商品初始化。
- **桌面小组件**：Android 桌面小组件，显示当日任务与积分，支持在桌面直接勾选完成任务并双向同步。
- **番茄钟**：专注/休息计时、震动提示、息屏控制、强制闭关、状态自动切换。
- **统计**：任务完成情况按日/三日/周/月/年多维度统计与图表。
- **设置**：主题切换（亮/暗）、任务视图模式（简洁/丰富）、数据导出/导入、清缓存、版本信息。
- **多平台**：Android、iOS、Web、Windows、macOS、Linux。

---

## 2. 技术栈与依赖

| 维度 | 选型 |
| --- | --- |
| 框架 | Flutter 3.11+（SDK `^3.11.1`） |
| 语言 | Dart |
| 状态管理 | Provider `^6.1.1` |
| 本地数据库 | sqflite `^2.3.0` + path `^1.9.0` |
| 桌面小组件 | home_widget `^0.6.0` |
| 轻量存储 | shared_preferences `^2.2.2` |
| 文件路径 | path_provider `^2.1.1` |
| 震动反馈 | vibration `^3.1.8` |
| 代码规范 | flutter_lints `^6.0.0` |

依赖定义见 [pubspec.yaml](file:///workspace/pubspec.yaml)，代码规范配置见 [analysis_options.yaml](file:///workspace/analysis_options.yaml)。

---

## 3. 项目结构

```
lib/
├── main.dart                 # 应用入口 + 主框架 HomePage
├── components/
│   └── task_dialog.dart       # 任务新增/编辑底部弹窗（可复用组件）
├── models/                    # 数据模型层
│   ├── task.dart
│   ├── user_points.dart
│   ├── shop_item.dart
│   ├── purchased_item.dart
│   └── recycled_task.dart
├── pages/                     # UI 页面层
│   ├── task_page.dart         # 任务列表 + 日历条
│   ├── statistics_page.dart   # 统计
│   ├── others_page.dart       # 其他（番茄钟/日历入口）
│   ├── mine_page.dart         # 我的（积分/商城/仓库/设置入口）
│   ├── calendar_page.dart     # 日历视图
│   ├── pomodoro_page.dart     # 番茄钟
│   ├── recycle_bin_page.dart  # 回收站
│   ├── settings_page.dart     # 设置
│   ├── shop_page.dart         # 积分商城
│   ├── warehouse_page.dart    # 我的仓库（已购买商品）
│   ├── widget_guide_page.dart # 小组件添加引导
│   └── help_page.dart         # 使用说明
├── providers/                 # 状态管理层
│   ├── app_provider.dart      # 聚合 Provider（协调子 Provider）
│   ├── task_provider.dart
│   ├── points_provider.dart
│   ├── shop_provider.dart
│   └── settings_provider.dart
├── repositories/              # 数据访问层
│   ├── task_repository.dart
│   ├── points_repository.dart
│   ├── shop_repository.dart
│   └── settings_repository.dart
├── use_cases/                 # 业务用例层（领域逻辑封装）
│   ├── task_use_cases.dart
│   ├── points_use_cases.dart
│   ├── shop_use_cases.dart
│   └── settings_use_cases.dart
├── services/                  # 服务层
│   ├── database_service.dart  # SQLite 数据库（单例）
│   ├── widget_service.dart    # 桌面小组件通信
│   └── data_migration_service.dart # 数据导入/导出
└── utils/
    └── version_utils.dart     # 动态版本读取
```

原生侧关键文件：

- [android/app/src/main/java/com/noteapp/taskmaster/TaskWidgetProvider.java](file:///workspace/android/app/src/main/java/com/noteapp/taskmaster/TaskWidgetProvider.java)：Android 桌面小组件实现。
- [android/app/src/main/kotlin/com/noteapp/taskmaster/MainActivity.kt](file:///workspace/android/app/src/main/kotlin/com/noteapp/taskmaster/MainActivity.kt)：原生 MethodChannel 处理。
- [android/app/src/main/AndroidManifest.xml](file:///workspace/android/app/src/main/AndroidManifest.xml)：注册小组件 receiver。

---

## 4. 整体架构

项目采用 **分层 + 聚合 Provider** 架构（重构记录见 [docs/REFACTOR_PLAN.md](file:///workspace/docs/REFACTOR_PLAN.md) 与 [docs/V5.1.0重构后变更摘要.md](file:///workspace/docs/V5.1.0重构后变更摘要.md)）。自上而下分层：

```
┌──────────────────────────────────────────────────┐
│  UI 层 (pages / components)                      │  StatefulWidget/StatelessWidget
│   ↓ context.watch/read<AppProvider>()            │  仅消费状态、触发动作
├──────────────────────────────────────────────────┤
│  状态管理层 (providers)                          │  ChangeNotifier
│   AppProvider 聚合 → Task/Points/Shop/Settings   │  持有 UI 状态，转发通知
│   ↓ 调用                                          │
├──────────────────────────────────────────────────┤
│  业务用例层 (use_cases)                          │  跨仓库编排、领域规则
│   ↓ 调用                                          │  （可选层，封装跨域逻辑）
├──────────────────────────────────────────────────┤
│  数据访问层 (repositories)                       │  对 DatabaseService 的领域封装
│   ↓ 调用                                          │
├──────────────────────────────────────────────────┤
│  服务层 (services)                               │  DatabaseService(单例)/WidgetService/
│   ↓                                               │  DataMigrationService
├──────────────────────────────────────────────────┤
│  数据模型层 (models) + SQLite + SharedPreferences│  纯数据载体
└──────────────────────────────────────────────────┘
```

### 分层职责

- **UI 层**：只负责渲染与交互，通过 `context.watch<AppProvider>()` 监听、`context.read<AppProvider>()` 触发动作，不直接访问数据库。
- **状态管理层**：持有 UI 状态（任务列表、积分、商品、主题、当前 Tab 等），调用 repository 完成数据操作后 `notifyListeners()`。`AppProvider` 作为聚合根，监听四个子 Provider 的变化并向上转发通知。
- **业务用例层**：封装跨仓库的领域规则（如完成任务同时改任务+积分、过期扣分、购买商品同时扣分+入库）。当前部分逻辑仍保留在 Provider 内，use_cases 提供了可复用的同构能力。
- **数据访问层**：薄封装，把 `DatabaseService` 的原始方法按领域归类，便于替换实现与测试。
- **服务层**：基础设施。`DatabaseService` 单例管理 SQLite；`WidgetService` 通过 `home_widget` 与原生小组件通信；`DataMigrationService` 负责导入/导出。
- **数据模型层**：不可变值对象，提供 `toMap()/fromMap()` 与 `copyWith()`。

### 状态更新流程

1. 用户操作 → 页面调用 `context.read<AppProvider>().xxx()`
2. Provider 内部调用对应 repository/use_case 完成持久化
3. Provider 重新加载数据并调用 `notifyListeners()`
4. `AppProvider._onSubProviderChanged()` 转发通知
5. `Consumer`/`context.watch` 收到通知重绘 UI

---

## 5. 入口层 main.dart

文件：[lib/main.dart](file:///workspace/lib/main.dart)

| 类 | 类型 | 职责 |
| --- | --- | --- |
| `main()` | 顶层函数 | 确保 binding 初始化、初始化 `WidgetService`、`runApp(MyApp())` |
| `MyApp` | StatelessWidget | 根 Widget：用 `ChangeNotifierProvider` 注入 `AppProvider`，通过 `Consumer` 根据 `provider.themeMode` 切换 `MaterialApp` 主题 |
| `HomePage` | StatefulWidget | 主框架：AppBar（积分胶囊）、`IndexedStack`（4 个 Tab 页）、`FloatingActionButton`（首页新增任务）、`NavigationBar`（底部导航） |
| `_HomePageState` | State | 实现 `WidgetsBindingObserver`：`initState` 异步 `provider.initialize()`；`didChangeAppLifecycleState` 在应用回到前台时 `provider.syncFromWidget()` 同步小组件；`_scrollToToday/_resetToToday` 控制日历条定位 |

关键行为：

- `initialize()` 在首帧后调用，并行初始化四个子 Provider，随后写入引导任务与小组件数据。
- 底部导航四个 Tab：首页（`TaskPage`）、统计（`StatisticsPage`）、其他（`OthersPage`）、我的（`MinePage`）。
- 首页 Tab 显示 `FloatingActionButton`，点击调用 `TaskDialog.showAddOrEditTaskDialog()`。

---

## 6. 状态管理层 providers

文件目录：[lib/providers/](file:///workspace/lib/providers)

### 6.1 AppProvider（聚合根）

文件：[lib/providers/app_provider.dart](file:///workspace/lib/providers/app_provider.dart)

`AppProvider extends ChangeNotifier`，持有四个子 Provider 实例并为它们添加监听器，子 Provider 任意变化时通过 `_onSubProviderChanged()` 转发 `notifyListeners()`。

| 成员 | 说明 |
| --- | --- |
| `task` / `points` / `shop` / `settings` | 四个子 Provider 实例 |
| `currentTab` | 当前底部导航索引 |
| `currentPoints` / `selectedDate` / `themeMode` | 便捷 getter，转发自子 Provider |
| `initialize()` | 初始化 WidgetService → 并行初始化四个子 Provider → 引导任务 → 更新小组件 |
| `syncFromWidget()` | 从小组件读取数据，按索引对比任务完成状态并同步本地，同步积分 |
| `_initTutorialTasks()` | 首次启动且当天无任务时，写入 6 条引导任务（仅一次） |
| `_updateWidget()` | 把任务/积分/日期写入桌面小组件 |
| `purchaseItem(ShopItem)` | 调用 `shop.purchaseItem`，成功后刷新积分 |
| `setCurrentTab/toggleTheme/setThemeMode/setTaskViewMode/toggleTaskViewMode` | 页面与设置状态管理 |
| `clearAllData()` | 清空全部数据并重新初始化 |
| `dispose()` | 移除子 Provider 监听器，避免内存泄漏 |

### 6.2 TaskProvider

文件：[lib/providers/task_provider.dart](file:///workspace/lib/providers/task_provider.dart)

| 成员 | 说明 |
| --- | --- |
| `_tasks` / `_recycledTasks` / `_selectedDate` / `_selectedDates` / `_multiTaskMode` | 任务与日期选择状态 |
| `initialize()` | 加载当日任务 → 回收站 → `autoCheckRecurringTasks()` → `_checkOverdueTasks()` |
| `loadTasksByDate(date)` | 按日期加载任务并刷新小组件 |
| `addTask(task)` | 处理循环任务：生成 `loopId`、`_handleRecurringTask`、`_generateTaskRange`（生成未来 15 天实例） |
| `_createRecurringTaskInstance` | 为循环任务生成重置状态的新实例 |
| `autoCheckRecurringTasks()` | 按 `loopId`（或字段签名）去重，补全循环任务实例 |
| `completeTask(task)` / `uncompleteTask(task)` | 仅允许当天完成任务；完成加积分、取消扣积分 |
| `deleteTask(id, {deleteAll})` | 单删入回收站；`deleteAll=true` 删除当前及后续全部循环实例 |
| `updateTask(task, {updateAll})` | 更新当前；`updateAll=true` 同步更新后续循环实例属性 |
| `restoreTaskFromRecycle(id)` / `deleteFromRecycle(id)` / `clearRecycleBin()` | 回收站操作 |
| `_checkOverdueTasks()` | 过期未完成且未扣分的一次性任务，扣半数积分并标记 `isDeducted` |
| `selectDate/toggleSelectedDate/setMultiTaskMode` | 日期选择与多选模式 |

### 6.3 PointsProvider

文件：[lib/providers/points_provider.dart](file:///workspace/lib/providers/points_provider.dart)

| 成员 | 说明 |
| --- | --- |
| `_userPoints` | `UserPoints` 状态 |
| `currentPoints` | 当前积分便捷 getter |
| `loadUserPoints()` / `addPoints/deductPoints/updatePoints` | 积分增删改后重新加载 |
| `syncPointsFromWidget()` | 从小组件同步积分 |
| `updateWidgetPoints()` | 把积分写回小组件 |

### 6.4 ShopProvider

文件：[lib/providers/shop_provider.dart](file:///workspace/lib/providers/shop_provider.dart)

| 成员 | 说明 |
| --- | --- |
| `_shopItems` / `_purchasedItems` | 商城商品与已购买商品 |
| `initialize()` | 加载商品 → 加载已购 → 首次为空时 `_createDefaultShopItems()`（8 项默认奖励） |
| `addShopItem/updateShopItem/deleteShopItem` | 商品 CRUD |
| `purchaseItem(item, currentPoints)` | 积分校验 → 扣分 → 生成 `PurchasedItem` 入库；返回错误信息或 `null` |
| `deletePurchasedItem(id)` | 删除已购买记录 |

### 6.5 SettingsProvider

文件：[lib/providers/settings_provider.dart](file:///workspace/lib/providers/settings_provider.dart)

定义枚举 `TaskViewMode { simple, rich }`。

| 成员 | 说明 |
| --- | --- |
| `_themeMode` / `_taskViewMode` / `_tutorialCompleted` | 主题、视图模式、引导完成标记 |
| `isDark` / `isRichView` | 便捷布尔 getter |
| `toggleTheme/setThemeMode/setTaskViewMode/toggleTaskViewMode` | 设置变更后 `_saveSettings()` 持久化 |
| `markTutorialCompleted()` / `resetSettings()` | 引导标记与重置 |
| `_loadSettings/_saveSettings` | 经 `SettingsRepository` 读写 settings 表 |

---

## 7. 业务用例层 use_cases

文件目录：[lib/use_cases/](file:///workspace/lib/use_cases)

用例层封装跨仓库编排，接收 repository 引用，便于单测与替换。

| 类 | 文件 | 关键方法 |
| --- | --- | --- |
| `TaskUseCases` | [task_use_cases.dart](file:///workspace/lib/use_cases/task_use_cases.dart) | `getTasksByDate`、`getRecurringTasks`、`checkOverdueTasks`（过期扣半分）、`completeTask`（含当天校验+加分）、`uncompleteTask`、`addTask/updateTask/deleteTask`、`restoreTaskFromRecycle/deleteFromRecycle/clearRecycleBin/getRecycledTasks` |
| `PointsUseCases` | [points_use_cases.dart](file:///workspace/lib/use_cases/points_use_cases.dart) | `getUserPoints`、`addPoints/deductPoints/updatePoints`、`hasEnoughPoints(required)` |
| `ShopUseCases` | [shop_use_cases.dart](file:///workspace/lib/use_cases/shop_use_cases.dart) | `getAllShopItems/addShopItem/updateShopItem/deleteShopItem`、`purchaseItem`（扣分+入库）、`getAllPurchasedItems/deletePurchasedItem`、`initDefaultShopItems` |
| `SettingsUseCases` | [settings_use_cases.dart](file:///workspace/lib/use_cases/settings_use_cases.dart) | `getSettings/saveSettings`、`clearAllData`、`markTutorialCompleted` |

> 说明：当前 Provider 内部仍直接持有 repository 并实现了等价逻辑；use_cases 提供了同构的业务编排入口，便于后续将 Provider 瘦身为纯状态容器。

---

## 8. 数据访问层 repositories

文件目录：[lib/repositories/](file:///workspace/lib/repositories)

四个 repository 均为薄封装，持有 `DatabaseService.instance` 单例，按领域归类原始数据库方法。

| 类 | 文件 | 覆盖能力 |
| --- | --- | --- |
| `TaskRepository` | [task_repository.dart](file:///workspace/lib/repositories/task_repository.dart) | 任务的增删改查、完成/取消、循环查询、过期查询、存在性校验、回收站全部操作 |
| `PointsRepository` | [points_repository.dart](file:///workspace/lib/repositories/points_repository.dart) | 积分读取、增减、直接设置 |
| `ShopRepository` | [shop_repository.dart](file:///workspace/lib/repositories/shop_repository.dart) | 商品 CRUD、已购买商品增删查 |
| `SettingsRepository` | [settings_repository.dart](file:///workspace/lib/repositories/settings_repository.dart) | settings 表读写、`clearAllData` |

---

## 9. 服务层 services

文件目录：[lib/services/](file:///workspace/lib/services)

### 9.1 DatabaseService

文件：[lib/services/database_service.dart](file:///workspace/lib/services/database_service.dart)

- **单例**：`DatabaseService.instance`，懒加载 `Database? _database`。
- **库文件**：`v5_tasks.db`，`version: 8`。
- **建表**：`_createDB` 创建 tasks / shop_items / user_points / purchased_items / settings / recycled_tasks 六张表。
- **迁移**：`_upgradeDB` 实现版本 1→8 的增量升级（新增表、ALTER 加列：外观字段、createdAt、priority、recycled_tasks、loopId）。
- **领域方法分组**：
  - Task：`createTask/getTasksByDate/getRecurringTasks/getAllTasks/existsTaskOnDate/updateTask/completeTask/uncompleteTask/deleteTask/deleteTaskWithoutRecycle`、回收站 `getRecycledTasks/restoreTaskFromRecycle/deleteFromRecycle/clearRecycleBin/_cleanupRecycledTasks`（仅保留最近 10 条）、`getOverdueTasks/markTaskDeducted`。
  - Shop：`createShopItem/getAllShopItems/updateShopItem/deleteShopItem`。
  - Warehouse：`addPurchasedItem/getAllPurchasedItems/deletePurchasedItem/getPurchasedItems`。
  - Points：`getUserPoints/updateUserPoints/addPoints/deductPoints/updatePoints`。
  - 数据迁移：`insertTask/insertRecycledTask/insertShopItem/insertPurchasedItem/insertSetting`（导入用）。
  - Settings：`getSettings/saveSettings`。
  - `clearAllData`：清空 tasks/shop_items/purchased_items 并重置积分。
- **任务排序规则**（见 `getTasksByDate`）：`isOK ASC`（未完成在前）→ 优先级 `red<orange<yellow<blue<white` → `cplTime ASC` → `id DESC`。

### 9.2 WidgetService

文件：[lib/services/widget_service.dart](file:///workspace/lib/services/widget_service.dart)

静态服务，封装与 Android 桌面小组件的通信。

| 成员 | 说明 |
| --- | --- |
| `widgetName/tasksKey/pointsKey/dateKey` | 小组件名与 SharedPreferences 键 |
| `_channel` | `MethodChannel('com.noteapp.taskmaster/widget')`（注：实际原生侧注册的通道为 `flutter.native/helper`） |
| `init()` | 初始化占位 |
| `updateWidgetData({tasks, points, date})` | 把任务（title/isOK/rewardPoints）+积分+日期经 `HomeWidget.saveWidgetData` 写入并触发 `HomeWidget.updateWidget` |
| `readWidgetData()` | 读取小组件 SharedPreferences，返回 `{tasks, points, date}` |
| `registerClickCallback` | 注册 `HomeWidget.widgetClicked` 回调 |
| `isWidgetAdded()` | 仅 Android，经 MethodChannel `isWidgetAdded` 查询 |
| `requestAddWidget()` | `HomeWidget.requestPinWidget`，失败回退 `_openWidgetPicker` |

### 9.3 DataMigrationService

文件：[lib/services/data_migration_service.dart](file:///workspace/lib/services/data_migration_service.dart)

静态服务，JSON 备份/恢复。

| 成员 | 说明 |
| --- | --- |
| `exportFileName` | `taskmaster_backup.json` |
| `exportData()` | 汇总 tasks/recycledTasks/userPoints/shopItems/purchasedItems/settings → JSON → 写入外部存储目录 |
| `importData(filePath)` | 校验格式 → `_createBackup()` 自动备份 → 在事务中清空六张表后逐项导入，失败自动回滚 |
| `exportFileExists()` / `getExportFilePath()` | 探测/获取导出文件路径 |

---

## 10. 数据模型层 models

文件目录：[lib/models/](file:///workspace/lib/models)

所有模型为不可变值对象，提供 `toMap()/fromMap()/copyWith()`，支持 JSON 序列化与数据库映射。

| 类 | 文件 | 关键字段/方法 |
| --- | --- | --- |
| `Task` | [task.dart](file:///workspace/lib/models/task.dart) | `id/loopId/title/description/isWord/isOK/cplTime/recurrence/completedAt/rewardPoints/isDeducted/createdAt/priority`；`priorityColor`（按 red/orange/yellow/blue/white 返回 Material 颜色）、`priorityOrder`（排序权重 0~4） |
| `UserPoints` | [user_points.dart](file:///workspace/lib/models/user_points.dart) | `id(默认1)/points/updatedAt` 单行积分记录 |
| `ShopItem` | [shop_item.dart](file:///workspace/lib/models/shop_item.dart) | `id/name/description/price/createdAt/iconName/colorValue`；`icon`（iconName→IconData 映射，含 28 种图标）、`color` |
| `PurchasedItem` | [purchased_item.dart](file:///workspace/lib/models/purchased_item.dart) | `id/shopItemId/name/description/price/purchasedAt/iconName/colorValue`；同款 `icon/color` 映射 |
| `RecycledTask` | [recycled_task.dart](file:///workspace/lib/models/recycled_task.dart) | `id/task(Task)/deletedAt`；`toMap/fromMap` 在回收站表（snake_case 列）与 `Task`（camelCase 列）之间做字段转换 |

---

## 11. UI 页面层 pages

文件目录：[lib/pages/](file:///workspace/lib/pages)

| 页面类 | 文件 | 职责 | 关键方法/逻辑 |
| --- | --- | --- | --- |
| `TaskPage` / `_TaskPageState` | [task_page.dart](file:///workspace/lib/pages/task_page.dart) | 首页：日历条 + 任务列表 + 进度 | `_resetAndScroll`、`_buildTaskCard`（按 `isRichView` 切换视图）、`_buildSimpleView`、`_onTaskCheckChanged`（完成/取消+积分提示）、`_showAddTaskDialog` |
| `StatisticsPage` / `_StatisticsPageState` | [statistics_page.dart](file:///workspace/lib/pages/statistics_page.dart) | 任务完成统计 | `_buildStatisticsChart`（按维度分发到日/三日/周/月/年图表） |
| `OthersPage` | [others_page.dart](file:///workspace/lib/pages/others_page.dart) | 「其他」入口页（StatelessWidget） | 跳转番茄钟、日历页 |
| `MinePage` | [mine_page.dart](file:///workspace/lib/pages/mine_page.dart) | 「我的」主页（StatelessWidget） | 展示积分、商城/仓库/设置入口 |
| `CalendarPage` / `_CalendarPageState` | [calendar_page.dart](file:///workspace/lib/pages/calendar_page.dart) | 月度日历视图 | 月度任务分布、选中日期任务展示 |
| `PomodoroPage` / `_PomodoroPageState` | [pomodoro_page.dart](file:///workspace/lib/pages/pomodoro_page.dart) | 番茄钟（独立计时状态） | `_startTimer/_pauseTimer/_resetTimer`、`_onTimerComplete`（专注→短休/每4次→长休）、`_triggerVibration`、`_loadSettings/_saveSettings`（息屏/强制闭关/震动） |
| `RecycleBinPage` / `_RecycleBinPageState` | [recycle_bin_page.dart](file:///workspace/lib/pages/recycle_bin_page.dart) | 任务回收站 | 初始化加载 `provider.task.recycledTasks`，恢复/删除/清空 |
| `SettingsPage` / `_SettingsPageState` | [settings_page.dart](file:///workspace/lib/pages/settings_page.dart) | 设置 | `_loadVersion`（VersionUtils）、`_clearCache`、`_showAboutDialog`、数据导入导出、主题/视图切换；分组折叠（常用/数据/更多） |
| `ShopPage` / `_ShopPageState` | [shop_page.dart](file:///workspace/lib/pages/shop_page.dart) | 积分商城 | 读取积分与商品列表、兑换 |
| `WarehousePage` | [warehouse_page.dart](file:///workspace/lib/pages/warehouse_page.dart) | 我的仓库（StatelessWidget） | 读取 `provider.shop.purchasedItems` 分组展示 |
| `WidgetGuidePage` / `_WidgetGuidePageState` | [widget_guide_page.dart](file:///workspace/lib/pages/widget_guide_page.dart) | 桌面小组件添加引导 | 调用 `WidgetService` 添加小组件 |
| `HelpPage` | [help_page.dart](file:///workspace/lib/pages/help_page.dart) | 使用说明（StatelessWidget） | 静态说明，无 Provider 依赖 |

> 番茄钟定义 `PomodoroMode { work, shortBreak, longBreak }`，专注 25 分钟、短休 5 分钟、长休 15 分钟，配置持久化在 `SharedPreferences`（键 `pomodoro_*`）。

---

## 12. 组件层 components

文件：[lib/components/task_dialog.dart](file:///workspace/lib/components/task_dialog.dart)

| 类 | 说明 |
| --- | --- |
| `TaskDialog` | 静态工具类（非 Widget），封装任务新增/编辑底部弹窗。`showAddOrEditTaskDialog(context, {Task? task})` 通过 `context.read<AppProvider>()` 获取 provider 与默认日期，使用 `StatefulBuilder` + `showModalBottomSheet` 构建表单（标题/描述/奖励积分/日期/重复/是否字数任务/优先级），保存时构造 `Task` 调用 `provider.task.addTask/updateTask` 后关闭弹窗 |

---

## 13. 工具层 utils

文件：[lib/utils/version_utils.dart](file:///workspace/lib/utils/version_utils.dart)

| 类 | 说明 |
| --- | --- |
| `VersionUtils` | 静态缓存版本号；`version` getter 通过 `rootBundle.loadString('pubspec.yaml')` + `yaml.loadYaml` 读取，去掉 `+build` 后缀；失败回退 `5.0.9`。供设置页展示统一版本 |

> 注：依赖 `package:yaml`，但 [pubspec.yaml](file:///workspace/pubspec.yaml) 未显式声明该依赖，依赖 Flutter 工具链传递可用。

---

## 14. 数据库设计

数据库 `v5_tasks.db`（SQLite，version 8），见 [database_service.dart](file:///workspace/lib/services/database_service.dart#L140-L226)。

### 14.1 表结构

**tasks**（任务主表）

| 列 | 类型 | 说明 |
| --- | --- | --- |
| id | INTEGER PK AUTO | 主键 |
| loopId | TEXT | 循环任务系列唯一标识 |
| title | TEXT | 标题 |
| description | TEXT | 描述（可空） |
| isWord | INTEGER | 是否字数任务（0/1） |
| isOK | INTEGER | 是否完成（0/1） |
| cplTime | TEXT | 计划完成时间（ISO8601） |
| recurrence | TEXT | 重复规则：none/daily/weekly/monthly |
| completedAt | TEXT | 实际完成时间（可空） |
| rewardPoints | INTEGER | 奖励积分 |
| isDeducted | INTEGER | 是否已扣分（避免重复扣） |
| createdAt | TEXT | 创建时间 |
| priority | TEXT | 优先级：red/orange/yellow/blue/white |

**shop_items**（商城商品）：`id, name, description, price, createdAt, iconName, colorValue`

**user_points**（积分，单行 id=1）：`id, points, updatedAt`

**purchased_items**（已购买商品/仓库）：`id, shopItemId, name, description, price, purchasedAt, iconName, colorValue`

**settings**（键值设置）：`key PK, value`

**recycled_tasks**（回收站，snake_case 列）：`id, task_id, title, description, is_word, is_ok, cpl_time, recurrence, completed_at, reward_points, is_deducted, created_at, priority, deleted_at`

### 14.2 版本迁移（_upgradeDB）

- v1→v2：新增 `purchased_items` 表。
- v2→v3：为 `shop_items` / `purchased_items` 增加 `iconName`、`colorValue`（容错 ALTER）。
- v3→v4：新增 `settings` 表。
- v4→v5：为 `tasks` 增加 `createdAt`。
- v5→v6：为 `tasks` 增加 `priority`。
- v6→v7：新增 `recycled_tasks` 表。
- v7→v8：为 `tasks` 增加 `loopId`。

### 14.3 查询排序

`getTasksByDate` 排序：未完成在前 → 优先级降序 → 时间升序 → id 降序。

---

## 15. 桌面小组件架构

### 15.1 整体机制

```
Flutter (WidgetService) ──HomeWidget──> SharedPreferences(HomeWidgetPreferences)
                                              │ 读取
                                              ▼
                          Android TaskWidgetProvider (RemoteViews 渲染)
                                              ▲ 点击复选框
                                              │ 写回 SharedPreferences + 广播刷新
Flutter (AppProvider.syncFromWidget) <──HomeWidget── 读取变化
```

- Flutter 侧 `WidgetService.updateWidgetData` 把任务/积分/日期序列化写入 `HomeWidget`，并触发 `HomeWidget.updateWidget`。
- 原生小组件 `TaskWidgetProvider` 在 `onUpdate` 中读取 `HomeWidgetPreferences`，用 `RemoteViews` 渲染最多 5 条任务（复选框图标 + 标题 + 积分）。
- 点击复选框发送广播 `ACTION_TOGGLE_TASK`，`onReceive` 调用 `toggleTaskStatus` 切换状态、更新积分并刷新小组件。
- 应用回到前台时 `HomePage.didChangeAppLifecycleState` → `AppProvider.syncFromWidget()` 读取小组件最新数据，按索引同步本地任务/积分。

### 15.2 原生文件

| 文件 | 作用 |
| --- | --- |
| [TaskWidgetProvider.java](file:///workspace/android/app/src/main/java/com/noteapp/taskmaster/TaskWidgetProvider.java) | `AppWidgetProvider` 子类，渲染与点击处理；`ACTION_TOGGLE_TASK` 广播 |
| [task_widget.xml](file:///workspace/android/app/src/main/res/layout/task_widget.xml) | 小组件布局（日期、积分、5 条任务项、空状态、打开应用按钮） |
| [task_widget_info.xml](file:///workspace/android/app/src/main/res/xml/task_widget_info.xml) | 小组件元数据：最小 320×180dp、30 分钟更新、可水平/垂直缩放 |
| [AndroidManifest.xml](file:///workspace/android/app/src/main/AndroidManifest.xml#L29-L38) | 注册 `TaskWidgetProvider` receiver 与 `APPWIDGET_UPDATE`/`TOGGLE_TASK` intent-filter |
| [MainActivity.kt](file:///workspace/android/app/src/main/kotlin/com/noteapp/taskmaster/MainActivity.kt) | MethodChannel `flutter.native/helper`，处理 `getIntentExtras`（`refresh_widget`） |

### 15.3 drawable 资源

[android/app/src/main/res/drawable/](file:///workspace/android/app/src/main/res/drawable)：`ic_checkbox_checked/unchecked`、`ic_star`、`button_background`、`points_background`、`widget_background`、`launch_background` 等小组件视觉资源。

---

## 16. 依赖关系图

### 16.1 运行时依赖（pubspec）

```
flutter ── cupertino_icons
       ├─ sqflite ── path
       ├─ provider
       ├─ home_widget
       ├─ shared_preferences
       ├─ path_provider
       └─ vibration
```

### 16.2 模块依赖（lib 内部）

```
main.dart
  └─ AppProvider ──┬─ TaskProvider ──── TaskRepository ─┐
                  ├─ PointsProvider ─ PointsRepository ─┤
                  ├─ ShopProvider ─── ShopRepository ────┤── DatabaseService (单例) ── SQLite
                  └─ SettingsProvider ─ SettingsRepository ┘
       │
       ├─ WidgetService ── home_widget ── 原生小组件
       └─ DataMigrationService ── DatabaseService / path_provider

pages / components
  └─ context.watch/read<AppProvider>  （单向消费）

use_cases
  └─ 注入 repositories  （TaskUseCases 兼依赖 PointsRepository）
```

### 16.3 跨域编排点

- 完成任务：`TaskProvider.completeTask` → `TaskRepository.completeTask` + `PointsRepository.addPoints`。
- 过期扣分：`TaskProvider._checkOverdueTasks` → `TaskRepository.getOverdueTasks/markTaskDeducted` + `PointsRepository.deductPoints`。
- 购买商品：`ShopProvider.purchaseItem` → `PointsRepository.deductPoints` + `ShopRepository.addPurchasedItem`。
- 小组件同步：`AppProvider.syncFromWidget` → `WidgetService.readWidgetData` → `TaskProvider` + `PointsProvider`。

---

## 17. 核心数据流

### 17.1 任务完成（积分奖励）

```
用户勾选任务
  → TaskPage._onTaskCheckChanged
  → AppProvider.task.completeTask(task)
  → TaskRepository.completeTask(id)  [isOK=1, completedAt=now]
  → PointsRepository.addPoints(rewardPoints)  [user_points]
  → TaskProvider.loadTasksByDate  [notifyListeners]
  → AppProvider._onSubProviderChanged  [notifyListeners]
  → WidgetService.updateWidgetData  [刷新桌面小组件]
  → UI 重绘（TaskPage / 积分胶囊）
```

### 17.2 循环任务生成

```
addTask(recurrence≠none, loopId=null)
  → 生成 loopId
  → _insertTaskIfNotExists（按 loopId+日期 去重）
  → _generateTaskRange  [从今日到+15天，按 daily/weekly/monthly 生成实例]
  → loadTasksByDate + 更新小组件
```

### 17.3 应用回前台同步小组件

```
AppLifecycleState.resumed
  → AppProvider.syncFromWidget
  → WidgetService.readWidgetData
  → 按索引对比 isOK：完成→completeTask+addPoints；取消→uncompleteTask+deductPoints
  → 积分不同→updatePoints
  → loadTasksByDate
```

### 17.4 数据导入

```
SettingsPage 触发
  → DataMigrationService.importData(filePath)
  → _createBackup  [自动备份]
  → db.transaction：清空六表 → 逐项 insert*
  → 失败自动回滚
```

---

## 18. 项目运行方式

### 18.1 环境准备

1. 安装 Flutter SDK（`^3.11.1`），执行 `flutter doctor` 确认工具链。
2. 选择目标平台：Android（Android Studio/SDK）、iOS（Xcode）、Web、Windows、macOS、Linux。

### 18.2 运行步骤

```bash
# 1. 安装依赖
flutter pub get

# 2. 运行（默认设备）
flutter run

# 3. 指定平台/设备
flutter run -d chrome        # Web
flutter run -d windows        # Windows
flutter run -d <device-id>    # 指定设备
```

### 18.3 构建产物

```bash
flutter build apk            # Android
flutter build apk --release
flutter build web
flutter build windows
flutter build macos
flutter build ios
```

### 18.4 数据与存储位置

- SQLite 数据库：`getDatabasesPath()/v5_tasks.db`。
- 小组件数据：`HomeWidgetPreferences`（Android SharedPreferences）。
- 番茄钟配置：`SharedPreferences`（键 `pomodoro_*`）。
- 数据导出：`getExternalStorageDirectory()/taskmaster_backup.json`（及带时间戳的自动备份）。

---

## 19. 多平台支持

| 平台 | 配置目录 | 说明 |
| --- | --- | --- |
| Android | [android/](file:///workspace/android) | 原生小组件、MethodChannel、`MainActivity.kt` |
| iOS | [ios/Runner/](file:///workspace/ios/Runner) | AppDelegate/SceneDelegate、Info.plist、启动图 |
| Web | [web/](file:///workspace/web) | `index.html`、PWA `manifest.json`、icons |
| Windows | [windows/](file:///workspace/windows) | CMake 构建、`flutter_window.cpp` |
| macOS | [macos/Runner/](file:///workspace/macos/Runner) | AppDelegate、entitlements |
| Linux | [linux/](file:///workspace/linux) | CMake 构建、`my_application.cc` |

核心业务逻辑（`lib/`）全平台共享，仅通过平台目录与条件判断适配差异。桌面小组件目前仅 Android 原生实现。

---

## 附：版本与文档

- 应用版本：`5.2.1+21`（[pubspec.yaml](file:///workspace/pubspec.yaml#L19)），版本历史见 [README.md](file:///workspace/README.md#L41-L125)。
- 重构记录：[docs/REFACTOR_PLAN.md](file:///workspace/docs/REFACTOR_PLAN.md)、[docs/V5.1.0重构后变更摘要.md](file:///workspace/docs/V5.1.0重构后变更摘要.md)。
- 架构与功能记录：[docs/architecture.md](file:///workspace/docs/architecture.md)、[docs/kf.md](file:///workspace/docs/kf.md)。
- 项目规则：[.trae/rules/documentation-rules.md](file:///workspace/.trae/rules/documentation-rules.md)、[.trae/rules/skutru-ruler.md](file:///workspace/.trae/rules/skutru-ruler.md)。
