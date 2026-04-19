import 'package:flutter_test/flutter_test.dart';
import 'package:v5_app/providers/points_provider.dart';
import 'package:v5_app/modules/points/models/points_model.dart';

void main() {
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
      expect(map['updatedAt'], isNotNull);
    });

    test('should create from Map correctly', () {
      final map = {
        'id': 2,
        'points': 200,
        'updatedAt': '2024-01-01T12:00:00.000',
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
      expect(map['relatedId'], 10);
      expect(map['createdAt'], isNotNull);
    });

    test('should create from Map correctly', () {
      final map = {
        'id': 2,
        'points': -10,
        'type': 'scratch_cost',
        'description': '刮刮卡消费',
        'relatedId': 3,
        'createdAt': '2024-01-01T12:00:00.000',
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
}
