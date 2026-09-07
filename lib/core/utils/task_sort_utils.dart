import '../../modules/tasks/models/task_model.dart';
import '../../providers/task_provider.dart';

class TaskSortUtils {
  static List<Task> sortTasks(List<Task> tasks, TaskSortOption sortOption) {
    switch (sortOption) {
      case TaskSortOption.priority:
        tasks.sort((a, b) => a.priorityOrder.compareTo(b.priorityOrder));
        break;
      case TaskSortOption.completionStatus:
        tasks.sort((a, b) {
          if (a.isOK == b.isOK) return 0;
          return a.isOK ? 1 : -1;
        });
        break;
      case TaskSortOption.createdTime:
        tasks.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        break;
      case TaskSortOption.completionTime:
        tasks.sort((a, b) {
          if (a.completedAt == null && b.completedAt == null) {
            return b.createdAt.compareTo(a.createdAt);
          }
          if (a.completedAt == null) return 1;
          if (b.completedAt == null) return -1;
          return b.completedAt!.compareTo(a.completedAt!);
        });
        break;
      case TaskSortOption.defaultOrder:
        break;
    }
    return tasks;
  }

  static List<Task> filterByPriority(List<Task> tasks, String? priority) {
    if (priority == null) return tasks;
    return tasks.where((task) => task.priority == priority).toList();
  }

  static List<Task> filterByCompletion(List<Task> tasks, bool? completion) {
    if (completion == null) return tasks;
    return tasks.where((task) => task.isOK == completion).toList();
  }

  static List<Task> filterByRecurrence(List<Task> tasks, bool? recurrence) {
    if (recurrence == null) return tasks;
    return tasks.where((task) {
      if (recurrence == true) {
        return task.recurrence != 'none';
      } else {
        return task.recurrence == 'none';
      }
    }).toList();
  }

  static List<Task> filterBySearchQuery(List<Task> tasks, String query) {
    if (query.isEmpty) return tasks;
    final queryLower = query.toLowerCase();
    return tasks.where((task) {
      return task.title.toLowerCase().contains(queryLower) ||
          (task.description?.toLowerCase().contains(queryLower) ?? false);
    }).toList();
  }

  static List<Task> filterByTagIds(List<Task> tasks, List<int> tagIds) {
    if (tagIds.isEmpty) return [];
    return tasks.where((task) => tagIds.contains(task.id)).toList();
  }

  static List<Task> applyAllFilters({
    required List<Task> tasks,
    String? priorityFilter,
    bool? completionFilter,
    bool? recurrenceFilter,
    String searchQuery = '',
    List<int> filteredTaskIds = const [],
    int? selectedTagId,
    TaskSortOption sortOption = TaskSortOption.defaultOrder,
  }) {
    var result = tasks;

    if (selectedTagId != null) {
      result = filterByTagIds(result, filteredTaskIds);
    }

    result = filterByPriority(result, priorityFilter);
    result = filterByCompletion(result, completionFilter);
    result = filterByRecurrence(result, recurrenceFilter);
    result = filterBySearchQuery(result, searchQuery);
    result = sortTasks(result, sortOption);

    return result;
  }
}
