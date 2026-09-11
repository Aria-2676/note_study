part of '../task_provider.dart';

/// 「完成 / 取消完成」结算涉及的积分流水类型。
const List<String> _taskSettlementTypes = [
  'task_complete',
  'task_uncomplete',
];

/// 完成/取消完成的积分结算，以及逾期任务的扣分。
mixin TaskSettlementMixin on TaskProviderCoreMixin {
  Future<bool> _shouldHandlePoints(Task task, String type) async {
    if (task.id == null || task.rewardPoints <= 0) return false;
    return !await _pointsProvider.hasRecordForTypeAndRelatedId(type, task.id!);
  }

  /// 取任务最近一条结算流水（按写入顺序，最后一条即当前结算状态）。
  Future<PointsRecord?> _latestTaskSettlement(int taskId) {
    return _pointsProvider.getLatestRecord(taskId, _taskSettlementTypes);
  }

  /// 结算「完成任务」的积分。
  ///
  /// 仅当任务当前处于「未加分」状态时才加分：取消完成会写入一条冲销流水，
  /// 因此最后一条流水是扣分记录时，再次完成可以重新加分（状态可逆，
  /// 不会出现「取消过一次后该任务永久不再给分」）。
  Future<void> _settleTaskCompleted(Task task, String description) async {
    final int? taskId = task.id;
    if (taskId == null || task.rewardPoints <= 0) return;

    final latest = await _latestTaskSettlement(taskId);
    if (latest?.type == 'task_complete') return;

    await _pointsProvider.addPointsWithRecord(
      points: task.rewardPoints,
      type: 'task_complete',
      description: description,
      relatedId: taskId,
    );
  }

  /// 冲销「完成任务」的积分。
  ///
  /// 退还当初实际加过的分数（取加分流水的 points，而非任务当前的 rewardPoints），
  /// 即使任务在完成期间被改过奖励值，加减依然对称。
  Future<void> _settleTaskUncompleted(Task task, String description) async {
    final int? taskId = task.id;
    if (taskId == null) return;

    final latest = await _latestTaskSettlement(taskId);
    if (latest == null || latest.type != 'task_complete') return;

    await _pointsProvider.deductPointsWithRecord(
      points: latest.points,
      type: 'task_uncomplete',
      description: description,
      relatedId: taskId,
    );
  }

  Future<void> _checkOverdueTasks() async {
    final overdueTasks = await _taskRepository.getOverdueTasks(DateTime.now());
    for (final task in overdueTasks) {
      final int? taskId = task.id;
      if (taskId == null || task.isOK || task.isDeducted) continue;
      if (task.rewardPoints <= 0) continue;

      final int deductPoints = (task.rewardPoints / 2).floor();
      if (deductPoints > 0 &&
          await _shouldHandlePoints(task, 'overdue_deduct')) {
        await _pointsProvider.deductPointsWithRecord(
          points: deductPoints,
          type: 'overdue_deduct',
          description: '逾期任务扣除: ${task.title}',
          relatedId: taskId,
        );
      }
      // 扣分成功后再标记「已扣分」。若放在扣分之前，一旦扣分失败，
      // is_deducted 已置位会导致该任务在后续启动中被永久漏扣。
      await _taskRepository.markTaskDeducted(taskId);
    }
  }
}
