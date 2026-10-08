import 'package:flutter_test/flutter_test.dart';
import 'package:v5_app/core/utils/task_sort_utils.dart';
import 'package:v5_app/modules/tasks/models/task_model.dart';
import 'package:v5_app/providers/task_provider.dart';

/// 构造任务，仅覆盖被测排序/筛选字段，其余使用默认值。
Task _task({
  int? id,
  String title = '任务',
  String? description,
  bool isOK = false,
  String recurrence = 'none',
  String priority = 'white',
  DateTime? createdAt,
  DateTime? completedAt,
}) {
  return Task(
    id: id,
    title: title,
    description: description,
    isOK: isOK,
    recurrence: recurrence,
    priority: priority,
    createdAt: createdAt ?? DateTime(2024, 1, 1),
    cplTime: DateTime(2024, 1, 1),
    completedAt: completedAt,
  );
}

void main() {
  group('TaskSortUtils.sortTasks', () {
    test('priority should sort from red to white by priorityOrder', () {
      final tasks = [
        _task(title: 'white', priority: 'white'),
        _task(title: 'red', priority: 'red'),
        _task(title: 'blue', priority: 'blue'),
        _task(title: 'orange', priority: 'orange'),
        _task(title: 'yellow', priority: 'yellow'),
      ];

      final result = TaskSortUtils.sortTasks(tasks, TaskSortOption.priority);

      expect(result.map((t) => t.priority).toList(), [
        'red',
        'orange',
        'yellow',
        'blue',
        'white',
      ]);
    });

    test('completionStatus should place unfinished tasks before finished', () {
      final tasks = [
        _task(title: 'done', isOK: true),
        _task(title: 'todo', isOK: false),
        _task(title: 'done2', isOK: true),
      ];

      final result = TaskSortUtils.sortTasks(
        tasks,
        TaskSortOption.completionStatus,
      );

      expect(result.first.isOK, isFalse);
      expect(result.last.isOK, isTrue);
    });

    test('createdTime should sort newest first', () {
      final tasks = [
        _task(title: 'old', createdAt: DateTime(2024, 1, 1)),
        _task(title: 'new', createdAt: DateTime(2024, 3, 1)),
        _task(title: 'mid', createdAt: DateTime(2024, 2, 1)),
      ];

      final result = TaskSortUtils.sortTasks(tasks, TaskSortOption.createdTime);

      expect(result.map((t) => t.title).toList(), ['new', 'mid', 'old']);
    });

    test('completionTime should sort newest completion first', () {
      final tasks = [
        _task(title: 'a', completedAt: DateTime(2024, 1, 1)),
        _task(title: 'b', completedAt: DateTime(2024, 3, 1)),
        _task(title: 'c', completedAt: DateTime(2024, 2, 1)),
      ];

      final result = TaskSortUtils.sortTasks(
        tasks,
        TaskSortOption.completionTime,
      );

      expect(result.map((t) => t.title).toList(), ['b', 'c', 'a']);
    });

    test('completionTime should put nulls last and order them by createdAt desc',
        () {
      final tasks = [
        _task(title: 'nullOld', createdAt: DateTime(2024, 1, 1)),
        _task(
          title: 'completed',
          completedAt: DateTime(2024, 2, 1),
          createdAt: DateTime(2024, 2, 1),
        ),
        _task(title: 'nullNew', createdAt: DateTime(2024, 3, 1)),
      ];

      final result = TaskSortUtils.sortTasks(
        tasks,
        TaskSortOption.completionTime,
      );

      expect(result.map((t) => t.title).toList(), [
        'completed',
        'nullNew',
        'nullOld',
      ]);
    });

    test('defaultOrder should keep the original order', () {
      final tasks = [
        _task(title: 'x', priority: 'white'),
        _task(title: 'y', priority: 'red'),
      ];

      final result = TaskSortUtils.sortTasks(
        tasks,
        TaskSortOption.defaultOrder,
      );

      expect(result.map((t) => t.title).toList(), ['x', 'y']);
    });

    test('should return the same list instance (in-place sort)', () {
      final tasks = [_task(title: 'a')];
      final result = TaskSortUtils.sortTasks(tasks, TaskSortOption.priority);

      expect(identical(result, tasks), isTrue);
    });
  });

  group('TaskSortUtils.filterByPriority', () {
    final tasks = [
      _task(title: 'r', priority: 'red'),
      _task(title: 'w', priority: 'white'),
      _task(title: 'r2', priority: 'red'),
    ];

    test('should return all tasks when priority is null', () {
      expect(TaskSortUtils.filterByPriority(tasks, null).length, 3);
    });

    test('should keep only tasks matching the priority', () {
      final result = TaskSortUtils.filterByPriority(tasks, 'red');
      expect(result.map((t) => t.title).toList(), ['r', 'r2']);
    });

    test('should return empty when no task matches', () {
      expect(TaskSortUtils.filterByPriority(tasks, 'blue'), isEmpty);
    });
  });

  group('TaskSortUtils.filterByCompletion', () {
    final tasks = [
      _task(title: 'todo', isOK: false),
      _task(title: 'done', isOK: true),
    ];

    test('should return all tasks when completion is null', () {
      expect(TaskSortUtils.filterByCompletion(tasks, null).length, 2);
    });

    test('should keep only completed tasks when completion is true', () {
      final result = TaskSortUtils.filterByCompletion(tasks, true);
      expect(result.single.title, 'done');
    });

    test('should keep only unfinished tasks when completion is false', () {
      final result = TaskSortUtils.filterByCompletion(tasks, false);
      expect(result.single.title, 'todo');
    });
  });

  group('TaskSortUtils.filterByRecurrence', () {
    final tasks = [
      _task(title: 'once', recurrence: 'none'),
      _task(title: 'daily', recurrence: 'daily'),
    ];

    test('should return all tasks when recurrence is null', () {
      expect(TaskSortUtils.filterByRecurrence(tasks, null).length, 2);
    });

    test('should keep only recurring tasks when true', () {
      final result = TaskSortUtils.filterByRecurrence(tasks, true);
      expect(result.single.title, 'daily');
    });

    test('should keep only non-recurring tasks when false', () {
      final result = TaskSortUtils.filterByRecurrence(tasks, false);
      expect(result.single.title, 'once');
    });
  });

  group('TaskSortUtils.filterBySearchQuery', () {
    final tasks = [
      _task(title: 'Buy Milk', description: 'grocery store'),
      _task(title: 'Write Code', description: null),
      _task(title: 'Read Book', description: 'BUY a new novel'),
    ];

    test('should return all tasks when query is empty', () {
      expect(TaskSortUtils.filterBySearchQuery(tasks, '').length, 3);
    });

    test('should match title case-insensitively', () {
      final result = TaskSortUtils.filterBySearchQuery(tasks, 'buy');
      expect(result.map((t) => t.title).toList(), ['Buy Milk', 'Read Book']);
    });

    test('should match description when title does not contain query', () {
      final result = TaskSortUtils.filterBySearchQuery(tasks, 'grocery');
      expect(result.single.title, 'Buy Milk');
    });

    test('should ignore tasks with null description', () {
      final result = TaskSortUtils.filterBySearchQuery(tasks, 'code');
      expect(result.single.title, 'Write Code');
    });

    test('should return empty when nothing matches', () {
      expect(TaskSortUtils.filterBySearchQuery(tasks, 'zzz'), isEmpty);
    });
  });

  group('TaskSortUtils.filterByTagIds', () {
    final tasks = [
      _task(id: 1, title: 'a'),
      _task(id: 2, title: 'b'),
      _task(id: 3, title: 'c'),
    ];

    test('should return empty list when tagIds is empty', () {
      expect(TaskSortUtils.filterByTagIds(tasks, []), isEmpty);
    });

    test('should keep tasks whose id is contained in tagIds', () {
      final result = TaskSortUtils.filterByTagIds(tasks, [1, 3]);
      expect(result.map((t) => t.title).toList(), ['a', 'c']);
    });

    test('should ignore tasks with null id', () {
      final withNull = [_task(title: 'noId'), _task(id: 5, title: 'hasId')];
      final result = TaskSortUtils.filterByTagIds(withNull, [5]);
      expect(result.single.title, 'hasId');
    });
  });

  group('TaskSortUtils.applyAllFilters', () {
    final tasks = [
      _task(id: 1, title: 'Red daily', priority: 'red', recurrence: 'daily'),
      _task(id: 2, title: 'Red once', priority: 'red'),
      _task(id: 3, title: 'Blue once', priority: 'blue'),
    ];

    test('should apply no filters when args are default', () {
      final result = TaskSortUtils.applyAllFilters(tasks: tasks);
      expect(result.length, 3);
    });

    test('should filter by priority', () {
      final result = TaskSortUtils.applyAllFilters(
        tasks: tasks,
        priorityFilter: 'red',
      );
      expect(result.length, 2);
    });

    test('should filter by completion', () {
      final mixed = [
        _task(id: 1, title: 'todo'),
        _task(id: 2, title: 'done', isOK: true),
      ];
      final result = TaskSortUtils.applyAllFilters(
        tasks: mixed,
        completionFilter: true,
      );
      expect(result.single.title, 'done');
    });

    test('should filter by recurrence', () {
      final result = TaskSortUtils.applyAllFilters(
        tasks: tasks,
        recurrenceFilter: true,
      );
      expect(result.single.title, 'Red daily');
    });

    test('should filter by search query', () {
      final result = TaskSortUtils.applyAllFilters(
        tasks: tasks,
        searchQuery: 'blue',
      );
      expect(result.single.title, 'Blue once');
    });

    test('should use filteredTaskIds only when selectedTagId is set', () {
      // selectedTagId 为 null 时，即使传了 filteredTaskIds 也不生效
      final ignored = TaskSortUtils.applyAllFilters(
        tasks: tasks,
        filteredTaskIds: [1],
      );
      expect(ignored.length, 3);

      final applied = TaskSortUtils.applyAllFilters(
        tasks: tasks,
        selectedTagId: 10,
        filteredTaskIds: [1, 3],
      );
      expect(applied.map((t) => t.id).toList(), [1, 3]);
    });

    test('should combine multiple filters and sorting', () {
      final result = TaskSortUtils.applyAllFilters(
        tasks: tasks,
        priorityFilter: 'red',
        recurrenceFilter: true,
        searchQuery: 'daily',
        sortOption: TaskSortOption.priority,
      );
      expect(result.single.title, 'Red daily');
    });

    test('should sort the filtered result', () {
      final unsorted = [
        _task(id: 1, title: 'white', priority: 'white'),
        _task(id: 2, title: 'red', priority: 'red'),
      ];
      final result = TaskSortUtils.applyAllFilters(
        tasks: unsorted,
        sortOption: TaskSortOption.priority,
      );
      expect(result.map((t) => t.title).toList(), ['red', 'white']);
    });
  });
}