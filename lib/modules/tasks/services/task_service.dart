import '../../../core/utils/date_utils.dart';
import '../../../providers/task_provider.dart';
import '../../../data/models/task/task_model.dart';

class TaskService {
  final TaskProvider _provider;

  TaskService(this._provider);

  Future<void> createTask({
    required String title,
    String? description,
    bool isWord = false,
    DateTime? cplTime,
    String recurrence = 'none',
    int rewardPoints = 0,
    String priority = 'white',
  }) async {
    final task = Task(
      title: title,
      description: description,
      isWord: isWord,
      cplTime: cplTime ?? DateTime.now(),
      recurrence: recurrence,
      rewardPoints: rewardPoints,
      priority: priority,
    );
    await _provider.addTask(task);
  }

  Future<void> updateTask(Task task) async {
    await _provider.updateTask(task);
  }

  Future<void> deleteTask(int id) async {
    await _provider.deleteTask(id);
  }

  Future<void> toggleTaskCompletion(int id) async {
    final task = _provider.getTaskById(id);
    if (task != null) {
      if (task.isOK) {
        await _provider.uncompleteTask(task);
      } else {
        await _provider.completeTask(task);
      }
    }
  }

  Future<void> handleRecurringTasks() async {
    await _provider.loadTasksForDate(DateUtils.getToday());
    final tasks = _provider.tasks;

    for (final task in tasks) {
      if (task.recurrence != 'none' && task.isOK) {
        await _createNextRecurrence(task);
      }
    }
  }

  Future<void> _createNextRecurrence(Task task) async {
    DateTime nextDate;

    switch (task.recurrence) {
      case 'daily':
        nextDate = task.cplTime.add(const Duration(days: 1));
        break;
      case 'weekly':
        nextDate = task.cplTime.add(const Duration(days: 7));
        break;
      case 'monthly':
        nextDate = DateTime(
          task.cplTime.year,
          task.cplTime.month + 1,
          task.cplTime.day,
        );
        break;
      default:
        return;
    }

    final newTask = Task(
      loopId: task.loopId ?? task.id?.toString(),
      title: task.title,
      description: task.description,
      isWord: task.isWord,
      isOK: false,
      cplTime: nextDate,
      recurrence: task.recurrence,
      rewardPoints: task.rewardPoints,
      priority: task.priority,
    );

    await _provider.addTask(newTask);
  }

  int calculateDailyPoints(List<Task> tasks) {
    return tasks.where((t) => t.isOK).fold(0, (sum, t) => sum + t.rewardPoints);
  }
}
