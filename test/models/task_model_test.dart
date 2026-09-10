import 'package:flutter_test/flutter_test.dart';
import 'package:v5_app/modules/tasks/models/task_model.dart';

void main() {
  group('Task', () {
    test('toMap should return snake_case keys', () {
      final task = Task(
        title: '测试任务',
        description: '描述',
        cplTime: DateTime(2026, 9, 10),
        createdAt: DateTime(2026, 9, 10),
        loopId: 'loop_123',
        isWord: true,
        isOK: true,
        completedAt: DateTime(2026, 9, 10),
        rewardPoints: 10,
        isDeducted: true,
        priority: 'red',
        recurrence: 'daily',
      );
      final map = task.toMap();
      expect(map.containsKey('loop_id'), isTrue);
      expect(map.containsKey('is_word'), isTrue);
      expect(map.containsKey('is_ok'), isTrue);
      expect(map.containsKey('cpl_time'), isTrue);
      expect(map.containsKey('completed_at'), isTrue);
      expect(map.containsKey('reward_points'), isTrue);
      expect(map.containsKey('is_deducted'), isTrue);
      expect(map.containsKey('created_at'), isTrue);
      expect(map.containsKey('priority'), isTrue);
      expect(map.containsKey('recurrence'), isTrue);
      // 不应包含驼峰 key
      expect(map.containsKey('loopId'), isFalse);
      expect(map.containsKey('isWord'), isFalse);
      expect(map.containsKey('isOK'), isFalse);
      expect(map.containsKey('cplTime'), isFalse);
      expect(map.containsKey('completedAt'), isFalse);
      expect(map.containsKey('rewardPoints'), isFalse);
      expect(map.containsKey('isDeducted'), isFalse);
      expect(map.containsKey('createdAt'), isFalse);
    });

    test('fromMap should read snake_case keys', () {
      final map = {
        'id': 1,
        'loop_id': 'loop_123',
        'title': '测试',
        'description': null,
        'is_word': 1,
        'is_ok': 0,
        'cpl_time': '2026-09-10T00:00:00.000',
        'recurrence': 'none',
        'completed_at': null,
        'reward_points': 5,
        'is_deducted': 0,
        'created_at': '2026-09-10T00:00:00.000',
        'priority': 'blue',
      };
      final task = Task.fromMap(map);
      expect(task.id, 1);
      expect(task.loopId, 'loop_123');
      expect(task.isWord, isTrue);
      expect(task.isOK, isFalse);
      expect(task.rewardPoints, 5);
      expect(task.priority, 'blue');
      expect(task.recurrence, 'none');
      expect(task.completedAt, isNull);
      expect(task.isDeducted, isFalse);
    });

    test('toDbMap should equal toMap', () {
      final task = Task(
        title: '测试',
        cplTime: DateTime(2026, 9, 10),
        createdAt: DateTime(2026, 9, 10),
      );
      expect(task.toDbMap(), task.toMap());
    });

    test('default values should be correct', () {
      final task = Task(
        title: '测试',
        cplTime: DateTime(2026, 9, 10),
        createdAt: DateTime(2026, 9, 10),
      );
      expect(task.recurrence, 'none');
      expect(task.priority, 'white');
      expect(task.rewardPoints, 0);
      expect(task.isWord, isFalse);
      expect(task.isOK, isFalse);
      expect(task.isDeducted, isFalse);
      expect(task.loopId, isNull);
      expect(task.completedAt, isNull);
    });

    test('toMap and fromMap should be reversible', () {
      final task = Task(
        id: 5,
        title: '可逆测试',
        description: '描述',
        cplTime: DateTime(2026, 9, 10),
        createdAt: DateTime(2026, 9, 10),
        loopId: 'loop_abc',
        isWord: true,
        isOK: true,
        completedAt: DateTime(2026, 9, 10, 12),
        rewardPoints: 20,
        isDeducted: true,
        priority: 'red',
        recurrence: 'weekly',
      );
      final restored = Task.fromMap(task.toMap());
      expect(restored.title, task.title);
      expect(restored.description, task.description);
      expect(restored.loopId, task.loopId);
      expect(restored.isWord, task.isWord);
      expect(restored.isOK, task.isOK);
      expect(restored.cplTime, task.cplTime);
      expect(restored.recurrence, task.recurrence);
      expect(restored.completedAt, task.completedAt);
      expect(restored.rewardPoints, task.rewardPoints);
      expect(restored.isDeducted, task.isDeducted);
      expect(restored.createdAt, task.createdAt);
      expect(restored.priority, task.priority);
    });
  });

  group('RecycledTask', () {
    test('toMap should return snake_case keys', () {
      final recycled = RecycledTask(
        id: 1,
        task: Task(
          id: 10,
          title: '回收任务',
          cplTime: DateTime(2026, 9, 10),
          createdAt: DateTime(2026, 9, 10),
          loopId: 'loop_x',
          isWord: true,
          isOK: true,
          rewardPoints: 8,
          isDeducted: true,
          priority: 'yellow',
        ),
        deletedAt: DateTime(2026, 9, 10),
      );
      final map = recycled.toMap();
      expect(map.containsKey('id'), isTrue);
      expect(map.containsKey('task_id'), isTrue);
      expect(map.containsKey('cpl_time'), isTrue);
      expect(map.containsKey('is_word'), isTrue);
      expect(map.containsKey('is_ok'), isTrue);
      expect(map.containsKey('reward_points'), isTrue);
      expect(map.containsKey('is_deducted'), isTrue);
      expect(map.containsKey('created_at'), isTrue);
      expect(map.containsKey('deleted_at'), isTrue);
      expect(map.containsKey('priority'), isTrue);
      // 不应包含驼峰 key
      expect(map.containsKey('taskId'), isFalse);
      expect(map.containsKey('cplTime'), isFalse);
      expect(map.containsKey('isWord'), isFalse);
      expect(map.containsKey('deletedAt'), isFalse);
      expect(map.containsKey('rewardPoints'), isFalse);
    });

    test('fromMap should read snake_case keys', () {
      final map = {
        'id': 2,
        'task_id': 20,
        'title': '回收',
        'description': null,
        'is_word': 1,
        'is_ok': 0,
        'cpl_time': '2026-09-10T00:00:00.000',
        'recurrence': 'none',
        'completed_at': null,
        'reward_points': 3,
        'is_deducted': 0,
        'created_at': '2026-09-10T00:00:00.000',
        'priority': 'blue',
        'deleted_at': '2026-09-10T10:00:00.000',
      };
      final restored = RecycledTask.fromMap(map);
      expect(restored.id, 2);
      expect(restored.task.id, 20);
      expect(restored.task.title, '回收');
      expect(restored.task.isWord, isTrue);
      expect(restored.task.isOK, isFalse);
      expect(restored.task.rewardPoints, 3);
      expect(restored.task.priority, 'blue');
      expect(restored.deletedAt, DateTime(2026, 9, 10, 10));
    });

    test('toDbMap should equal toMap', () {
      final recycled = RecycledTask(
        id: 1,
        task: Task(
          title: '回收',
          cplTime: DateTime(2026, 9, 10),
          createdAt: DateTime(2026, 9, 10),
        ),
        deletedAt: DateTime(2026, 9, 10),
      );
      expect(recycled.toDbMap(), recycled.toMap());
    });
  });
}
