
import '../models/task.dart';
import '../models/recycled_task.dart';
import '../services/database_service.dart';

class TaskRepository {
  final DatabaseService _db = DatabaseService.instance;

  Future<List<Task>> getTasksByDate(DateTime date) async {
    return await _db.getTasksByDate(date);
  }

  Future<List<Task>> getAllTasks() async {
    return await _db.getAllTasks();
  }

  Future<List<Task>> getRecurringTasks() async {
    return await _db.getRecurringTasks();
  }

  Future<List<Task>> getOverdueTasks(DateTime date) async {
    return await _db.getOverdueTasks(date);
  }

  Future<void> createTask(Task task) async {
    await _db.createTask(task);
  }

  Future<void> updateTask(Task task) async {
    await _db.updateTask(task);
  }

  Future<void> deleteTask(int id) async {
    await _db.deleteTask(id);
  }

  Future<void> deleteTaskWithoutRecycle(int id) async {
    await _db.deleteTaskWithoutRecycle(id);
  }

  Future<void> completeTask(int id) async {
    await _db.completeTask(id);
  }

  Future<void> uncompleteTask(int id) async {
    await _db.uncompleteTask(id);
  }

  Future<void> markTaskDeducted(int id) async {
    await _db.markTaskDeducted(id);
  }

  Future<bool> existsTaskOnDate(String title, String? description, DateTime date) async {
    return await _db.existsTaskOnDate(title, description, date);
  }

  // 回收站相关
  Future<List<RecycledTask>> getRecycledTasks() async {
    return await _db.getRecycledTasks();
  }

  Future<Task> restoreTaskFromRecycle(int recycledTaskId) async {
    return await _db.restoreTaskFromRecycle(recycledTaskId);
  }

  Future<void> deleteFromRecycle(int recycledTaskId) async {
    await _db.deleteFromRecycle(recycledTaskId);
  }

  Future<void> clearRecycleBin() async {
    await _db.clearRecycleBin();
  }
}