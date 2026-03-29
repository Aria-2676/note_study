# 功能模块实现记录

## 1. 任务管理
- **功能描述**：创建、编辑、删除任务，标记任务完成状态，支持循环任务
- **核心文件**：`lib/pages/task_page.dart`
- **关键函数**：
  - `_addTask()`：添加新任务
  - `_editTask()`：编辑现有任务
  - `_deleteTask()`：删除任务
  - `_completeTask()`：标记任务完成
  - `_uncompleteTask()`：取消任务完成
- **实现逻辑**：通过 `AppProvider` 管理任务状态，使用 `DatabaseService` 进行数据持久化

## 2. 积分系统
- **功能描述**：完成任务获得积分，积分显示和管理
- **核心文件**：`lib/pages/mine_page.dart`、`lib/providers/app_provider.dart`
- **关键函数**：
  - `addPoints()`：添加积分
  - `deductPoints()`：扣除积分
  - `_loadUserPoints()`：加载用户积分
- **实现逻辑**：任务完成时通过 `AppProvider` 调用 `DatabaseService` 更新积分

## 3. 商城系统
- **功能描述**：用积分兑换各种奖励，查看已购买的商品
- **核心文件**：`lib/pages/shop_page.dart`、`lib/pages/warehouse_page.dart`
- **关键函数**：
  - `purchaseItem()`：购买商品
  - `_loadShopItems()`：加载商城商品
  - `_loadPurchasedItems()`：加载已购买商品
- **实现逻辑**：通过 `AppProvider` 管理商品和购买记录，使用 `DatabaseService` 进行数据持久化

## 4. 桌面小组件
- **功能描述**：在桌面显示任务和积分，快速完成任务
- **核心文件**：`lib/pages/widget_guide_page.dart`、`lib/services/widget_service.dart`
- **关键函数**：
  - `updateWidgetData()`：更新小组件数据
  - `syncFromWidget()`：从小组件同步数据
  - `init()`：初始化小组件
- **实现逻辑**：通过 `HomeWidget` 插件与原生小组件通信，使用 `SharedPreferences` 存储小组件数据

## 5. 主题切换
- **功能描述**：在亮色和暗色模式之间切换
- **核心文件**：`lib/pages/settings_page.dart`、`lib/providers/app_provider.dart`
- **关键函数**：
  - `toggleTheme()`：切换主题
  - `_loadSettings()`：加载主题设置
  - `_saveSettings()`：保存主题设置
- **实现逻辑**：通过 `AppProvider` 管理主题状态，使用 `DatabaseService` 持久化设置

## 6. 数据存储
- **功能描述**：任务、积分、商品等数据的持久化存储
- **核心文件**：`lib/services/database_service.dart`
- **关键函数**：
  - `createTask()`：创建任务
  - `getTasksByDate()`：按日期获取任务
  - `completeTask()`：标记任务完成
  - `addPoints()`：添加积分
  - `getUserPoints()`：获取用户积分
  - `createShopItem()`：创建商品
  - `getAllShopItems()`：获取所有商品
- **实现逻辑**：使用 `sqflite` 库操作 SQLite 数据库，实现数据的增删改查

## 7. 状态管理
- **功能描述**：管理应用的全局状态，包括任务、积分、商品等
- **核心文件**：`lib/providers/app_provider.dart`
- **关键函数**：
  - `initialize()`：初始化应用状态
  - `loadTasksByDate()`：加载指定日期的任务
  - `addTask()`：添加任务
  - `purchaseItem()`：购买商品
  - `toggleTheme()`：切换主题
- **实现逻辑**：使用 `Provider` 包实现状态管理，通过 `notifyListeners()` 通知UI更新

## 8. 页面导航
- **功能描述**：底部导航栏切换不同页面
- **核心文件**：`lib/main.dart`
- **关键函数**：
  - `_HomePageState`：管理底部导航栏状态
  - `_onItemTapped()`：处理导航栏点击
- **实现逻辑**：使用 `BottomNavigationBar` 实现底部导航，通过 `setState()` 管理当前选中的页面

## 9. 帮助和设置
- **功能描述**：应用使用指南和设置选项
- **核心文件**：`lib/pages/help_page.dart`、`lib/pages/settings_page.dart`
- **关键函数**：
  - `_loadVersion()`：加载应用版本
  - `_clearCache()`：清除缓存
- **实现逻辑**：通过静态页面展示使用指南，提供设置选项和版本信息

## 10. 多平台支持
- **功能描述**：支持 Android、iOS、Web、Windows、macOS、Linux 平台
- **核心文件**：各平台特定配置文件
  - Android：`android/app/src/main/`
  - iOS：`ios/Runner/`
  - Web：`web/`
  - Windows：`windows/runner/`
  - macOS：`macos/Runner/`
  - Linux：`linux/runner/`
- **实现逻辑**：使用 Flutter 的跨平台能力，通过平台特定配置适配不同平台