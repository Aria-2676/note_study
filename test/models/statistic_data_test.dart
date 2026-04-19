import 'package:flutter_test/flutter_test.dart';
import 'package:v5_app/core/models/statistic_data.dart';

void main() {
  group('StatisticData', () {
    test('should create StatisticData with correct properties', () {
      final data = StatisticData(
        key: 'test_key',
        type: StatisticType.click,
        value: {'count': 1},
      );

      expect(data.key, 'test_key');
      expect(data.type, StatisticType.click);
      expect(data.value, {'count': 1});
    });

    test('should set time to current UTC time by default', () {
      final before = DateTime.now().toUtc();
      final data = StatisticData(
        key: 'test_key',
        type: StatisticType.pageView,
        value: 'test',
      );
      final after = DateTime.now().toUtc();

      expect(data.time.isAfter(before.subtract(const Duration(seconds: 1))), true);
      expect(data.time.isBefore(after.add(const Duration(seconds: 1))), true);
    });

    test('should accept custom time', () {
      final customTime = DateTime(2024, 1, 1, 12, 0);
      final data = StatisticData(
        key: 'test_key',
        type: StatisticType.pageView,
        value: 'test',
        time: customTime,
      );

      expect(data.time, customTime);
    });

    test('should convert to Map correctly', () {
      final data = StatisticData(
        key: 'test_key',
        type: StatisticType.click,
        value: {'action': 'tap'},
        time: DateTime(2024, 1, 1, 12, 0),
      );

      final map = data.toMap();

      expect(map['key'], 'test_key');
      expect(map['type'], 'click');
      expect(map['value'], {'action': 'tap'});
      expect(map['time'], '2024-01-01T12:00:00.000');
    });

    test('should convert int value to string in Map', () {
      final data = StatisticData(
        key: 'test_key',
        type: StatisticType.count,
        value: 42,
      );

      final map = data.toMap();
      expect(map['value'], '42');
    });

    test('should create from Map correctly', () {
      final map = {
        'key': 'test_key',
        'type': 'count',
        'value': '100',
        'time': '2024-01-01T12:00:00.000Z',
      };

      final data = StatisticData.fromMap(map);

      expect(data.key, 'test_key');
      expect(data.type, StatisticType.count);
      expect(data.value, '100');
    });

    test('should default to system type for unknown type', () {
      final map = {
        'key': 'test_key',
        'type': 'unknown_type',
        'value': 'test',
        'time': '2024-01-01T12:00:00.000Z',
      };

      final data = StatisticData.fromMap(map);
      expect(data.type, StatisticType.system);
    });
  });

  group('StatisticType', () {
    test('should have all required types', () {
      expect(StatisticType.values, contains(StatisticType.pageView));
      expect(StatisticType.values, contains(StatisticType.click));
      expect(StatisticType.values, contains(StatisticType.count));
      expect(StatisticType.values, contains(StatisticType.system));
    });
  });

  group('StatisticKeys', () {
    group('Task module', () {
      test('should have correct page view key', () {
        expect(StatisticKeys.pageViewTaskHome, 'page_view_task_home');
      });

      test('should have correct click keys', () {
        expect(StatisticKeys.clickTaskComplete, 'click_task_complete');
        expect(StatisticKeys.clickTaskCreate, 'click_task_create');
        expect(StatisticKeys.clickTaskDelete, 'click_task_delete');
      });

      test('should have correct count key', () {
        expect(StatisticKeys.countTaskCompleted, 'count_task_completed');
      });
    });

    group('Shop module', () {
      test('should have correct page view keys', () {
        expect(StatisticKeys.pageViewShopHome, 'page_view_shop_home');
        expect(StatisticKeys.pageViewShopWarehouse, 'page_view_shop_warehouse');
      });

      test('should have correct click key', () {
        expect(StatisticKeys.clickShopExchange, 'click_shop_exchange');
      });
    });

    group('Points module', () {
      test('should have correct page view key', () {
        expect(StatisticKeys.pageViewPointsHome, 'page_view_points_home');
      });

      test('should have correct count keys', () {
        expect(StatisticKeys.countPointsIncrease, 'count_points_increase');
        expect(StatisticKeys.countPointsDecrease, 'count_points_decrease');
      });
    });

    group('Tag module', () {
      test('should have correct page view key', () {
        expect(StatisticKeys.pageViewTagManagement, 'page_view_tag_management');
      });

      test('should have correct click keys', () {
        expect(StatisticKeys.clickTagCreate, 'click_tag_create');
        expect(StatisticKeys.clickTagDelete, 'click_tag_delete');
      });
    });

    group('Profile module', () {
      test('should have correct page view key', () {
        expect(StatisticKeys.pageViewSettings, 'page_view_settings');
      });

      test('should have correct click key', () {
        expect(StatisticKeys.clickDataExport, 'click_data_export');
      });
    });

    group('Pomodoro module', () {
      test('should have correct page view keys', () {
        expect(StatisticKeys.pageViewPomodoroHome, 'page_view_pomodoro_home');
        expect(StatisticKeys.pageViewPomodoroHistory, 'page_view_pomodoro_history');
      });

      test('should have correct click keys', () {
        expect(StatisticKeys.clickPomodoroStart, 'click_pomodoro_start');
        expect(StatisticKeys.clickPomodoroPause, 'click_pomodoro_pause');
        expect(StatisticKeys.clickPomodoroReset, 'click_pomodoro_reset');
        expect(StatisticKeys.clickPomodoroSettings, 'click_pomodoro_settings');
      });

      test('should have correct count keys', () {
        expect(StatisticKeys.countPomodoroCompleted, 'count_pomodoro_completed');
        expect(StatisticKeys.countPomodoroFocusMinutes, 'count_pomodoro_focus_minutes');
      });
    });

    group('Scratch module', () {
      test('should have correct page view keys', () {
        expect(StatisticKeys.pageViewScratchHome, 'page_view_scratch_home');
        expect(StatisticKeys.pageViewScratchWallet, 'page_view_scratch_wallet');
        expect(StatisticKeys.pageViewScratchRecords, 'page_view_scratch_records');
      });

      test('should have correct click keys', () {
        expect(StatisticKeys.clickScratchBuyTicket, 'click_scratch_buy_ticket');
        expect(StatisticKeys.clickScratchStart, 'click_scratch_start');
      });

      test('should have correct count keys', () {
        expect(StatisticKeys.countScratchWin, 'count_scratch_win');
        expect(StatisticKeys.countScratchCost, 'count_scratch_cost');
      });
    });

    group('System', () {
      test('should have correct system keys', () {
        expect(StatisticKeys.systemAppCrash, 'system_app_crash');
        expect(StatisticKeys.systemInitFail, 'system_init_fail');
        expect(StatisticKeys.systemStatisticFail, 'system_statistic_fail');
      });
    });
  });
}
