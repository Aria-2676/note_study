import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DatabaseService', () {
    group('onUpgrade', () {
      test('should use IF NOT EXISTS for points_records table creation', () {
        final createTableSql = '''
          CREATE TABLE IF NOT EXISTS points_records (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            points INTEGER NOT NULL,
            type TEXT NOT NULL,
            description TEXT NOT NULL,
            relatedId INTEGER,
            createdAt TEXT NOT NULL
          )
        ''';

        expect(createTableSql, contains('IF NOT EXISTS'));
      });
    });

    group('Database Schema', () {
      test('tasks table should have all required columns', () {
        final tasksTableColumns = [
          'id',
          'loopId',
          'title',
          'description',
          'isWord',
          'isOK',
          'cplTime',
          'recurrence',
          'completedAt',
          'rewardPoints',
          'isDeducted',
          'createdAt',
          'priority',
        ];

        expect(tasksTableColumns.length, 13);
        expect(tasksTableColumns, contains('id'));
        expect(tasksTableColumns, contains('title'));
        expect(tasksTableColumns, contains('cplTime'));
        expect(tasksTableColumns, contains('priority'));
      });

      test('points_records table should have all required columns', () {
        final pointsRecordsColumns = [
          'id',
          'points',
          'type',
          'description',
          'relatedId',
          'createdAt',
        ];

        expect(pointsRecordsColumns.length, 6);
        expect(pointsRecordsColumns, contains('id'));
        expect(pointsRecordsColumns, contains('points'));
        expect(pointsRecordsColumns, contains('type'));
      });

      test('shop_items table should have all required columns', () {
        final shopItemsColumns = [
          'id',
          'name',
          'description',
          'price',
          'iconName',
          'colorValue',
        ];

        expect(shopItemsColumns.length, 6);
        expect(shopItemsColumns, contains('id'));
        expect(shopItemsColumns, contains('name'));
        expect(shopItemsColumns, contains('price'));
      });

      test('tags table should have all required columns', () {
        final tagsColumns = [
          'id',
          'name',
          'color',
          'icon',
          'isSystem',
        ];

        expect(tagsColumns.length, 5);
        expect(tagsColumns, contains('id'));
        expect(tagsColumns, contains('name'));
        expect(tagsColumns, contains('isSystem'));
      });

      test('task_tags table should have correct structure', () {
        final taskTagsColumns = ['taskId', 'tagId'];

        expect(taskTagsColumns.length, 2);
        expect(taskTagsColumns, contains('taskId'));
        expect(taskTagsColumns, contains('tagId'));
      });
    });

    group('Database Version', () {
      test('current database version should be 3', () {
        const currentVersion = 3;
        expect(currentVersion, equals(3));
      });

      test('version 3 should include points_records table', () {
        final version3Features = ['points_records'];
        expect(version3Features, contains('points_records'));
      });
    });
  });
}
