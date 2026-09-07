import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:v5_app/providers/settings_provider.dart';

void main() {
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
}
