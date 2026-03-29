# 项目架构文档

## 1. 整体架构

### 技术栈
- **框架**：Flutter 3.11+
- **语言**：Dart
- **状态管理**：Provider
- **数据库**：SQLite (sqflite)
- **桌面小组件**：home_widget
- **存储**：shared_preferences

### 架构模式
- **MVC 架构**：
  - **Model**：数据模型（`lib/models/`）
  - **View**：页面组件（`lib/pages/`）
  - **Controller**：状态管理和业务逻辑（`lib/providers/`、`lib/services/`）

## 2. 模块间依赖关系

```
┌─────────────────┐      ┌─────────────────┐      ┌─────────────────┐
│                 │      │                 │      │                 │
│   页面组件      │◄─────┤   状态管理      │◄─────┤   服务层        │
│ lib/pages/      │      │ lib/providers/  │      │ lib/services/   │
│                 │      │                 │      │                 │
└─────────────────┘      └─────────────────┘      └─────────────────┘
          ▲                        │                        │
          │                        ▼                        ▼
          │              ┌─────────────────┐      ┌─────────────────┐
          │              │                 │      │                 │
          └──────────────┤   数据模型      │      │   外部依赖      │
                         │ lib/models/     │      │ pubspec.yaml    │
                         │                 │      │                 │
                         └─────────────────┘      └─────────────────┘
```

## 3. 数据流说明

### 数据流向
1. **用户交互** → 页面组件（pages）
2. **页面组件** → 状态管理（providers）
3. **状态管理** → 服务层（services）
4. **服务层** → 数据持久化（SQLite）
5. **服务层** → 状态管理（providers）
6. **状态管理** → 页面组件（pages）
7. **页面组件** → UI 更新

### 核心数据流
- **任务管理**：用户操作 → TaskPage → AppProvider → DatabaseService → SQLite → AppProvider → TaskPage
- **积分系统**：任务完成 → AppProvider → DatabaseService → SQLite → AppProvider → MinePage
- **商城系统**：购买商品 → AppProvider → DatabaseService → SQLite → AppProvider → ShopPage/WarehousePage

## 4. 状态管理方案

### Provider 架构
- **AppProvider**：全局状态管理，管理所有应用状态
  - 任务列表
  - 积分数据
  - 商城商品
  - 主题设置
  - 视图模式

### 状态更新流程
1. **状态变更**：通过 AppProvider 的方法修改状态
2. **通知监听**：调用 `notifyListeners()` 通知所有监听者
3. **UI 更新**：Consumer 组件接收通知并更新 UI

### 性能优化
- **选择性监听**：使用 `Selector` 只监听需要的状态
- **批量更新**：合并多个状态更新为一次通知
- **延迟加载**：按需加载数据，避免一次性加载所有数据

## 5. 多平台适配

### 平台特定代码
- **Android**：`android/app/src/main/`
  - 原生小组件实现
  - 平台特定配置
- **iOS**：`ios/Runner/`
  - 平台特定配置
  - 权限配置
- **Web**：`web/`
  - Web 特定配置
  - PWA 支持
- **Windows/macOS/Linux**：平台特定配置

### 跨平台统一
- **核心逻辑**：所有平台共享同一套业务逻辑
- **UI 适配**：使用 Flutter 的自适应布局
- **平台特性**：通过条件编译处理平台差异

## 6. 扩展性考虑

### 模块划分
- **松耦合**：模块间通过明确的接口通信
- **可替换性**：服务层可轻松替换实现
- **可测试性**：依赖注入便于单元测试

### 未来扩展
- **新功能**：可通过添加新页面和服务实现
- **新平台**：Flutter 支持的平台可直接构建
- **性能优化**：可通过缓存、懒加载等方式优化