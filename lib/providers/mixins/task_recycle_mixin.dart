part of '../task_provider.dart';

/// 回收站的读取、恢复与清空。
mixin TaskRecycleMixin on TaskProviderCoreMixin, TaskCrudMixin {
  Future<void> restoreTaskFromRecycle(int recycledTaskId) async {
    final recycledTask = _recycledTasks.firstWhere(
      (t) => t.id == recycledTaskId,
    );
    final originalCplTime = recycledTask.task.cplTime;
    final restoredTask = await _taskRepository.restoreTaskFromRecycle(
      recycledTaskId,
    );
    _invalidateMonthCache(originalCplTime);

    if (restoredTask.recurrence != 'none') {
      await _taskSchedulerService.generateRecurringTasks(
        restoredTask.copyWith(cplTime: originalCplTime),
      );
    }
    await _loadRecycledTasks();
    await loadTasksByDate(_selectedDate);
  }

  Future<void> deleteFromRecycle(int recycledTaskId) async {
    await _taskRepository.deleteFromRecycle(recycledTaskId);
    await _loadRecycledTasks();
  }

  Future<void> clearRecycleBin() async {
    await _taskRepository.clearRecycleBin();
    await _loadRecycledTasks();
  }
}
