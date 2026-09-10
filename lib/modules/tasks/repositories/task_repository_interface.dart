import '../../tasks/models/task_model.dart';

/// 任务数据仓储抽象接口
///
/// 定义任务数据访问的契约，具体实现由 [TaskRepositoryImpl] 完成。
/// 通过接口抽象便于 Provider 以接口类型持有依赖、测试时注入 Mock。
abstract class TaskRepository {
  /// 获取指定日期的任务列表
  Future<List<Task>> getTasksForDate(DateTime date);

  /// 新增单个任务（含重复检测，不含循环任务生成）
  Future<Task> addTask(Task task);

  /// 更新任务，[updateAll] 为 true 时同步更新同 loop 的后续任务
  Future<void> updateTask(Task task, {bool updateAll = false});

  /// 删除任务，[deleteAll] 为 true 时同步删除同 loop 的后续任务
  Future<void> deleteTask(int id, {bool deleteAll = false});

  /// 完成任务
  Future<String?> completeTask(Task task);

  /// 取消完成任务
  Future<void> uncompleteTask(Task task);

  /// 获取所有循环任务
  Future<List<Task>> getRecurringTasks();

  /// 获取截至 [date] 的逾期未完成任务（仅非循环任务）
  Future<List<Task>> getOverdueTasks(DateTime date);

  /// 获取指定日期范围内的任务
  Future<List<Task>> getTasksByDateRange(DateTime start, DateTime end);

  /// 获取指定 loop_id 的任务列表
  Future<List<Task>> getTasksByLoopId(String loopId);

  /// 按条件搜索任务（SQL 下推，避免全表加载）
  Future<List<Task>> searchTasks(
    String query, {
    DateTime? startDate,
    DateTime? endDate,
    bool? completionStatus,
    int limit = 50,
    int offset = 0,
  });

  /// 标记任务为已扣分
  Future<void> markTaskDeducted(int id);

  /// 从回收站还原任务
  Future<Task> restoreTaskFromRecycle(int recycledTaskId);

  /// 从回收站彻底删除任务
  Future<void> deleteFromRecycle(int recycledTaskId);

  /// 清空回收站
  Future<void> clearRecycleBin();

  /// 获取回收站任务列表
  Future<List<RecycledTask>> getRecycledTasks();
}
