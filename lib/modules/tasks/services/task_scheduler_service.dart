import 'dart:math';

import 'package:sqflite/sqflite.dart';

import '../../../core/services/database/database_gateway.dart';
import '../models/task_model.dart';
import '../repositories/task_repository_interface.dart';

/// 任务调度服务
///
/// 从 [TaskRepositoryImpl] 迁出的循环任务生成、逾期检查等业务逻辑
/// 集中在此处。Repository 只负责单次数据读写，调度逻辑独立于数据访问。
/// 循环任务批量生成在单事务内完成，避免多次往返与中间不一致。
class TaskSchedulerService {
  final TaskRepository _repository;
  final DatabaseGateway _gateway;

  TaskSchedulerService(this._repository, this._gateway);

  /// 生成循环任务唯一 loop_id
  String generateLoopId() {
    return 'loop_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(10000)}';
  }

  /// 生成未来 15 天内的循环任务实例
  ///
  /// 在单事务内逐日检测重复并插入，避免逐条独立事务的开销。
  Future<void> generateRecurringTasks(Task task) async {
    final now = DateTime.now();
    final rangeEnd = now.add(const Duration(days: 15));

    var next = DateTime(task.cplTime.year, task.cplTime.month, task.cplTime.day);

    final db = await _gateway.database;
    await db.transaction((txn) async {
      while (!next.isAfter(rangeEnd)) {
        if (task.recurrence == 'daily') {
          await _insertIfNotExistsTxn(txn, task, next);
          next = next.add(const Duration(days: 1));
          continue;
        }
        if (task.recurrence == 'weekly') {
          while (next.weekday != task.cplTime.weekday) {
            next = next.add(const Duration(days: 1));
          }
          if (next.isAfter(rangeEnd)) break;
          await _insertIfNotExistsTxn(txn, task, next);
          next = next.add(const Duration(days: 7));
          continue;
        }
        if (task.recurrence == 'monthly') {
          int day = task.cplTime.day;
          int daysInMonth = DateTime(next.year, next.month + 1, 0).day;
          day = day > daysInMonth ? daysInMonth : day;
          var monthlyDate = DateTime(next.year, next.month, day);

          if (!monthlyDate.isAfter(rangeEnd)) {
            await _insertIfNotExistsTxn(txn, task, monthlyDate);
          }

          int nextMonth = next.month + 1;
          int nextYear = next.year;
          if (nextMonth > 12) {
            nextMonth = 1;
            nextYear++;
          }
          next = DateTime(nextYear, nextMonth, 1);
          continue;
        }
        break;
      }
    });
  }

  /// 在事务内检测重复并插入循环任务实例
  Future<void> _insertIfNotExistsTxn(
    Transaction txn,
    Task task,
    DateTime date,
  ) async {
    if (task.loopId == null) return;
    final start = DateTime(date.year, date.month, date.day);
    final end = start.add(const Duration(days: 1));
    final exists = await txn.query(
      'tasks',
      columns: ['id'],
      where: 'loop_id = ? AND cpl_time >= ? AND cpl_time < ?',
      whereArgs: [task.loopId, start.toIso8601String(), end.toIso8601String()],
      limit: 1,
    );
    if (exists.isNotEmpty) return;
    final instance = task.copyWith(
      id: null,
      cplTime: date,
      isOK: false,
      completedAt: null,
      isDeducted: false,
    );
    await txn.insert('tasks', instance.toMap());
  }

  /// 自动检查并补全循环任务
  ///
  /// 取每个循环模式中最早的一条作为模板，生成未来实例。
  Future<void> autoCheckRecurringTasks() async {
    final recurringTasks = await _repository.getRecurringTasks();
    if (recurringTasks.isEmpty) return;
    final uniquePatterns = <String, Task>{};

    for (var task in recurringTasks) {
      final key =
          task.loopId ??
          '${task.title}||${task.description}||${task.recurrence}||${task.isWord}||${task.rewardPoints}';
      if (!uniquePatterns.containsKey(key) ||
          uniquePatterns[key]!.cplTime.isAfter(task.cplTime)) {
        uniquePatterns[key] = task;
      }
    }

    final futures = <Future>[];
    for (var task in uniquePatterns.values) {
      futures.add(generateRecurringTasks(task));
    }
    await Future.wait(futures);
  }

  /// 检查逾期任务并标记扣分状态
  Future<void> checkOverdueTasks() async {
    final overdueTasks = await _repository.getOverdueTasks(DateTime.now());
    for (final task in overdueTasks) {
      if (task.rewardPoints > 0 && !task.isDeducted) {
        await _repository.markTaskDeducted(task.id!);
      }
    }
  }
}
