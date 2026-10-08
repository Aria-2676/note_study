import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:v5_app/core/services/database/database_service.dart';
import 'package:v5_app/providers/settings_provider.dart';
import 'package:v5_app/providers/task_provider.dart' show TaskSortOption;

void main() {
  // 让 DatabaseService.instance 落到 ffi SQLite，并用独立临时目录隔离，
  // 与 points_provider_test.dart 的既有模式保持一致。
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
  setUpAll(() async {
    final dir = Directory.systemTemp.createTempSync('v5_settings_test');
    await databaseFactory.setDatabasesPath(dir.path);
  });

  // mutation 的落库是异步的（_saveSettings 即发即忘），轮询等待指定键写入。
  Future<void> expectPersisted(String key, String value) async {
    for (var i = 0; i < 150; i++) {
      final s = await DatabaseService.instance.getSettings();
      if (s[key] == value) return;
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
    expect((await DatabaseService.instance.getSettings())[key], value);
  }

  group('TaskViewMode', () {
    test('should have correct enum values', () {
      expect(TaskViewMode.values.length, 2);
      expect(TaskViewMode.values, contains(TaskViewMode.simple));
      expect(TaskViewMode.values, contains(TaskViewMode.rich));
    });
  });

  group('TaskCreateMode', () {
    test('should have correct enum values', () {
      expect(TaskCreateMode.values.length, 3);
      expect(TaskCreateMode.values, contains(TaskCreateMode.minimal));
      expect(TaskCreateMode.values, contains(TaskCreateMode.full));
      expect(TaskCreateMode.values, contains(TaskCreateMode.custom));
    });
  });

  group('TaskEditMode', () {
    test('should have correct enum values', () {
      expect(TaskEditMode.values.length, 3);
      expect(TaskEditMode.values, contains(TaskEditMode.minimal));
      expect(TaskEditMode.values, contains(TaskEditMode.full));
      expect(TaskEditMode.values, contains(TaskEditMode.custom));
    });
  });

  group('PinnedSettingLocation', () {
    test('should have correct enum values', () {
      expect(PinnedSettingLocation.values.length, 2);
      expect(
        PinnedSettingLocation.values,
        contains(PinnedSettingLocation.profile),
      );
      expect(
        PinnedSettingLocation.values,
        contains(PinnedSettingLocation.settings),
      );
    });
  });

  group('SettingType', () {
    test('should have correct enum values', () {
      expect(SettingType.values.length, 2);
      expect(SettingType.values, contains(SettingType.toggle));
      expect(SettingType.values, contains(SettingType.segmented));
    });
  });

  group('PinnedSettingItem', () {
    test('should create toggle setting item', () {
      const item = PinnedSettingItem(
        key: 'themeMode',
        title: '夜间模式',
        icon: Icons.dark_mode,
        type: SettingType.toggle,
      );

      expect(item.key, 'themeMode');
      expect(item.title, '夜间模式');
      expect(item.type, SettingType.toggle);
      expect(item.options, isNull);
    });

    test('should create segmented setting item', () {
      const item = PinnedSettingItem(
        key: 'taskViewMode',
        title: '任务视图',
        icon: Icons.view_agenda,
        type: SettingType.segmented,
        options: ['丰富', '简洁'],
      );

      expect(item.key, 'taskViewMode');
      expect(item.type, SettingType.segmented);
      expect(item.options, ['丰富', '简洁']);
    });
  });

  group('TaskCreateField', () {
    test('should have correct default values', () {
      const field = TaskCreateField(
        key: 'test',
        label: '测试字段',
        icon: Icons.edit,
      );

      expect(field.key, 'test');
      expect(field.label, '测试字段');
      expect(field.defaultEnabled, true);
    });

    test('should allow custom defaultEnabled', () {
      const field = TaskCreateField(
        key: 'test',
        label: '测试字段',
        icon: Icons.edit,
        defaultEnabled: false,
      );

      expect(field.defaultEnabled, false);
    });
  });

  group('TaskCreateFields', () {
    test('should have all required fields', () {
      expect(TaskCreateFields.all.length, 6);
      expect(TaskCreateFields.all.any((f) => f.key == 'description'), isTrue);
      expect(TaskCreateFields.all.any((f) => f.key == 'rewardPoints'), isTrue);
      expect(TaskCreateFields.all.any((f) => f.key == 'date'), isTrue);
      expect(TaskCreateFields.all.any((f) => f.key == 'recurrence'), isTrue);
      expect(TaskCreateFields.all.any((f) => f.key == 'priority'), isTrue);
      expect(TaskCreateFields.all.any((f) => f.key == 'isWord'), isTrue);
    });

    test('description field should have correct properties', () {
      expect(TaskCreateFields.description.key, 'description');
      expect(TaskCreateFields.description.label, '任务描述');
      expect(TaskCreateFields.description.defaultEnabled, true);
    });

    test('rewardPoints field should have correct properties', () {
      expect(TaskCreateFields.rewardPoints.key, 'rewardPoints');
      expect(TaskCreateFields.rewardPoints.label, '积分奖励');
      expect(TaskCreateFields.rewardPoints.defaultEnabled, true);
    });

    test('isWord field should have defaultEnabled false', () {
      expect(TaskCreateFields.isWord.defaultEnabled, false);
    });
  });

  group('SettingsProvider', () {
    test('should have correct initial values', () {
      final provider = SettingsProvider();

      expect(provider.themeMode, ThemeMode.light);
      expect(provider.taskViewMode, TaskViewMode.simple);
      expect(provider.taskCreateMode, TaskCreateMode.full);
      expect(provider.taskEditMode, TaskEditMode.full);
      expect(provider.allowEditPastTasks, false);
      expect(provider.allowCompletePastTasks, false);
      expect(provider.rememberFilters, true);
    });

    test('isDark should return correct value', () {
      final provider = SettingsProvider();

      expect(provider.isDark, false);
    });

    test('isRichView should return correct value', () {
      final provider = SettingsProvider();

      expect(provider.isRichView, false);
    });

    test('enabledCreateFields should be empty initially', () {
      final provider = SettingsProvider();

      expect(provider.enabledCreateFields, isEmpty);
    });

    test('enabledEditFields should be empty initially', () {
      final provider = SettingsProvider();

      expect(provider.enabledEditFields, isEmpty);
    });

    test('profilePinnedSettings should be empty initially', () {
      final provider = SettingsProvider();

      expect(provider.profilePinnedSettings, isEmpty);
    });

    test('settingsPinnedSettings should be empty initially', () {
      final provider = SettingsProvider();

      expect(provider.settingsPinnedSettings, isEmpty);
    });

    test('isFieldEnabled should return false for unknown field', () {
      final provider = SettingsProvider();

      expect(provider.isFieldEnabled('unknown'), false);
    });

    test('isEditFieldEnabled should return false for unknown field', () {
      final provider = SettingsProvider();

      expect(provider.isEditFieldEnabled('unknown'), false);
    });

    test('availablePinnedSettings should contain expected keys', () {
      expect(
        SettingsProvider.availablePinnedSettings.containsKey('themeMode'),
        isTrue,
      );
      expect(
        SettingsProvider.availablePinnedSettings.containsKey('taskViewMode'),
        isTrue,
      );
      expect(
        SettingsProvider.availablePinnedSettings.containsKey('taskCreateMode'),
        isTrue,
      );
    });

    test('maxPinnedSettings should be 6', () {
      expect(SettingsProvider.maxPinnedSettings, 6);
    });
  });

  group('SettingsProvider.initialize 解析持久化键', () {
    Future<SettingsProvider> loaded(Map<String, String> raw) async {
      final db = await DatabaseService.instance.database;
      await db.delete('settings');
      await DatabaseService.instance.saveSettings(raw);
      final p = SettingsProvider();
      await p.initialize();
      return p;
    }
    test('缺失键回落默认值', () async {
      final p = await loaded({});
      const defaultFields = {
        'description',
        'rewardPoints',
        'date',
        'recurrence',
        'priority',
      };
      expect(p.themeMode, ThemeMode.light);
      expect(p.taskViewMode, TaskViewMode.simple); // 缺失键保留字段默认值
      expect(p.taskCreateMode, TaskCreateMode.full);
      expect(p.taskEditMode, TaskEditMode.full);
      expect(p.taskSortOption, TaskSortOption.defaultOrder);
      expect(p.enabledCreateFields, defaultFields);
      expect(p.enabledEditFields, defaultFields);
      expect(p.allowEditPastTasks, isFalse);
      expect(p.allowCompletePastTasks, isFalse);
      expect(p.rememberFilters, isTrue);
      expect(p.lastPriorityFilter, isNull);
      expect(p.lastCompletionFilter, isNull);
      expect(p.lastRecurrenceFilter, isNull);
      expect(p.lastTagFilterId, isNull);
      expect(p.profilePinnedSettings, isEmpty);
      expect(p.settingsPinnedSettings, isEmpty);
    });
    test('解析枚举/布尔/排序键', () async {
      final p = await loaded({
        'themeMode': 'dark',
        'taskViewMode': 'simple',
        'taskCreateMode': 'minimal',
        'taskEditMode': 'custom',
        'taskSortOption': 'priority',
        'allowEditPastTasks': 'true',
        'allowCompletePastTasks': 'true',
        'rememberFilters': 'false',
      });
      expect(p.themeMode, ThemeMode.dark);
      expect(p.taskViewMode, TaskViewMode.simple);
      expect(p.taskCreateMode, TaskCreateMode.minimal);
      expect(p.taskEditMode, TaskEditMode.custom);
      expect(p.taskSortOption, TaskSortOption.priority);
      expect(p.allowEditPastTasks, isTrue);
      expect(p.allowCompletePastTasks, isTrue);
      expect(p.rememberFilters, isFalse);
      final bogus = await loaded({'taskSortOption': 'bogus'});
      expect(bogus.taskSortOption, TaskSortOption.defaultOrder);
    });
    test('解析自定义字段与筛选键', () async {
      final p = await loaded({
        'taskCreateMode': 'custom',
        'taskEditMode': 'custom',
        'enabledCreateFields': 'description,date',
        'enabledEditFields': 'isWord',
        'lastPriorityFilter': 'red',
        'lastCompletionFilter': 'false',
        'lastRecurrenceFilter': 'true',
        'lastTagFilterId': '42',
      });
      expect(p.enabledCreateFields, {'description', 'date'});
      expect(p.enabledEditFields, {'isWord'});
      expect(p.lastPriorityFilter, 'red');
      expect(p.lastCompletionFilter, isFalse);
      expect(p.lastRecurrenceFilter, isTrue);
      expect(p.lastTagFilterId, 42);
      final empty = await loaded({
        'lastPriorityFilter': '',
        'lastCompletionFilter': 'maybe',
        'lastRecurrenceFilter': '',
        'lastTagFilterId': 'not-a-number',
      });
      expect(empty.lastPriorityFilter, isNull);
      expect(empty.lastCompletionFilter, isNull);
      expect(empty.lastRecurrenceFilter, isNull);
      expect(empty.lastTagFilterId, isNull);
    });
    test('置顶项过滤未知键', () async {
      final p = await loaded({
        'profilePinnedSettings': 'themeMode,bogus,taskViewMode',
        'settingsPinnedSettings': 'rememberFilters',
      });
      expect(p.profilePinnedSettings, ['themeMode', 'taskViewMode']);
      expect(p.settingsPinnedSettings, ['rememberFilters']);
    });
  });

  group('SettingsProvider 变更方法', () {
    late SettingsProvider p;
    setUp(() async {
      final db = await DatabaseService.instance.database;
      await db.delete('settings');
      p = SettingsProvider();
      await p.initialize();
    });
    test('toggleTheme 切换并落库', () async {
      p.toggleTheme();
      expect(p.themeMode, ThemeMode.dark);
      await expectPersisted('themeMode', 'dark');
      p.toggleTheme();
      expect(p.themeMode, ThemeMode.light);
      await expectPersisted('themeMode', 'light');
    });
    test('视图与排序更新并落库', () async {
      p.setTaskViewMode(TaskViewMode.rich);
      expect(p.isRichView, isTrue);
      p.toggleTaskViewMode();
      expect(p.taskViewMode, TaskViewMode.simple);
      p.setTaskSortOption(TaskSortOption.completionTime);
      expect(p.taskSortOption, TaskSortOption.completionTime);
      await expectPersisted('taskSortOption', 'completionTime');
    });
    test('setTaskCreateMode 重置字段', () async {
      p.setTaskCreateMode(TaskCreateMode.full);
      expect(p.enabledCreateFields.length, 6);
      p.setTaskCreateMode(TaskCreateMode.minimal);
      expect(p.enabledCreateFields, isEmpty);
      p.setTaskCreateMode(TaskCreateMode.custom);
      expect(p.enabledCreateFields, isEmpty);
    });
    test('toggleCreateField 仅 custom 生效', () async {
      p.setTaskCreateMode(TaskCreateMode.minimal);
      p.toggleCreateField('description');
      expect(p.enabledCreateFields, isEmpty);
      p.setTaskCreateMode(TaskCreateMode.custom);
      p.setEnabledCreateFields({'description'});
      p.toggleCreateField('description');
      expect(p.isFieldEnabled('description'), isFalse);
      p.toggleCreateField('date');
      expect(p.enabledCreateFields, {'date'});
    });
    test('编辑模式与字段切换对称', () async {
      p.setTaskEditMode(TaskEditMode.full);
      expect(p.enabledEditFields.length, 6);
      p.setTaskEditMode(TaskEditMode.custom);
      p.toggleEditField('isWord');
      expect(p.isEditFieldEnabled('isWord'), isFalse);
      p.setTaskEditMode(TaskEditMode.minimal);
      p.toggleEditField('description');
      expect(p.enabledEditFields, isEmpty);
      p.setEnabledEditFields({'date'});
      expect(p.enabledEditFields, {'date'});
    });
    test('布尔开关与筛选记忆', () async {
      p.setAllowEditPastTasks(true);
      p.setAllowCompletePastTasks(true);
      p.setRememberFilters(false);
      p.setLastPriorityFilter('red');
      p.setLastCompletionFilter(true);
      p.setLastRecurrenceFilter(false);
      p.setLastTagFilterId(9);
      expect(p.allowEditPastTasks, isTrue);
      expect(p.allowCompletePastTasks, isTrue);
      expect(p.rememberFilters, isFalse);
      expect(p.lastTagFilterId, 9);
      await expectPersisted('allowEditPastTasks', 'true');
      await expectPersisted('allowCompletePastTasks', 'true');
      await expectPersisted('rememberFilters', 'false');
      await expectPersisted('lastPriorityFilter', 'red');
      await expectPersisted('lastCompletionFilter', 'true');
      await expectPersisted('lastRecurrenceFilter', 'false');
      await expectPersisted('lastTagFilterId', '9');
      p.setLastPriorityFilter(null);
      p.clearAllFilters();
      expect(p.lastPriorityFilter, isNull);
      expect(p.lastCompletionFilter, isNull);
      expect(p.lastRecurrenceFilter, isNull);
      expect(p.lastTagFilterId, isNull);
      await expectPersisted('lastPriorityFilter', '');
      await expectPersisted('lastCompletionFilter', '');
      await expectPersisted('lastRecurrenceFilter', '');
      await expectPersisted('lastTagFilterId', '');
    });
  });

  group('SettingsProvider 快捷设置项', () {
    late SettingsProvider p;
    setUp(() async {
      final db = await DatabaseService.instance.database;
      await db.delete('settings');
      p = SettingsProvider();
      await p.initialize();
    });
    test('添加置顶项并落库', () async {
      expect(p.addPinnedSetting('themeMode', PinnedSettingLocation.profile), isTrue);
      expect(p.isPinned('themeMode', PinnedSettingLocation.profile), isTrue);
      expect(p.profilePinnedSettings, ['themeMode']);
      await expectPersisted('profilePinnedSettings', 'themeMode');
    });
    test('重复或未知键不添加', () async {
      p.addPinnedSetting('themeMode', PinnedSettingLocation.profile);
      expect(p.addPinnedSetting('themeMode', PinnedSettingLocation.profile), isFalse);
      expect(p.addPinnedSetting('bogus', PinnedSettingLocation.profile), isFalse);
      expect(p.profilePinnedSettings, ['themeMode']);
    });
    test('最多置顶 maxPinnedSettings 项', () async {
      expect(
        SettingsProvider.availablePinnedSettings.length,
        SettingsProvider.maxPinnedSettings,
      );
      for (final key in SettingsProvider.availablePinnedSettings.keys) {
        expect(p.addPinnedSetting(key, PinnedSettingLocation.settings), isTrue);
      }
      expect(
        p.settingsPinnedSettings.length,
        SettingsProvider.maxPinnedSettings,
      );
    });
    test('两处置顶互不影响', () async {
      p.addPinnedSetting('themeMode', PinnedSettingLocation.profile);
      p.addPinnedSetting('rememberFilters', PinnedSettingLocation.settings);
      expect(p.profilePinnedSettings, ['themeMode']);
      expect(p.settingsPinnedSettings, ['rememberFilters']);
    });
    test('移除与重排置顶项', () async {
      p.addPinnedSetting('themeMode', PinnedSettingLocation.profile);
      p.addPinnedSetting('taskViewMode', PinnedSettingLocation.profile);
      p.reorderPinnedSettings(0, 1, PinnedSettingLocation.profile);
      expect(p.profilePinnedSettings, ['taskViewMode', 'themeMode']);
      // 越界索引应被忽略
      p.reorderPinnedSettings(5, 0, PinnedSettingLocation.profile);
      p.reorderPinnedSettings(-1, 0, PinnedSettingLocation.profile);
      expect(p.profilePinnedSettings, ['taskViewMode', 'themeMode']);
      // 移除不存在项无副作用
      p.removePinnedSetting('taskViewMode', PinnedSettingLocation.profile);
      p.removePinnedSetting('taskViewMode', PinnedSettingLocation.profile);
      expect(p.profilePinnedSettings, ['themeMode']);
    });
    test('resetPinnedSettings 清空单处或全部', () async {
      p.addPinnedSetting('themeMode', PinnedSettingLocation.profile);
      p.addPinnedSetting('rememberFilters', PinnedSettingLocation.settings);
      p.resetPinnedSettings(PinnedSettingLocation.profile);
      expect(p.profilePinnedSettings, isEmpty);
      expect(p.settingsPinnedSettings, ['rememberFilters']);
      p.resetPinnedSettings(null);
      expect(p.settingsPinnedSettings, isEmpty);
    });
  });
}
