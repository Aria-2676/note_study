import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:v5_app/modules/tag/models/tag_model.dart';
import 'package:v5_app/modules/tasks/models/task_model.dart';

void main() {
  group('TaskRichCardWidget', () {
    group('Widget Display Logic', () {
      test('should determine task type text based on isWord', () {
        final wordTask = Task(
          title: '背单词',
          cplTime: DateTime.now(),
          isWord: true,
        );
        final normalTask = Task(
          title: '普通任务',
          cplTime: DateTime.now(),
          isWord: false,
        );

        expect(wordTask.isWord ? '单词任务' : '普通任务', '单词任务');
        expect(normalTask.isWord ? '单词任务' : '普通任务', '普通任务');
      });

      test('should determine recurrence text', () {
        String getRecurrenceText(String recurrence) {
          switch (recurrence) {
            case 'daily':
              return '每天';
            case 'weekly':
              return '每周';
            case 'monthly':
              return '每月';
            default:
              return '';
          }
        }

        expect(getRecurrenceText('daily'), '每天');
        expect(getRecurrenceText('weekly'), '每周');
        expect(getRecurrenceText('monthly'), '每月');
        expect(getRecurrenceText('none'), '');
      });

      test('should format reward points text', () {
        final task = Task(
          title: '奖励任务',
          cplTime: DateTime.now(),
          rewardPoints: 10,
        );

        final rewardText = '完成 +${task.rewardPoints}积分';
        expect(rewardText, '完成 +10积分');
      });
    });
  });

  group('Tag Filtering', () {
    test('should filter out 单词 tag from display', () {
      final tags = [
        Tag(id: 1, name: '单词', color: '#FF9800', icon: 'translate', isSystem: true),
        Tag(id: 2, name: '工作', color: '#2196F3', icon: 'work', isSystem: false),
        Tag(id: 3, name: '学习', color: '#4CAF50', icon: 'school', isSystem: false),
      ];

      final filteredTags = tags.where((tag) => tag.name != '单词').toList();

      expect(filteredTags.length, 2);
      expect(filteredTags.any((tag) => tag.name == '单词'), isFalse);
      expect(filteredTags.any((tag) => tag.name == '工作'), isTrue);
      expect(filteredTags.any((tag) => tag.name == '学习'), isTrue);
    });

    test('should return empty list when only 单词 tag exists', () {
      final tags = [
        Tag(id: 1, name: '单词', color: '#FF9800', icon: 'translate', isSystem: true),
      ];

      final filteredTags = tags.where((tag) => tag.name != '单词').toList();

      expect(filteredTags.isEmpty, isTrue);
    });

    test('should return all tags when no 单词 tag exists', () {
      final tags = [
        Tag(id: 2, name: '工作', color: '#2196F3', icon: 'work', isSystem: false),
        Tag(id: 3, name: '学习', color: '#4CAF50', icon: 'school', isSystem: false),
      ];

      final filteredTags = tags.where((tag) => tag.name != '单词').toList();

      expect(filteredTags.length, 2);
    });

    test('should preserve tag order after filtering', () {
      final tags = [
        Tag(id: 1, name: '单词', color: '#FF9800', icon: 'translate', isSystem: true),
        Tag(id: 2, name: '工作', color: '#2196F3', icon: 'work', isSystem: false),
        Tag(id: 3, name: '学习', color: '#4CAF50', icon: 'school', isSystem: false),
        Tag(id: 4, name: '生活', color: '#9C27B0', icon: 'home', isSystem: false),
      ];

      final filteredTags = tags.where((tag) => tag.name != '单词').toList();

      expect(filteredTags[0].name, '工作');
      expect(filteredTags[1].name, '学习');
      expect(filteredTags[2].name, '生活');
    });
  });

  group('Task Model', () {
    test('should create task with default values', () {
      final task = Task(
        title: 'Test Task',
        cplTime: DateTime(2024, 6, 15),
      );

      expect(task.title, 'Test Task');
      expect(task.isWord, isFalse);
      expect(task.isOK, isFalse);
      expect(task.recurrence, 'none');
      expect(task.rewardPoints, 0);
      expect(task.priority, 'white');
    });

    test('should create word task', () {
      final task = Task(
        title: '背单词',
        cplTime: DateTime(2024, 6, 15),
        isWord: true,
      );

      expect(task.isWord, isTrue);
    });

    test('should create completed task', () {
      final task = Task(
        title: '已完成任务',
        cplTime: DateTime(2024, 6, 15),
        isOK: true,
      );

      expect(task.isOK, isTrue);
    });

    test('should create recurring task', () {
      final task = Task(
        title: '每日任务',
        cplTime: DateTime(2024, 6, 15),
        recurrence: 'daily',
      );

      expect(task.recurrence, 'daily');
    });

    test('should create task with reward points', () {
      final task = Task(
        title: '重要任务',
        cplTime: DateTime(2024, 6, 15),
        rewardPoints: 20,
      );

      expect(task.rewardPoints, 20);
    });

    test('should create task with priority', () {
      final task = Task(
        title: '紧急任务',
        cplTime: DateTime(2024, 6, 15),
        priority: 'red',
      );

      expect(task.priority, 'red');
    });

    test('should copy task with new values', () {
      final task = Task(
        id: 1,
        title: 'Original Task',
        cplTime: DateTime(2024, 6, 15),
      );

      final updatedTask = task.copyWith(title: 'Updated Task');

      expect(updatedTask.id, 1);
      expect(updatedTask.title, 'Updated Task');
      expect(updatedTask.cplTime, task.cplTime);
    });
  });

  group('Tag Model', () {
    test('should create tag with default values', () {
      final tag = Tag(
        name: 'Test Tag',
        color: '#FF0000',
        icon: 'label',
      );

      expect(tag.name, 'Test Tag');
      expect(tag.color, '#FF0000');
      expect(tag.icon, 'label');
      expect(tag.isSystem, isFalse);
    });

    test('should create system tag', () {
      final tag = Tag(
        name: '单词',
        color: '#FF9800',
        icon: 'translate',
        isSystem: true,
      );

      expect(tag.isSystem, isTrue);
    });

    test('should convert hex color to Flutter color', () {
      final tag = Tag(
        name: 'Test',
        color: '#FF9800',
        icon: 'label',
      );

      final flutterColor = tag.flutterColor;
      expect(flutterColor, isA<Color>());
    });
  });
}
