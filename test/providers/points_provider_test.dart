import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:v5_app/core/services/database/database_service.dart';
import 'package:v5_app/providers/points_provider.dart';
import 'package:v5_app/modules/points/models/points_model.dart';

void main() {
  // 让 DatabaseService.instance 在测试进程内落到 ffi 的 SQLite 上，
  // 并用独立临时目录隔离，避免与其它测试文件并发争用同一个库文件。
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
  setUpAll(() async {
    final dir = Directory.systemTemp.createTempSync('v5_points_test');
    await databaseFactory.setDatabasesPath(dir.path);
  });

  group('PointsProvider', () {
    test('should have correct initial values', () {
      final provider = PointsProvider();

      expect(provider.currentPoints, 0);
      expect(provider.records, isEmpty);
      expect(provider.userPoints.id, 1);
    });

    test('userPoints should return UserPoints instance', () {
      final provider = PointsProvider();

      expect(provider.userPoints, isA<UserPoints>());
    });

    test('currentPoints should return userPoints.points', () {
      final provider = PointsProvider();

      expect(provider.currentPoints, provider.userPoints.points);
    });
  });

  group('UserPoints', () {
    test('should create with default values', () {
      final userPoints = UserPoints();

      expect(userPoints.id, 1);
      expect(userPoints.points, 0);
      expect(userPoints.updatedAt, isNotNull);
    });

    test('should create with custom values', () {
      final customDate = DateTime(2024, 1, 1);
      final userPoints = UserPoints(
        id: 2,
        points: 100,
        updatedAt: customDate,
      );

      expect(userPoints.id, 2);
      expect(userPoints.points, 100);
      expect(userPoints.updatedAt, customDate);
    });

    test('should convert to Map correctly', () {
      final userPoints = UserPoints(
        id: 1,
        points: 50,
      );

      final map = userPoints.toMap();

      expect(map['id'], 1);
      expect(map['points'], 50);
      expect(map['updated_at'], isNotNull);
    });

    test('should create from Map correctly', () {
      final map = {
        'id': 2,
        'points': 200,
        'updated_at': '2024-01-01T12:00:00.000',
      };

      final userPoints = UserPoints.fromMap(map);

      expect(userPoints.id, 2);
      expect(userPoints.points, 200);
    });

    test('should handle null values in fromMap', () {
      final map = <String, dynamic>{};

      final userPoints = UserPoints.fromMap(map);

      expect(userPoints.id, 1);
      expect(userPoints.points, 0);
    });

    test('copyWith should update specified fields', () {
      final original = UserPoints(id: 1, points: 100);
      final copied = original.copyWith(points: 200);

      expect(copied.id, 1);
      expect(copied.points, 200);
    });
  });

  group('PointsRecord', () {
    test('should create with required values', () {
      final record = PointsRecord(
        points: 10,
        type: 'task_complete',
        description: '完成任务',
      );

      expect(record.id, isNull);
      expect(record.points, 10);
      expect(record.type, 'task_complete');
      expect(record.description, '完成任务');
      expect(record.relatedId, isNull);
      expect(record.createdAt, isNotNull);
    });

    test('should create with all values', () {
      final customDate = DateTime(2024, 1, 1);
      final record = PointsRecord(
        id: 1,
        points: 20,
        type: 'shop_exchange',
        description: '兑换商品',
        relatedId: 5,
        createdAt: customDate,
      );

      expect(record.id, 1);
      expect(record.points, 20);
      expect(record.type, 'shop_exchange');
      expect(record.description, '兑换商品');
      expect(record.relatedId, 5);
      expect(record.createdAt, customDate);
    });

    test('should convert to Map correctly', () {
      final record = PointsRecord(
        id: 1,
        points: 15,
        type: 'bonus',
        description: '奖励',
        relatedId: 10,
      );

      final map = record.toMap();

      expect(map['id'], 1);
      expect(map['points'], 15);
      expect(map['type'], 'bonus');
      expect(map['description'], '奖励');
      expect(map['related_id'], 10);
      expect(map['created_at'], isNotNull);
    });

    test('should create from Map correctly', () {
      final map = {
        'id': 2,
        'points': -10,
        'type': 'scratch_cost',
        'description': '刮刮卡消费',
        'related_id': 3,
        'created_at': '2024-01-01T12:00:00.000',
      };

      final record = PointsRecord.fromMap(map);

      expect(record.id, 2);
      expect(record.points, -10);
      expect(record.type, 'scratch_cost');
      expect(record.description, '刮刮卡消费');
      expect(record.relatedId, 3);
    });

    test('should handle negative points for deductions', () {
      final record = PointsRecord(
        points: -50,
        type: 'shop_exchange',
        description: '兑换商品',
      );

      expect(record.points, -50);
    });
  });

  group('PointsProvider 数据库交互', () {
    late PointsProvider provider;

    setUp(() async {
      // clearAllData 会把积分清零、清空流水，保证每个用例起点一致
      await DatabaseService.instance.clearAllData();
      provider = PointsProvider();
      await provider.initialize();
    });

    test('should load zero points and empty records after initialize', () {
      expect(provider.currentPoints, 0);
      expect(provider.records, isEmpty);
    });

    test('addPoints should increase the balance', () async {
      await provider.addPoints(50);
      expect(provider.currentPoints, 50);
    });

    test('addPoints should accumulate across calls', () async {
      await provider.addPoints(10);
      await provider.addPoints(15);
      expect(provider.currentPoints, 25);
    });

    test('deductPoints should decrease the balance', () async {
      await provider.addPoints(50);
      await provider.deductPoints(20);
      expect(provider.currentPoints, 30);
    });

    test('updatePoints should set the exact balance', () async {
      await provider.addPoints(50);
      await provider.updatePoints(123);
      expect(provider.currentPoints, 123);
    });

    test('addPointsWithRecord should write points and a positive record',
        () async {
      await provider.addPointsWithRecord(
        points: 30,
        type: 'task_complete',
        description: '完成任务',
        relatedId: 7,
      );

      expect(provider.currentPoints, 30);
      expect(provider.records.length, 1);
      expect(provider.records.single.points, 30);
      expect(provider.records.single.type, 'task_complete');
      expect(provider.records.single.relatedId, 7);
    });

    test('deductPointsWithRecord should write negative points and record',
        () async {
      await provider.addPointsWithRecord(
        points: 30,
        type: 'task_complete',
        description: '完成任务',
        relatedId: 7,
      );
      await provider.deductPointsWithRecord(
        points: 10,
        type: 'task_uncomplete',
        description: '取消完成',
        relatedId: 7,
      );

      expect(provider.currentPoints, 20);
      expect(provider.records.first.points, -10);
      expect(provider.records.first.type, 'task_uncomplete');
    });

    test('hasRecordForTypeAndRelatedId should reflect stored records',
        () async {
      await provider.addPointsWithRecord(
        points: 5,
        type: 'task_complete',
        description: '完成任务',
        relatedId: 9,
      );

      expect(
        await provider.hasRecordForTypeAndRelatedId('task_complete', 9),
        isTrue,
      );
      expect(
        await provider.hasRecordForTypeAndRelatedId('task_complete', 99),
        isFalse,
      );
    });

    test('getLatestRecord should return the newest matching record', () async {
      await provider.addPointsWithRecord(
        points: 10,
        type: 'task_complete',
        description: '完成任务',
        relatedId: 3,
      );
      await provider.deductPointsWithRecord(
        points: 10,
        type: 'task_uncomplete',
        description: '取消完成',
        relatedId: 3,
      );

      final latest = await provider.getLatestRecord(3, [
        'task_complete',
        'task_uncomplete',
      ]);

      expect(latest, isNotNull);
      expect(latest!.type, 'task_uncomplete');
    });

    test('getLatestRecord should return null when nothing matches', () async {
      expect(await provider.getLatestRecord(404, ['task_complete']), isNull);
      expect(await provider.getLatestRecord(404, []), isNull);
    });

    test('reload should re-read points modified directly in the database',
        () async {
      await DatabaseService.instance.updateUserPoints(999);
      await provider.reload();
      expect(provider.currentPoints, 999);
    });

    test('refreshRecords should reload the record list', () async {
      await DatabaseService.instance.addPointsRecord(
        PointsRecord(points: 1, type: 'manual', description: '手工记录'),
      );
      await provider.refreshRecords();
      expect(provider.records.length, 1);
    });

    test('records should be capped at 50 entries', () async {
      for (var i = 0; i < 60; i++) {
        await DatabaseService.instance.addPointsRecord(
          PointsRecord(points: i, type: 'bulk', description: '记录$i'),
        );
      }
      await provider.refreshRecords();
      expect(provider.records.length, 50);
    });

    test('should notify listeners when points change', () async {
      var notifyCount = 0;
      provider.addListener(() => notifyCount++);

      await provider.addPoints(10);

      expect(notifyCount, greaterThanOrEqualTo(1));
    });
  });
}
