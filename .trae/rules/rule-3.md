规范 3：工程结构与命名
固定目录
lib/core/services/：全局服务（WidgetService/StatisticService）；
lib/providers/：所有状态管理类；
lib/modules/ 模块 /：pages、adapters、utils。
命名规则
所有文件：小写 + 下划线（task_provider.dart、task_statistic_adapter.dart），遵循 Dart 官方风格指南；
类名：大驼峰（TaskProvider、TaskStatisticAdapter）；
禁止中文、无意义名（page.dart、utils1.dart）。
隔离规则
业务模块完全独立，新增模块只加目录，不修改其他模块代码；
模块交互仅通过 Provider，禁止直接调用其他模块服务。