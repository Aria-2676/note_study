import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:v5_app/modules/tasks/models/task_model.dart';
import 'package:v5_app/modules/tasks/repositories/task_repository.dart';
import 'package:v5_app/modules/tasks/services/task_scheduler_service.dart';
import 'package:v5_app/providers/points_provider.dart';
import 'package:v5_app/providers/task_provider.dart';

@GenerateMocks([TaskRepository, PointsProvider, TaskSchedulerService])
import 'task_query_crud_mixin_test.mocks.dart';

void main() {
  late TaskProvider provider;
  late MockTaskRepository repo;
  late MockPointsProvider points;
  late MockTaskSchedulerService scheduler;

  final date = DateTime(2024, 6, 15);

  setUp(() {
    repo = MockTaskRepository();
    points = MockPointsProvider();
    scheduler = MockTaskSchedulerService();
    when(points.currentPoints).thenReturn(0);
    provider = TaskProvider(
      points,
      taskRepository: repo,
      taskSchedulerService: scheduler,
    );
  });

  group('TaskQueryMixin 查询与筛选', () {
    test('getTaskById 命中与未命中', () async {
      when(repo.getTasksForDate(any)).thenAnswer(
        (_) async => [Task(id: 1, title: 'A', cplTime: date)],
      );
      await provider.loadTasksByDate(date);

      expect(provider.getTaskById(1)?.title, 'A');
      expect(provider.getTaskById(99), isNull);
    });

    test('setSearchQuery 过滤任务并暴露查询串', () async {
      when(repo.getTasksForDate(any)).thenAnswer(
        (_) async => [
          Task(id: 1, title: 'alpha', cplTime: date),
          Task(id: 2, title: 'beta', cplTime: date),
        ],
      );
      await provider.loadTasksByDate(date);

      provider.setSearchQuery('alph');

      expect(provider.searchQuery, 'alph');
      expect(provider.tasks.map((t) => t.title), ['alpha']);
    });

    test('clearSearch/enterSearchMode/exitSearchMode', () {
      provider.enterSearchMode();
      expect(provider.isSearchMode, isTrue);
      provider.setSearchQuery('x');
      provider.clearSearch();
      expect(provider.searchQuery, '');
      expect(provider.isSearchMode, isFalse);
      provider.enterSearchMode();
      provider.exitSearchMode();
      expect(provider.isSearchMode, isFalse);
    });

    test('selectTag/clearTagFilter 按任务集合过滤', () async {
      when(repo.getTasksForDate(any)).thenAnswer(
        (_) async => [
          Task(id: 1, title: 'A', cplTime: date),
          Task(id: 2, title: 'B', cplTime: date),
        ],
      );
      await provider.loadTasksByDate(date);

      provider.selectTag(5, taskIds: [2]);
      expect(provider.selectedTagId, 5);
      expect(provider.tasks.map((t) => t.id), [2]);

      provider.clearTagFilter();
      expect(provider.selectedTagId, isNull);
      expect(provider.tasks.length, 2);
    });

    test('setSortOption 通知，syncSortOption 静默', () {
      var notifications = 0;
      provider.addListener(() => notifications++);

      provider.setSortOption(TaskSortOption.priority);
      expect(provider.sortOption, TaskSortOption.priority);
      expect(notifications, 1);

      provider.syncSortOption(TaskSortOption.completionTime);
      expect(provider.sortOption, TaskSortOption.completionTime);
      expect(notifications, 1);
    });

    test('searchAllTasks 空查询清除结果', () async {
      await provider.searchAllTasks('');

      expect(provider.searchResults, isEmpty);
      expect(provider.isSearching, isFalse);
    });

    test('searchAllTasks 非空查询写入结果', () async {
      when(repo.searchTasks(any)).thenAnswer(
        (_) async => [Task(id: 1, title: 'k', cplTime: date)],
      );

      await provider.searchAllTasks('k');

      expect(provider.searchResults.single.title, 'k');
      expect(provider.isSearching, isFalse);
    });

    test('searchAllTasks 仓储异常时结果为空', () async {
      when(repo.searchTasks(any)).thenThrow(Exception('boom'));

      await provider.searchAllTasks('k');

      expect(provider.searchResults, isEmpty);
      expect(provider.isSearching, isFalse);
    });

    test('advancedSearch 透传日期与完成状态', () async {
      when(
        repo.searchTasks(
          any,
          startDate: anyNamed('startDate'),
          endDate: anyNamed('endDate'),
          completionStatus: anyNamed('completionStatus'),
        ),
      ).thenAnswer((_) async => []);

      await provider.advancedSearch(
        query: 'q',
        startDate: DateTime(2024, 1, 1),
        endDate: DateTime(2024, 1, 31),
        completionStatus: true,
      );

      verify(
        repo.searchTasks(
          'q',
          startDate: anyNamed('startDate'),
          endDate: anyNamed('endDate'),
          completionStatus: anyNamed('completionStatus'),
        ),
      ).called(1);
      expect(provider.isSearching, isFalse);
    });
  });

  group('TaskCrudMixin 增删改查', () {
    test('loadTasksForDate 与 loadTodayTasks', () async {
      when(repo.getTasksForDate(any)).thenAnswer((_) async => []);

      await provider.loadTasksForDate(date);
      expect(provider.selectedDate, date);

      await provider.loadTodayTasks();
      expect(provider.selectedDate.day, DateTime.now().day);
    });

    test('addTask 非循环任务直接新增', () async {
      final created = Task(id: 1, title: 'A', cplTime: date);
      when(repo.addTask(any)).thenAnswer((_) async => created);
      when(repo.getTasksForDate(any)).thenAnswer((_) async => [created]);

      final result = await provider.addTask(Task(title: 'A', cplTime: date));

      expect(result.id, 1);
      verify(repo.getTasksForDate(date)).called(1);
      verifyNever(scheduler.generateRecurringTasks(any));
    });

    test('addTask 循环任务补 loopId 并生成后续实例', () async {
      final created = Task(id: 2, title: 'R', cplTime: date, recurrence: 'daily');
      when(scheduler.generateLoopId()).thenReturn('loop-x');
      when(repo.addTask(any)).thenAnswer((_) async => created);
      when(repo.getTasksForDate(any)).thenAnswer((_) async => [created]);
      when(scheduler.generateRecurringTasks(any)).thenAnswer((_) async {});

      await provider.addTask(
        Task(title: 'R', cplTime: date, recurrence: 'daily'),
      );

      final captured = verify(repo.addTask(captureAny)).captured.single as Task;
      expect(captured.loopId, 'loop-x');
      verify(scheduler.generateRecurringTasks(any)).called(1);
    });

    test('addTask 已有 loopId 时保留原值', () async {
      when(repo.addTask(any)).thenAnswer(
        (_) async => Task(id: 3, title: 'R', cplTime: date, recurrence: 'daily'),
      );
      when(repo.getTasksForDate(any)).thenAnswer((_) async => []);
      when(scheduler.generateRecurringTasks(any)).thenAnswer((_) async {});

      await provider.addTask(
        Task(title: 'R', cplTime: date, recurrence: 'daily', loopId: 'l1'),
      );

      final captured = verify(repo.addTask(captureAny)).captured.single as Task;
      expect(captured.loopId, 'l1');
      verifyNever(scheduler.generateLoopId());
    });

    test('updateTask 循环任务触发重新生成', () async {
      when(repo.updateTask(any, updateAll: anyNamed('updateAll'))).thenAnswer(
        (_) async {},
      );
      when(repo.getTasksForDate(any)).thenAnswer((_) async => []);
      when(scheduler.generateRecurringTasks(any)).thenAnswer((_) async {});

      await provider.updateTask(
        Task(id: 1, title: 'R', cplTime: date, recurrence: 'weekly'),
      );

      verify(scheduler.generateRecurringTasks(any)).called(1);
    });

    test('updateTask 非循环任务不触发重新生成', () async {
      when(repo.updateTask(any, updateAll: anyNamed('updateAll'))).thenAnswer(
        (_) async {},
      );
      when(repo.getTasksForDate(any)).thenAnswer((_) async => []);

      await provider.updateTask(Task(id: 1, title: 'N', cplTime: date));

      verifyNever(scheduler.generateRecurringTasks(any));
    });

    test('deleteTask 单次删除刷新回收站，批量删除不刷新', () async {
      when(repo.getTasksForDate(any)).thenAnswer((_) async => []);
      when(repo.deleteTask(any, deleteAll: anyNamed('deleteAll'))).thenAnswer(
        (_) async {},
      );
      when(repo.getRecycledTasks()).thenAnswer((_) async => []);

      await provider.deleteTask(1);
      verify(repo.getRecycledTasks()).called(1);

      clearInteractions(repo);
      await provider.deleteTask(1, deleteAll: true);
      verifyNever(repo.getRecycledTasks());
    });

    test('selectDate 会重新加载任务', () async {
      when(repo.getTasksForDate(any)).thenAnswer((_) async => []);

      provider.selectDate(date);

      expect(provider.selectedDate, date);
      verify(repo.getTasksForDate(date)).called(1);
    });

    test('setMultiTaskMode 关闭时只保留当前日期', () async {
      when(repo.getTasksForDate(any)).thenAnswer((_) async => []);
      await provider.loadTasksByDate(date);

      provider.toggleSelectedDate(DateTime(2024, 6, 16));
      expect(provider.selectedDates.length, 2);

      provider.setMultiTaskMode(true);
      expect(provider.multiTaskMode, isTrue);

      provider.setMultiTaskMode(false);
      expect(provider.selectedDates.length, 1);
    });

    test('completeTask 已完成任务直接返回 null', () async {
      final done = Task(id: 1, title: 'D', cplTime: date, isOK: true);

      expect(await provider.completeTask(done), isNull);
      verifyNever(repo.completeTask(any));
    });

    test('uncompleteTask 未完成任务不处理', () async {
      await provider.uncompleteTask(Task(id: 1, title: 'N', cplTime: date));

      verifyNever(repo.uncompleteTask(any));
    });

    test('uncompleteTask 已完成任务会冲销并重新加载', () async {
      when(repo.uncompleteTask(any)).thenAnswer((_) async {});
      when(repo.getTasksForDate(any)).thenAnswer((_) async => []);
      when(points.getLatestRecord(any, any)).thenAnswer((_) async => null);

      await provider.uncompleteTask(
        Task(id: 5, title: 'D', cplTime: date, isOK: true, rewardPoints: 10),
      );

      verify(repo.uncompleteTask(any)).called(1);
      verify(repo.getTasksForDate(any)).called(1);
    });
  });
}