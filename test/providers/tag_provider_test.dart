import 'package:flutter_test/flutter_test.dart';
import 'package:v5_app/modules/tag/models/tag_model.dart';

void main() {
  group('Tag', () {
    test('should create with required values', () {
      final tag = Tag(name: '测试标签');

      expect(tag.id, isNull);
      expect(tag.name, '测试标签');
      expect(tag.color, '#2196F3');
      expect(tag.icon, isNull);
      expect(tag.isSystem, false);
      expect(tag.createdAt, isNotNull);
    });

    test('should create with all values', () {
      final customDate = DateTime(2024, 1, 1);
      final tag = Tag(
        id: 1,
        name: '工作',
        color: '#FF9800',
        icon: 'work',
        isSystem: true,
        createdAt: customDate,
      );

      expect(tag.id, 1);
      expect(tag.name, '工作');
      expect(tag.color, '#FF9800');
      expect(tag.icon, 'work');
      expect(tag.isSystem, true);
      expect(tag.createdAt, customDate);
    });

    test('should convert to Map correctly', () {
      final tag = Tag(
        id: 1,
        name: '学习',
        color: '#4CAF50',
        icon: 'school',
        isSystem: true,
      );

      final map = tag.toMap();

      expect(map['id'], 1);
      expect(map['name'], '学习');
      expect(map['color'], '#4CAF50');
      expect(map['icon'], 'school');
      expect(map['isSystem'], 1);
    });

    test('should not include null id in Map', () {
      final tag = Tag(name: '测试');

      final map = tag.toMap();

      expect(map.containsKey('id'), false);
    });

    test('should create from Map correctly', () {
      final map = {
        'id': 2,
        'name': '生活',
        'color': '#9C27B0',
        'icon': 'home',
        'isSystem': 1,
        'createdAt': '2024-01-01T12:00:00.000',
      };

      final tag = Tag.fromMap(map);

      expect(tag.id, 2);
      expect(tag.name, '生活');
      expect(tag.color, '#9C27B0');
      expect(tag.icon, 'home');
      expect(tag.isSystem, true);
    });

    test('should handle null values in fromMap', () {
      final map = <String, dynamic>{'name': '测试'};

      final tag = Tag.fromMap(map);

      expect(tag.id, isNull);
      expect(tag.color, '#2196F3');
      expect(tag.icon, isNull);
      expect(tag.isSystem, false);
    });

    test('copyWith should update specified fields', () {
      final original = Tag(id: 1, name: '原标签', color: '#FF0000');
      final copied = original.copyWith(name: '新标签');

      expect(copied.id, 1);
      expect(copied.name, '新标签');
      expect(copied.color, '#FF0000');
    });

    test('flutterColor should return correct Color', () {
      final tag = Tag(name: '测试', color: '#FF9800');

      expect(tag.flutterColor.toARGB32(), 0xFFFF9800);
    });

    test('flutterColor should handle invalid color', () {
      final tag = Tag(name: '测试', color: 'invalid');

      expect(tag.flutterColor, isNotNull);
    });

    test('defaultTags should have 4 tags', () {
      expect(Tag.defaultTags.length, 4);
    });

    test('defaultTags should all be system tags', () {
      for (final tag in Tag.defaultTags) {
        expect(tag.isSystem, true);
      }
    });

    test('defaultTags should have expected names', () {
      final names = Tag.defaultTags.map((t) => t.name).toList();
      expect(names, contains('单词'));
      expect(names, contains('工作'));
      expect(names, contains('学习'));
      expect(names, contains('生活'));
    });
  });

  group('TaskTag', () {
    test('should create with required values', () {
      final taskTag = TaskTag(taskId: 1, tagId: 2);

      expect(taskTag.taskId, 1);
      expect(taskTag.tagId, 2);
    });

    test('should convert to Map correctly', () {
      final taskTag = TaskTag(taskId: 1, tagId: 2);

      final map = taskTag.toMap();

      expect(map['taskId'], 1);
      expect(map['tagId'], 2);
    });

    test('should create from Map correctly', () {
      final map = {'taskId': 3, 'tagId': 4};

      final taskTag = TaskTag.fromMap(map);

      expect(taskTag.taskId, 3);
      expect(taskTag.tagId, 4);
    });
  });
}
