import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:home_widget/home_widget.dart';
import '../modules/tasks/models/task_model.dart';
import '../modules/tasks/repositories/task_repository.dart';
import '../modules/tasks/services/task_scheduler_service.dart';
import '../core/services/database/database_service.dart';
import '../core/services/widget_service.dart';
import '../core/utils/app_logger.dart';
import '../core/utils/task_sort_utils.dart';
import '../modules/points/models/points_model.dart';
import 'points_provider.dart';

part 'mixins/task_provider_core_mixin.dart';
part 'mixins/task_settlement_mixin.dart';
part 'mixins/task_query_mixin.dart';
part 'mixins/task_widget_mixin.dart';
part 'mixins/task_crud_mixin.dart';
part 'mixins/task_recycle_mixin.dart';
part 'mixins/task_batch_mixin.dart';

/// 任务列表的排序方式。
enum TaskSortOption {
  defaultOrder,
  priority,
  completionStatus,
  createdTime,
  completionTime,
}

/// 任务模块的状态中枢（[ChangeNotifier]）。
///
/// 该类的职责较多，为满足「文件 ≤500 行 / 类 ≤300 行」的工程约束，实现按关注点
/// 拆分到 `mixins/` 下的多个 part 文件（属于同一 library，因此可共享私有状态）：
///
/// - [TaskProviderCoreMixin]：共享状态、月份缓存与跨关注点的公共方法
/// - [TaskSettlementMixin]：完成/取消完成的积分结算与逾期扣分
/// - [TaskQueryMixin]：搜索、筛选、排序
/// - [TaskWidgetMixin]：桌面小组件数据更新
/// - [TaskCrudMixin]：任务增删改查与日期选择
/// - [TaskRecycleMixin]：回收站
/// - [TaskBatchMixin]：批量操作
///
/// 各 mixin 通过 `on` 约束声明其依赖，只有被依赖的 mixin 出现在 `on` 列表中时，
/// 才能访问对方的成员（Dart 的 mixin 无法直接访问兄弟 mixin 的成员）。
class TaskProvider extends ChangeNotifier
    with
        TaskProviderCoreMixin,
        TaskSettlementMixin,
        TaskQueryMixin,
        TaskWidgetMixin,
        TaskCrudMixin,
        TaskRecycleMixin,
        TaskBatchMixin {
  TaskProvider(
    PointsProvider pointsProvider, {
    TaskRepository? taskRepository,
    TaskSchedulerService? taskSchedulerService,
  }) {
    _pointsProvider = pointsProvider;
    _taskRepository =
        taskRepository ?? TaskRepositoryImpl(DatabaseService.instance);
    _taskSchedulerService =
        taskSchedulerService ??
        TaskSchedulerService(
          taskRepository ?? TaskRepositoryImpl(DatabaseService.instance),
          DatabaseService.instance,
        );
  }

  /// 应用启动时的初始化流程：准备小组件、加载回收站、检查逾期、加载今日任务、
  /// 检查循环任务，最后刷新桌面小组件。
  Future<void> initialize() async {
    await WidgetService.init();
    await _loadRecycledTasks();
    await _checkOverdueTasks();
    await loadTasksByDate(DateTime.now());
    await autoCheckRecurringTasks();
    _debouncedUpdateWidget();
  }
}
