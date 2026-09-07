import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
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
}
