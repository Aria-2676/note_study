# 项目文档规范

## 1. 项目 README.md（根目录）
- **文件位置**：项目根目录
- **内容要求**：
  - 项目简介
  - 功能特点
  - 技术栈
  - 运行方式
  - 项目结构
  - 版本历史（每次更新都要添加）

## 2. 功能模块文档（kf.md）
- **文件位置**：`docs/kf.md`
- **内容要求**：
  - 按模块划分（任务管理、积分系统、商城系统等）
  - 每个功能包含：
    - 功能描述
    - 核心文件位置
    - 关键函数列表及作用
    - 实现逻辑简述
    - 调用关系（可选）

## 2. API/函数文档
- **使用Dart doc comments**：为关键函数添加文档注释
- **内容包括**：
  - 函数作用
  - 参数说明
  - 返回值说明
  - 调用示例
  - 注意事项

## 3. 架构文档（可选）
- **文件位置**：`docs/architecture.md`
- **内容要求**：
  - 整体架构描述
  - 模块间依赖关系
  - 数据流说明
  - 状态管理方案

## 4. 文档维护
- **与代码同步**：每次修改功能时同步更新文档
- **版本控制**：文档纳入Git管理
- **定期审查**：确保文档准确性和完整性
- **简洁实用**：只记录关键信息，避免文档膨胀

## 5. 功能实现记录（kf.md）
- 任务管理：`lib/pages/task_page.dart`
- 积分系统：`lib/pages/mine_page.dart`（积分显示和管理）
- 商城系统：`lib/pages/shop_page.dart`
- 桌面小组件：`lib/pages/widget_guide_page.dart` 和 `lib/services/widget_service.dart`
- 主题切换：`lib/pages/settings_page.dart`
- 数据存储：`lib/services/database_service.dart`
- 状态管理：`lib/providers/app_provider.dart`