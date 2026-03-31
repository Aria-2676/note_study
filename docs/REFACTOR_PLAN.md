# 项目重构计划书

## 1. 重构目标

### 1.1 核心目标
- 提高代码可维护性和可测试性
- 实现更清晰的模块化结构
- 分离业务逻辑与UI逻辑
- 优化状态管理架构
- 提升代码质量和可读性

### 1.2 具体目标
- **状态管理**：将单一的AppProvider拆分为多个功能专一的Provider
- **业务逻辑**：分离业务逻辑到专门的层
- **UI组件**：提取可复用组件，减少代码重复
- **服务层**：增强服务层的抽象性和可扩展性
- **代码质量**：添加必要的测试和错误处理

## 2. 重构前分析

### 2.1 当前结构
- `lib/main.dart`：包含应用入口和主页面，混合了UI和业务逻辑
- `lib/providers/app_provider.dart`：单一的状态管理文件，包含所有业务逻辑（756行）
- `lib/models/`：数据模型层
- `lib/pages/`：页面层
- `lib/services/`：服务层
- `lib/utils/`：工具类

### 2.2 主要问题
- **状态管理集中度过高**：AppProvider承担过多职责
- **UI逻辑与业务逻辑混合**：main.dart中的任务对话框代码过长
- **模块化粒度不够细**：缺乏清晰的领域边界
- **代码重复**：存在重复的代码模式
- **测试覆盖不足**：缺乏单元测试和集成测试

## 3. 重构后结构

### 3.1 目录结构
```
lib/
├── models/              # 数据模型
├── pages/               # 页面
├── providers/           # 状态管理
│   ├── task_provider.dart
│   ├── points_provider.dart
│   ├── shop_provider.dart
│   ├── settings_provider.dart
│   └── app_provider.dart (简化版，作为聚合)
├── services/            # 服务层
│   ├── database_service.dart
│   ├── widget_service.dart
│   └── import_export_service.dart
├── repositories/        # 数据访问层
│   ├── task_repository.dart
│   ├── points_repository.dart
│   ├── shop_repository.dart
│   └── settings_repository.dart
├── use_cases/           # 业务逻辑层
│   ├── task_use_cases.dart
│   ├── points_use_cases.dart
│   ├── shop_use_cases.dart
│   └── settings_use_cases.dart
├── components/          # 可复用组件
│   ├── task_dialog.dart
│   ├── calendar_view.dart
│   └── points_display.dart
├── utils/               # 工具类
└── main.dart            # 应用入口
```

### 3.2 模块职责
- **models**：数据模型定义
- **providers**：状态管理，负责UI状态
- **repositories**：数据访问，处理与数据库的交互
- **use_cases**：业务逻辑，处理核心业务规则
- **components**：可复用UI组件
- **services**：外部服务，如小组件、导入导出等

## 4. 重构步骤

### 4.1 第一阶段：状态管理重构
1. 分析AppProvider中的功能，识别不同领域
2. 创建专门的Provider：TaskProvider、PointsProvider、ShopProvider、SettingsProvider
3. 迁移相应的状态和方法到各自的Provider
4. 保留AppProvider作为聚合，负责协调各个子Provider

### 4.2 第二阶段：业务逻辑分离
1. 创建repositories目录，实现数据访问层
2. 创建use_cases目录，实现业务逻辑层
3. 将业务逻辑从Provider中迁移到use_cases
4. 重构Provider，使其只负责状态管理

### 4.3 第三阶段：UI组件化
1. 分析main.dart中的任务对话框代码
2. 提取为独立的TaskDialog组件
3. 识别其他可复用的UI元素，提取为组件
4. 重构页面，使用新的组件

### 4.4 第四阶段：服务层增强
1. 增强数据库服务的抽象性
2. 实现统一的错误处理机制
3. 添加日志系统

### 4.5 第五阶段：代码质量提升
1. 添加单元测试
2. 实现代码规范检查
3. 优化性能和内存使用

## 5. 实施计划

### 5.1 时间估计
- 第一阶段：2-3天
- 第二阶段：2-3天
- 第三阶段：1-2天
- 第四阶段：1天
- 第五阶段：1-2天

### 5.2 风险评估
- **风险**：重构可能引入新的bug
- **缓解措施**：
  - 分阶段实施，每个阶段都进行测试
  - 保留原始代码备份
  - 编写单元测试确保功能正常

### 5.3 测试策略
- 每个重构阶段完成后进行功能测试
- 重构完成后进行全面的回归测试
- 确保所有现有功能正常工作

## 6. 预期成果

### 6.1 代码质量
- 更清晰的代码结构
- 更好的可维护性
- 更高的代码可读性

### 6.2 功能完整性
- 保持所有现有功能
- 提高系统的可扩展性
- 为未来功能添加做好准备

### 6.3 开发效率
- 降低新功能开发的复杂度
- 减少bug修复的时间
- 提高团队协作效率

## 7. 总结

本重构计划旨在通过结构化的方法，提高项目的代码质量和可维护性。通过分阶段实施，可以确保重构过程的可控性和安全性，同时实现重构的目标。重构后，项目将具备更好的架构基础，为未来的功能扩展和维护打下坚实的基础。