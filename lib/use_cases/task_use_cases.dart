import '../models/task.dart';
import '../models/recycled_task.dart';
import '../repositories/task_repository.dart';
import '../repositories/points_repository.dart';

class TaskUseCases {
  final TaskRepository _taskRepo;
  final PointsRepository _pointsRepo;

  TaskUseCases(this._taskRepo, this._pointsRepo);

  // 获取指定日期的任务
  Future<List<Task>> getTasksByDate(DateTime date) async {
    return await _taskRepo.getTasksByDate(date);
  }

  // 获取所有任务
  Future<List<Task>> getAllTasks() async {
    return await _taskRepo.getAllTasks();
  }

  // 获取循环任务
  Future<List<Task>> getRecurringTasks() async {
    return await _taskRepo.getRecurringTasks();
  }

  // 检查过期任务并扣除积分
  Future<void> checkOverdueTasks() async {
    final overdueTasks = await _taskRepo.getOverdueTasks(DateTime.now());
    for (final task in overdueTasks) {
      if (task.rewardPoints > 0 && !task.isDeducted) {
        final deductPoints = (task.rewardPoints / 2).floor();
        if (deductPoints > 0) {
          await _pointsRepo.deductPoints(deductPoints);
          await _taskRepo.markTaskDeducted(task.id!);
        }
      }
    }
  }

  // 添加任务
  Future<void> addTask(Task task) async {
    await _taskRepo.createTask(task);
  }

  // 更新任务
  Future<void> updateTask(Task task) async {
    await _taskRepo.updateTask(task);
  }

  // 删除任务
  Future<void> deleteTask(int id) async {
    await _taskRepo.deleteTask(id);
  }

  // 完成任务
  Future<String?> completeTask(Task task) async {
    final now = DateTime.now();
    if (task.cplTime.year != now.year ||
        task.cplTime.month != now.month ||
        task.cplTime.day != now.day) {
      return '当前日期不是任务日期，不能完成任务';
    }
    await _taskRepo.completeTask(task.id!);

    if (task.rewardPoints > 0) {
      await _pointsRepo.addPoints(task.rewardPoints);
    }

    return null;
  }

  // 取消完成任务
  Future<void> uncompleteTask(Task task) async {
    await _taskRepo.uncompleteTask(task.id!);

    if (task.rewardPoints > 0) {
      await _pointsRepo.deductPoints(task.rewardPoints);
    }
  }

  // 从回收站恢复任务
  Future<Task> restoreTaskFromRecycle(int recycledTaskId) async {
    return await _taskRepo.restoreTaskFromRecycle(recycledTaskId);
  }

  // 从回收站删除任务
  Future<void> deleteFromRecycle(int recycledTaskId) async {
    await _taskRepo.deleteFromRecycle(recycledTaskId);
  }

  // 清空回收站
  Future<void> clearRecycleBin() async {
    await _taskRepo.clearRecycleBin();
  }

  // 获取回收站任务
  Future<List<RecycledTask>> getRecycledTasks() async {
    return await _taskRepo.getRecycledTasks();
  }
}
