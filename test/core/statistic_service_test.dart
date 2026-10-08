import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:v5_app/core/models/statistic_data.dart';
import 'package:v5_app/core/services/statistic_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final service = StatisticService();
  const cacheKey = 'statistic_cache';

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await StatisticService.init();
  });

  setUp(() async {
    await service.clearCache();
  });

  group('StatisticService', () {
    test('should start with an empty cache', () async {
      expect(await service.getCacheCount(), 0);
    });

    test('report should cache the reported data', () async {
      await service.report(
        StatisticData(
          key: StatisticKeys.countTaskCompleted,
          type: StatisticType.count,
          value: 1,
        ),
      );

      expect(await service.getCacheCount(), 1);

      final prefs = await SharedPreferences.getInstance();
      final cache = jsonDecode(prefs.getString(cacheKey)!) as List;
      final entry = cache.single as Map<String, dynamic>;

      expect(entry['key'], StatisticKeys.countTaskCompleted);
      expect(entry['type'], 'count');
      expect(entry['value'], '1');
      expect(entry['time'], isNotNull);
    });

    test('report should keep a Map value as a nested map', () async {
      await service.report(
        StatisticData(
          key: StatisticKeys.clickShopExchange,
          type: StatisticType.click,
          value: {'itemId': 1, 'name': '休息15分钟'},
        ),
      );

      final prefs = await SharedPreferences.getInstance();
      final cache = jsonDecode(prefs.getString(cacheKey)!) as List;
      final entry = cache.single as Map<String, dynamic>;

      expect(entry['value'], {'itemId': 1, 'name': '休息15分钟'});
    });

    test('reportBatch should cache every item', () async {
      await service.reportBatch([
        StatisticData(key: 'count_a', type: StatisticType.count, value: 1),
        StatisticData(key: 'count_b', type: StatisticType.count, value: 2),
        StatisticData(key: 'count_c', type: StatisticType.count, value: 3),
      ]);

      expect(await service.getCacheCount(), 3);
    });

    test('cache should be capped at 2000 entries', () async {
      final prefs = await SharedPreferences.getInstance();
      final seeded = List.generate(
        2000,
        (i) => {
          'key': 'count_seed_$i',
          'type': 'count',
          'value': '$i',
          'time': '2024-01-01T00:00:00.000Z',
        },
      );
      await prefs.setString(cacheKey, jsonEncode(seeded));

      await service.report(
        StatisticData(key: 'count_new', type: StatisticType.count, value: 999),
      );

      // 超过上限后应裁剪回 2000 条
      expect(await service.getCacheCount(), 2000);

      final cache = jsonDecode(prefs.getString(cacheKey)!) as List;
      // 最早的记录被淘汰，最新写入的保留
      expect((cache.first as Map)['key'], 'count_seed_1');
      expect((cache.last as Map)['key'], 'count_new');
    });

    test('clearCache should empty the cache', () async {
      await service.report(
        StatisticData(key: 'count_a', type: StatisticType.count, value: 1),
      );
      expect(await service.getCacheCount(), 1);

      await service.clearCache();

      expect(await service.getCacheCount(), 0);
    });
  });
}