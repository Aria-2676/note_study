import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:v5_app/modules/points/models/points_model.dart';
import 'package:v5_app/modules/tasks/models/task_model.dart';
import 'package:v5_app/modules/tasks/repositories/task_repository.dart';
import 'package:v5_app/providers/points_provider.dart';
import 'package:v5_app/providers/task_provider.dart';

@GenerateMocks([TaskRepository, PointsProvider])
import 'task_provider_test.mocks.dart';

void main() {
  late TaskProvider taskProvider;
  late MockTaskRepository mockTaskRepository;
  late MockPointsProvider mockPointsProvider;

  setUp(() {
    mockTaskRepository = MockTaskRepository();
    mockPointsProvider = MockPointsProvider();
    taskProvider = TaskProvider(
      mockPointsProvider,
      taskRepository: mockTaskRepository,
    );
    when(mockPointsProvider.currentPoints).thenReturn(0);
  });

  group('selectDate', () {
    test('should update _selectedDate and _selectedDates', () async {
      final testDate = DateTime(2024, 6, 15);
      when(mockTaskRepository.getTasksForDate(any)).thenAnswer((_) async => []);

      taskProvider.selectDate(testDate);

      expect(taskProvider.selectedDate, testDate);
      expect(taskProvider.selectedDates.length, 1);
      expect(
        taskProvider.selectedDates.any(
          (d) =>
              d.year == testDate.year &&
              d.month == testDate.month &&
              d.day == testDate.day,
        ),
        isTrue,
      );
    });

    test('should call loadTasksByDate with the selected date', () async {
      final testDate = DateTime(2024, 6, 15);
      when(mockTaskRepository.getTasksForDate(any)).thenAnswer((_) async => []);

      taskProvider.selectDate(testDate);

      verify(mockTaskRepository.getTasksForDate(testDate)).called(1);
    });

    test('should notify listeners when date changes', () async {
      int notifyCount = 0;
      taskProvider.addListener(() => notifyCount++);
      when(mockTaskRepository.getTasksForDate(any)).thenAnswer((_) async => []);

      final testDate = DateTime(2024, 6, 15);
      taskProvider.selectDate(testDate);

      await Future.delayed(const Duration(milliseconds: 100));

      expect(notifyCount, greaterThanOrEqualTo(1));
    });
  });

  group('loadTasksByDate', () {
    test('should update _selectedDate and _selectedDates', () async {
      final testDate = DateTime(2024, 6, 15);
      when(mockTaskRepository.getTasksForDate(any)).thenAnswer((_) async => []);

      await taskProvider.loadTasksByDate(testDate);

      expect(taskProvider.selectedDate, testDate);
      expect(taskProvider.selectedDates.length, 1);
      expect(
        taskProvider.selectedDates.any(
          (d) =>
              d.year == testDate.year &&
              d.month == testDate.month &&
              d.day == testDate.day,
        ),
        isTrue,
      );
    });

    test('should load tasks for the given date', () async {
      final testDate = DateTime(2024, 6, 15);
      final mockTasks = [Task(id: 1, title: 'Test Task', cplTime: testDate)];
      when(
        mockTaskRepository.getTasksForDate(any),
      ).thenAnswer((_) async => mockTasks);

      await taskProvider.loadTasksByDate(testDate);

      expect(taskProvider.rawTasks.length, 1);
      expect(taskProvider.rawTasks[0].title, 'Test Task');
    });

    test('should notify listeners after loading tasks', () async {
      int notifyCount = 0;
      taskProvider.addListener(() => notifyCount++);
      when(mockTaskRepository.getTasksForDate(any)).thenAnswer((_) async => []);

      await taskProvider.loadTasksByDate(DateTime(2024, 6, 15));

      expect(notifyCount, greaterThanOrEqualTo(1));
    });
  });

  group('addTask', () {
    test('should add task and load tasks for task.cplTime', () async {
      final taskDate = DateTime(2024, 6, 20);
      final newTask = Task(title: 'New Task', cplTime: taskDate);
      final createdTask = newTask.copyWith(id: 1);

      when(
        mockTaskRepository.addTask(any),
      ).thenAnswer((_) async => createdTask);
      when(
        mockTaskRepository.getTasksForDate(any),
      ).thenAnswer((_) async => [createdTask]);

      final result = await taskProvider.addTask(newTask);

      expect(result.id, 1);
      verify(mockTaskRepository.getTasksForDate(taskDate)).called(1);
    });

    test(
      'should not load tasks for _selectedDate when task has different date',
      () async {
        final selectedDate = DateTime(2024, 6, 15);
        final taskDate = DateTime(2024, 6, 20);
        final newTask = Task(title: 'New Task', cplTime: taskDate);

        when(
          mockTaskRepository.getTasksForDate(any),
        ).thenAnswer((_) async => []);
        await taskProvider.loadTasksByDate(selectedDate);

        clearInteractions(mockTaskRepository);

        when(
          mockTaskRepository.addTask(any),
        ).thenAnswer((_) async => newTask.copyWith(id: 1));

        await taskProvider.addTask(newTask);

        verifyNever(mockTaskRepository.getTasksForDate(selectedDate));
        verify(mockTaskRepository.getTasksForDate(taskDate)).called(1);
      },
    );
  });

  group('updateTask', () {
    test('should update task and load tasks for task.cplTime', () async {
      final taskDate = DateTime(2024, 6, 20);
      final updatedTask = Task(id: 1, title: 'Updated Task', cplTime: taskDate);

      when(
        mockTaskRepository.updateTask(any, updateAll: anyNamed('updateAll')),
      ).thenAnswer((_) async {});
      when(
        mockTaskRepository.getTasksForDate(any),
      ).thenAnswer((_) async => [updatedTask]);

      await taskProvider.updateTask(updatedTask);

      verify(mockTaskRepository.getTasksForDate(taskDate)).called(1);
    });
  });

  group('toggleSelectedDate', () {
    test('should add date when not in selectedDates', () {
      final testDate = DateTime(2024, 6, 15);
      when(mockTaskRepository.getTasksForDate(any)).thenAnswer((_) async => []);

      taskProvider.toggleSelectedDate(testDate);

      expect(
        taskProvider.selectedDates.any(
          (d) =>
              d.year == testDate.year &&
              d.month == testDate.month &&
              d.day == testDate.day,
        ),
        isTrue,
      );
    });

    test(
      'should remove date when already in selectedDates (if more than one)',
      () async {
        final date1 = DateTime(2024, 6, 15);
        final date2 = DateTime(2024, 6, 16);
        when(
          mockTaskRepository.getTasksForDate(any),
        ).thenAnswer((_) async => []);

        await taskProvider.loadTasksByDate(date1);
        taskProvider.toggleSelectedDate(date2);

        expect(taskProvider.selectedDates.length, 2);

        taskProvider.toggleSelectedDate(date2);

        expect(taskProvider.selectedDates.length, 1);
      },
    );

    test('should not remove the last date', () async {
      final date = DateTime(2024, 6, 15);
      when(mockTaskRepository.getTasksForDate(any)).thenAnswer((_) async => []);

      await taskProvider.loadTasksByDate(date);

      taskProvider.toggleSelectedDate(date);

      expect(taskProvider.selectedDates.length, 1);
    });

    test('should notify listeners', () {
      int notifyCount = 0;
      taskProvider.addListener(() => notifyCount++);

      taskProvider.toggleSelectedDate(DateTime(2024, 6, 15));

      expect(notifyCount, greaterThanOrEqualTo(1));
    });
  });

  group('setBatchMode', () {
    test('should update batch mode', () {
      taskProvider.setBatchMode(true);
      expect(taskProvider.batchMode, isTrue);

      taskProvider.setBatchMode(false);
      expect(taskProvider.batchMode, isFalse);
    });

    test('should clear selectedTaskIds when disabling batch mode', () {
      taskProvider.toggleTaskSelection(1);
      taskProvider.toggleTaskSelection(2);

      expect(taskProvider.selectedTaskIds.length, 2);

      taskProvider.setBatchMode(false);

      expect(taskProvider.selectedTaskIds.isEmpty, isTrue);
    });

    test('should notify listeners', () {
      int notifyCount = 0;
      taskProvider.addListener(() => notifyCount++);

      taskProvider.setBatchMode(true);

      expect(notifyCount, greaterThanOrEqualTo(1));
    });
  });

  group('toggleTaskSelection', () {
    test('should add task id when not selected', () {
      taskProvider.toggleTaskSelection(1);

      expect(taskProvider.selectedTaskIds.contains(1), isTrue);
    });

    test('should remove task id when already selected', () {
      taskProvider.toggleTaskSelection(1);
      taskProvider.toggleTaskSelection(1);

      expect(taskProvider.selectedTaskIds.contains(1), isFalse);
    });

    test('should notify listeners', () {
      int notifyCount = 0;
      taskProvider.addListener(() => notifyCount++);

      taskProvider.toggleTaskSelection(1);

      expect(notifyCount, greaterThanOrEqualTo(1));
    });
  });

  group('toggleBatchMode', () {
    test('should toggle batch mode', () {
      expect(taskProvider.batchMode, isFalse);

      taskProvider.toggleBatchMode();
      expect(taskProvider.batchMode, isTrue);

      taskProvider.toggleBatchMode();
      expect(taskProvider.batchMode, isFalse);
    });

    test('should clear selectedTaskIds when disabling batch mode', () {
      taskProvider.toggleBatchMode();
      taskProvider.toggleTaskSelection(1);
      taskProvider.toggleTaskSelection(2);

      expect(taskProvider.selectedTaskIds.length, 2);

      taskProvider.toggleBatchMode();

      expect(taskProvider.selectedTaskIds.isEmpty, isTrue);
    });

    test('should notify listeners', () {
      int notifyCount = 0;
      taskProvider.addListener(() => notifyCount++);

      taskProvider.toggleBatchMode();

      expect(notifyCount, greaterThanOrEqualTo(1));
    });
  });

  group('setPriorityFilter', () {
    test('should update priority filter', () {
      taskProvider.setPriorityFilter('red');
      expect(taskProvider.priorityFilter, 'red');

      taskProvider.setPriorityFilter(null);
      expect(taskProvider.priorityFilter, isNull);
    });

    test('should notify listeners', () {
      int notifyCount = 0;
      taskProvider.addListener(() => notifyCount++);

      taskProvider.setPriorityFilter('red');

      expect(notifyCount, greaterThanOrEqualTo(1));
    });
  });

  group('setCompletionFilter', () {
    test('should update completion filter', () {
      taskProvider.setCompletionFilter(true);
      expect(taskProvider.completionFilter, isTrue);

      taskProvider.setCompletionFilter(false);
      expect(taskProvider.completionFilter, isFalse);

      taskProvider.setCompletionFilter(null);
      expect(taskProvider.completionFilter, isNull);
    });

    test('should notify listeners', () {
      int notifyCount = 0;
      taskProvider.addListener(() => notifyCount++);

      taskProvider.setCompletionFilter(true);

      expect(notifyCount, greaterThanOrEqualTo(1));
    });
  });

  group('hasActiveFilter', () {
    test('should return false when no filters are active', () {
      expect(taskProvider.hasActiveFilter, isFalse);
    });

    test('should return true when priority filter is active', () {
      taskProvider.setPriorityFilter('red');
      expect(taskProvider.hasActiveFilter, isTrue);
    });

    test('should return true when completion filter is active', () {
      taskProvider.setCompletionFilter(true);
      expect(taskProvider.hasActiveFilter, isTrue);
    });

    test('should return true when recurrence filter is active', () {
      taskProvider.setRecurrenceFilter(true);
      expect(taskProvider.hasActiveFilter, isTrue);
    });
  });

  group('activeFilterCount', () {
    test('should return 0 when no filters are active', () {
      expect(taskProvider.activeFilterCount, 0);
    });

    test('should return correct count when multiple filters are active', () {
      taskProvider.setPriorityFilter('red');
      taskProvider.setCompletionFilter(true);
      taskProvider.setRecurrenceFilter(true);

      expect(taskProvider.activeFilterCount, 3);
    });
  });

  group('clearFilters', () {
    test('should clear all filters', () {
      taskProvider.setPriorityFilter('red');
      taskProvider.setCompletionFilter(true);
      taskProvider.setRecurrenceFilter(true);

      taskProvider.clearFilters();

      expect(taskProvider.priorityFilter, isNull);
      expect(taskProvider.completionFilter, isNull);
      expect(taskProvider.recurrenceFilter, isNull);
    });

    test('should notify listeners', () {
      int notifyCount = 0;
      taskProvider.addListener(() => notifyCount++);

      taskProvider.setPriorityFilter('red');
      notifyCount = 0;

      taskProvider.clearFilters();

      expect(notifyCount, greaterThanOrEqualTo(1));
    });
  });

  group('任务积分结算', () {
    final taskDate = DateTime(2024, 6, 15);

    Task rewardTask({bool isOK = false}) => Task(
      id: 7,
      title: '写代码',
      cplTime: taskDate,
      rewardPoints: 10,
      isOK: isOK,
    );

    setUp(() {
      when(mockTaskRepository.completeTask(any)).thenAnswer((_) async => null);
      when(mockTaskRepository.uncompleteTask(any)).thenAnswer((_) async {});
      when(mockTaskRepository.getTasksForDate(any)).thenAnswer((_) async => []);
    });

    test('should award points when a task is completed for the first time', () async {
      await taskProvider.completeTask(rewardTask());

      verify(
        mockPointsProvider.addPointsWithRecord(
          points: 10,
          type: 'task_complete',
          description: anyNamed('description'),
          relatedId: 7,
        ),
      ).called(1);
    });

    test('should not award points again while the completion is still settled', () async {
      when(mockPointsProvider.getLatestRecord(any, any)).thenAnswer(
        (_) async => PointsRecord(
          points: 10,
          type: 'task_complete',
          description: '完成任务',
        ),
      );

      await taskProvider.completeTask(rewardTask());

      verifyNever(
        mockPointsProvider.addPointsWithRecord(
          points: anyNamed('points'),
          type: anyNamed('type'),
          description: anyNamed('description'),
          relatedId: anyNamed('relatedId'),
        ),
      );
    });

    test('should refund the awarded points when completion is undone', () async {
      when(mockPointsProvider.getLatestRecord(any, any)).thenAnswer(
        (_) async => PointsRecord(
          points: 10,
          type: 'task_complete',
          description: '完成任务',
        ),
      );

      await taskProvider.uncompleteTask(rewardTask(isOK: true));

      verify(
        mockPointsProvider.deductPointsWithRecord(
          points: 10,
          type: 'task_uncomplete',
          description: anyNamed('description'),
          relatedId: 7,
        ),
      ).called(1);
    });

    test('should award again after completion was undone', () async {
      // 最近一条是「取消完成」，说明加分已被冲销 —— 再次完成应重新加分
      when(mockPointsProvider.getLatestRecord(any, any)).thenAnswer(
        (_) async => PointsRecord(
          points: -10,
          type: 'task_uncomplete',
          description: '取消完成',
        ),
      );

      await taskProvider.completeTask(rewardTask());

      verify(
        mockPointsProvider.addPointsWithRecord(
          points: 10,
          type: 'task_complete',
          description: anyNamed('description'),
          relatedId: 7,
        ),
      ).called(1);
    });

    test('should refund exactly the amount that was awarded', () async {
      // 完成期间奖励值被改过，冲销仍应按当初实际加过的分值
      when(mockPointsProvider.getLatestRecord(any, any)).thenAnswer(
        (_) async => PointsRecord(
          points: 3,
          type: 'task_complete',
          description: '完成任务',
        ),
      );

      await taskProvider.uncompleteTask(rewardTask(isOK: true));

      verify(
        mockPointsProvider.deductPointsWithRecord(
          points: 3,
          type: 'task_uncomplete',
          description: anyNamed('description'),
          relatedId: 7,
        ),
      ).called(1);
    });

    test('should not touch points when the task has no reward', () async {
      final freeTask = Task(
        id: 8,
        title: '免费任务',
        cplTime: taskDate,
        rewardPoints: 0,
      );

      await taskProvider.completeTask(freeTask);

      verifyNever(
        mockPointsProvider.addPointsWithRecord(
          points: anyNamed('points'),
          type: anyNamed('type'),
          description: anyNamed('description'),
          relatedId: anyNamed('relatedId'),
        ),
      );
    });

    test('should not settle points for an already completed task', () async {
      await taskProvider.completeTask(rewardTask(isOK: true));

      verifyNever(
        mockPointsProvider.addPointsWithRecord(
          points: anyNamed('points'),
          type: anyNamed('type'),
          description: anyNamed('description'),
          relatedId: anyNamed('relatedId'),
        ),
      );
    });
  });

  group('月份缓存 LRU', () {
    test('should evict the least recently used month, not the first inserted', () async {
      int fetchCount = 0;
      when(mockTaskRepository.getTasksByDateRange(any, any)).thenAnswer((_) async {
        fetchCount++;
        return [];
      });

      final jan = DateTime(2024, 1, 15);
      final feb = DateTime(2024, 2, 15);
      final mar = DateTime(2024, 3, 15);
      final apr = DateTime(2024, 4, 15);

      await taskProvider.getTasksForMonth(jan);
      await taskProvider.getTasksForMonth(feb);
      await taskProvider.getTasksForMonth(mar);
      expect(fetchCount, 3);

      // 再次访问 1 月，使其成为「最近使用」（不应触发查库）
      await taskProvider.getTasksForMonth(jan);
      expect(fetchCount, 3);

      // 插入第 4 个月：应淘汰最久未使用的 2 月
      await taskProvider.getTasksForMonth(apr);
      expect(fetchCount, 4);

      // 1 月刚被访问过，仍在缓存中
      await taskProvider.getTasksForMonth(jan);
      expect(fetchCount, 4);

      // 2 月已被淘汰 → 需要重新查库
      await taskProvider.getTasksForMonth(feb);
      expect(fetchCount, 5);
    });
  });

  group('selectAllTasks', () {
    test('should skip tasks whose id is null instead of crashing', () async {
      final date = DateTime(2024, 6, 15);
      when(mockTaskRepository.getTasksForDate(any)).thenAnswer(
        (_) async => [
          Task(id: 1, title: 'A', cplTime: date),
          Task(title: 'B', cplTime: date), // 未落库，id 为 null
          Task(id: 3, title: 'C', cplTime: date),
        ],
      );
      await taskProvider.loadTasksByDate(date);

      expect(taskProvider.selectAllTasks, returnsNormally);
      expect(taskProvider.selectedTaskIds, {1, 3});
    });
  });

  group('批量操作', () {
    final date = DateTime(2024, 6, 15);

    setUp(() {
      when(mockTaskRepository.getTasksForDate(any)).thenAnswer(
        (_) async => [
          Task(id: 1, title: 'A', cplTime: date),
          Task(id: 2, title: 'B', cplTime: date),
          Task(id: 3, title: 'C', cplTime: date),
        ],
      );
    });

    test('should finish remaining items and report counts when one fails', () async {
      await taskProvider.loadTasksByDate(date);
      taskProvider.setBatchMode(true);
      for (final id in [1, 2, 3]) {
        taskProvider.toggleTaskSelection(id);
      }

      when(mockTaskRepository.completeTask(any)).thenAnswer((invocation) async {
        final task = invocation.positionalArguments[0] as Task;
        if (task.id == 2) throw Exception('boom');
        return null;
      });

      final message = await taskProvider.batchCompleteTasks();

      // 2 号失败不应中断整批：3 个都被尝试过
      verify(mockTaskRepository.completeTask(any)).called(3);
      expect(message, '成功完成 2 个任务，1 个失败');
      // 无论成功失败都要退出批量态并清空选择
      expect(taskProvider.selectedTaskIds, isEmpty);
      expect(taskProvider.batchMode, isFalse);
    });

    test('should return null and clear selection when nothing is actionable', () async {
      when(mockTaskRepository.getTasksForDate(any)).thenAnswer(
        (_) async => [Task(id: 1, title: 'A', cplTime: date, isOK: true)],
      );
      await taskProvider.loadTasksByDate(date);
      taskProvider.setBatchMode(true);
      taskProvider.toggleTaskSelection(1);

      final message = await taskProvider.batchCompleteTasks();

      expect(message, isNull);
      expect(taskProvider.selectedTaskIds, isEmpty);
      verifyNever(mockTaskRepository.completeTask(any));
    });
  });

  group('小组件任务来源', () {
    final selectedDate = DateTime(2024, 6, 15);

    test("should show today's tasks even when another date is selected", () async {
      final selectedDayTask = Task(
        id: 1,
        title: '选中日任务',
        cplTime: selectedDate,
      );
      final todayTask = Task(id: 2, title: '今天的任务', cplTime: DateTime.now());

      when(mockTaskRepository.getTasksForDate(any)).thenAnswer((invocation) async {
        final date = invocation.positionalArguments[0] as DateTime;
        final isSelectedDay =
            date.year == selectedDate.year &&
            date.month == selectedDate.month &&
            date.day == selectedDate.day;
        return isSelectedDay ? [selectedDayTask] : [todayTask];
      });

      await taskProvider.loadTasksByDate(selectedDate);
      // 前台列表展示的是「选中日」的任务
      expect(taskProvider.rawTasks.single.title, '选中日任务');

      // 小组件必须只认「真实今天」
      final widgetTasks = await taskProvider.widgetTasksForToday();
      expect(widgetTasks.single.title, '今天的任务');
    });

    test('should reuse the loaded list when the selected date is today', () async {
      int fetchCount = 0;
      when(mockTaskRepository.getTasksForDate(any)).thenAnswer((_) async {
        fetchCount++;
        return [];
      });

      await taskProvider.loadTasksByDate(DateTime.now());
      expect(fetchCount, 1);

      await taskProvider.widgetTasksForToday();
      // 选中日就是今天 → 直接复用，不应产生额外查库
      expect(fetchCount, 1);
    });
  });
}
