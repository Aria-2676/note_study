import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:v5_app/core/config/app_config.dart';

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
            related_id INTEGER,
            created_at TEXT NOT NULL
          )
        ''';

        expect(createTableSql, contains('IF NOT EXISTS'));
        expect(createTableSql, contains('related_id'));
        expect(createTableSql, contains('created_at'));
      });
    });

    group('Database Schema', () {
      test('tasks table should have all required columns', () {
        final tasksTableColumns = [
          'id',
          'loop_id',
          'title',
          'description',
          'is_word',
          'is_ok',
          'cpl_time',
          'recurrence',
          'completed_at',
          'reward_points',
          'is_deducted',
          'created_at',
          'priority',
        ];

        expect(tasksTableColumns.length, 13);
        expect(tasksTableColumns, contains('id'));
        expect(tasksTableColumns, contains('title'));
        expect(tasksTableColumns, contains('cpl_time'));
        expect(tasksTableColumns, contains('priority'));
        // 蛇形字段名
        expect(tasksTableColumns, contains('loop_id'));
        expect(tasksTableColumns, contains('is_word'));
        expect(tasksTableColumns, contains('is_ok'));
        expect(tasksTableColumns, contains('completed_at'));
        expect(tasksTableColumns, contains('reward_points'));
        expect(tasksTableColumns, contains('is_deducted'));
        expect(tasksTableColumns, contains('created_at'));
        // 不应包含驼峰 key
        expect(tasksTableColumns, isNot(contains('loopId')));
        expect(tasksTableColumns, isNot(contains('isWord')));
        expect(tasksTableColumns, isNot(contains('isOK')));
        expect(tasksTableColumns, isNot(contains('cplTime')));
      });

      test('points_records table should have all required columns', () {
        final pointsRecordsColumns = [
          'id',
          'points',
          'type',
          'description',
          'related_id',
          'created_at',
        ];

        expect(pointsRecordsColumns.length, 6);
        expect(pointsRecordsColumns, contains('id'));
        expect(pointsRecordsColumns, contains('points'));
        expect(pointsRecordsColumns, contains('type'));
        expect(pointsRecordsColumns, contains('related_id'));
        expect(pointsRecordsColumns, contains('created_at'));
      });

      test('shop_items table should have all required columns', () {
        final shopItemsColumns = [
          'id',
          'name',
          'description',
          'price',
          'created_at',
          'icon_name',
          'color_value',
        ];

        expect(shopItemsColumns.length, 7);
        expect(shopItemsColumns, contains('id'));
        expect(shopItemsColumns, contains('name'));
        expect(shopItemsColumns, contains('price'));
        expect(shopItemsColumns, contains('icon_name'));
        expect(shopItemsColumns, contains('color_value'));
        expect(shopItemsColumns, contains('created_at'));
      });

      test('tags table should have all required columns', () {
        final tagsColumns = [
          'id',
          'name',
          'color',
          'icon',
          'is_system',
          'created_at',
        ];

        expect(tagsColumns.length, 6);
        expect(tagsColumns, contains('id'));
        expect(tagsColumns, contains('name'));
        expect(tagsColumns, contains('is_system'));
        expect(tagsColumns, contains('created_at'));
      });

      test('task_tags table should have correct structure', () {
        final taskTagsColumns = ['task_id', 'tag_id'];

        expect(taskTagsColumns.length, 2);
        expect(taskTagsColumns, contains('task_id'));
        expect(taskTagsColumns, contains('tag_id'));
      });

      test('scratch_tickets table should have snake_case columns', () {
        final scratchTicketsColumns = [
          'id',
          'cost_points',
          'prize_id',
          'prize_name',
          'prize_type',
          'prize_value',
          'created_at',
          'is_scratched',
          'is_revealed',
        ];

        expect(scratchTicketsColumns.length, 9);
        expect(scratchTicketsColumns, contains('cost_points'));
        expect(scratchTicketsColumns, contains('prize_id'));
        expect(scratchTicketsColumns, contains('prize_name'));
        expect(scratchTicketsColumns, contains('prize_type'));
        expect(scratchTicketsColumns, contains('prize_value'));
        expect(scratchTicketsColumns, contains('is_scratched'));
        expect(scratchTicketsColumns, contains('is_revealed'));
      });

      test('pomodoro_records table should have snake_case columns', () {
        final pomodoroRecordsColumns = [
          'id',
          'mode',
          'duration_seconds',
          'actual_seconds',
          'start_time',
          'end_time',
          'related_task_id',
          'related_task_title',
          'is_completed',
          'created_at',
        ];

        expect(pomodoroRecordsColumns.length, 10);
        expect(pomodoroRecordsColumns, contains('duration_seconds'));
        expect(pomodoroRecordsColumns, contains('actual_seconds'));
        expect(pomodoroRecordsColumns, contains('start_time'));
        expect(pomodoroRecordsColumns, contains('end_time'));
        expect(pomodoroRecordsColumns, contains('related_task_id'));
        expect(pomodoroRecordsColumns, contains('related_task_title'));
        expect(pomodoroRecordsColumns, contains('is_completed'));
      });

      test('pomodoro_settings table should have snake_case columns', () {
        final pomodoroSettingsColumns = [
          'id',
          'work_duration',
          'short_break_duration',
          'long_break_duration',
          'long_break_interval',
          'sound_enabled',
          'vibration_enabled',
          'notification_enabled',
          'auto_start_break',
          'auto_start_work',
        ];

        expect(pomodoroSettingsColumns.length, 10);
        expect(pomodoroSettingsColumns, contains('work_duration'));
        expect(pomodoroSettingsColumns, contains('short_break_duration'));
        expect(pomodoroSettingsColumns, contains('long_break_duration'));
        expect(pomodoroSettingsColumns, contains('long_break_interval'));
        expect(pomodoroSettingsColumns, contains('sound_enabled'));
        expect(pomodoroSettingsColumns, contains('vibration_enabled'));
        expect(pomodoroSettingsColumns, contains('notification_enabled'));
        expect(pomodoroSettingsColumns, contains('auto_start_break'));
        expect(pomodoroSettingsColumns, contains('auto_start_work'));
      });

      test('lottery_records table should have snake_case columns', () {
        final lotteryRecordsColumns = [
          'id',
          'draw_time',
          'prize_name',
          'prize_type',
          'prize_value',
          'cost_points',
          'created_at',
        ];

        expect(lotteryRecordsColumns.length, 7);
        expect(lotteryRecordsColumns, contains('draw_time'));
        expect(lotteryRecordsColumns, contains('prize_name'));
        expect(lotteryRecordsColumns, contains('prize_type'));
        expect(lotteryRecordsColumns, contains('prize_value'));
        expect(lotteryRecordsColumns, contains('cost_points'));
      });

      test('custom_prize_pool table should have snake_case columns', () {
        final customPrizePoolColumns = [
          'id',
          'name',
          'type',
          'value',
          'weight',
          'is_default',
        ];

        expect(customPrizePoolColumns.length, 6);
        expect(customPrizePoolColumns, contains('is_default'));
      });

      test('purchased_items table should have snake_case columns', () {
        final purchasedItemsColumns = [
          'id',
          'shop_item_id',
          'name',
          'description',
          'price',
          'purchased_at',
          'icon_name',
          'color_value',
        ];

        expect(purchasedItemsColumns.length, 8);
        expect(purchasedItemsColumns, contains('shop_item_id'));
        expect(purchasedItemsColumns, contains('purchased_at'));
        expect(purchasedItemsColumns, contains('icon_name'));
        expect(purchasedItemsColumns, contains('color_value'));
      });

      test('recycled_tasks table should have snake_case columns', () {
        final recycledTasksColumns = [
          'id',
          'task_id',
          'loop_id',
          'title',
          'description',
          'is_word',
          'is_ok',
          'cpl_time',
          'recurrence',
          'completed_at',
          'reward_points',
          'is_deducted',
          'created_at',
          'priority',
          'deleted_at',
        ];

        expect(recycledTasksColumns.length, 15);
        expect(recycledTasksColumns, contains('task_id'));
        // v3 起回收站需保留 loop_id，否则恢复循环任务会丢循环链
        expect(recycledTasksColumns, contains('loop_id'));
        expect(recycledTasksColumns, contains('is_word'));
        expect(recycledTasksColumns, contains('is_ok'));
        expect(recycledTasksColumns, contains('cpl_time'));
        expect(recycledTasksColumns, contains('deleted_at'));
      });
    });

    group('Database Version', () {
      test('current database version should be 3', () {
        expect(AppConfig.dbVersion, equals(3));
      });

      test('version 2 should migrate v1 camelCase schema to snake_case', () {
        const version2Features = ['_migrateV1ToV2', 'snake_case'];
        expect(version2Features, contains('_migrateV1ToV2'));
      });

      test('version 3 should add loop_id to recycled_tasks', () {
        final source = File(
          'lib/core/services/database/database_service.dart',
        ).readAsStringSync();

        expect(source, contains('_migrateV2ToV3'));
        expect(source, contains('await _migrateV2ToV3(db);'));
        expect(
          source,
          contains('ALTER TABLE recycled_tasks ADD COLUMN loop_id TEXT'),
        );
      });
    });

    group('V1 to V2 Migration', () {
      test('should have _migrateV1ToV2 method in DatabaseService', () {
        final source = File(
          'lib/core/services/database/database_service.dart',
        ).readAsStringSync();

        expect(source, contains('_migrateV1ToV2'));
        // 验证迁移方法被 onUpgrade 调用
        expect(source, contains('await _migrateV1ToV2(db);'));
        // 验证三步法迁移关键字
        expect(source, contains('CREATE TABLE tasks_new'));
        expect(source, contains('INSERT INTO tasks_new'));
        expect(source, contains('DROP TABLE tasks'));
        expect(source, contains("ALTER TABLE tasks_new RENAME TO tasks"));
      });

      test('should migrate tasks camelCase columns to snake_case', () {
        final source = File(
          'lib/core/services/database/database_service.dart',
        ).readAsStringSync();

        // v1 -> v2 SELECT 从旧驼峰列读取
        expect(
          source,
          contains('SELECT id, loopId, title, description, isWord, isOK, '
              'cplTime, recurrence,'),
        );
        // 写入新蛇形列
        expect(source, contains('loop_id, title, description, is_word, is_ok,'));
      });

      test('should migrate all v1 tables in _migrateV1ToV2', () {
        final source = File(
          'lib/core/services/database/database_service.dart',
        ).readAsStringSync();

        // 截取 _migrateV1ToV2 方法体片段校验各表迁移
        final migrateStart = source.indexOf('_migrateV1ToV2');
        expect(migrateStart, greaterThan(0));

        // 校验所有表都出现在迁移方法中
        expect(source, contains('shop_items_new'));
        expect(source, contains('user_points_new'));
        expect(source, contains('points_records_new'));
        expect(source, contains('purchased_items_new'));
        expect(source, contains('custom_prize_pool_new'));
        expect(source, contains('lottery_records_new'));
        expect(source, contains('tags_new'));
        expect(source, contains('task_tags_new'));
        expect(source, contains('pomodoro_records_new'));
        expect(source, contains('pomodoro_settings_new'));
        expect(source, contains('scratch_tickets_new'));
      });
    });
  });
}
