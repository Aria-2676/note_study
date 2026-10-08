import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:v5_app/modules/points/models/points_model.dart';
import 'package:v5_app/modules/tasks/models/task_model.dart';
import 'package:v5_app/providers/task_provider.dart';

import 'task_provider_test.mocks.dart';

/// TaskProvider 的积分结算 / 月份缓存 / 批量操作 / 小组件数据源相关用例。
///
/// 由原 `task_provider_test.dart` 拆分而来（规范 6：单文件 ≤500 行）；
/// Mock 定义与生成文件仍复用 `task_provider_test.mocks.dart`。
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