import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/statistic_data.dart';

/// 统计上报服务
/// 统一管理所有统计数据的上报、存储和同步
class StatisticService {
  static final StatisticService _instance = StatisticService._internal();
  factory StatisticService() => _instance;
  StatisticService._internal();

  static const String _cacheKey = 'statistic_cache';
  static const int _maxCacheSize = 2000;

  static bool _initialized = false;
  static SharedPreferences? _prefs;

  /// 初始化统计服务
  /// 必须在main.dart中调用
  static Future<void> init() async {
    if (_initialized) return;

    try {
      _prefs = await SharedPreferences.getInstance();
      _initialized = true;
      debugPrint('StatisticService initialized successfully');
    } catch (e, stack) {
      debugPrint('StatisticService init failed: $e\n$stack');
      await _reportInitFail(e.toString(), stack.toString());
    }
  }

  /// 上报统计数据
  /// [data] 统计数据对象
  Future<void> report(StatisticData data) async {
    if (!_initialized) {
      debugPrint('StatisticService not initialized, skipping report');
      return;
    }

    try {
      await _cacheData(data);
      debugPrint('Statistic report: ${data.key} - ${data.type}');
    } catch (e, stack) {
      debugPrint('Statistic report failed: $e\n$stack');
      await _reportStatisticFail(e.toString(), stack.toString());
    }
  }

  /// 批量上报统计数据
  Future<void> reportBatch(List<StatisticData> dataList) async {
    for (final data in dataList) {
      await report(data);
    }
  }

  /// 缓存统计数据到本地
  Future<void> _cacheData(StatisticData data) async {
    if (_prefs == null) return;

    try {
      final cache = await _getCache();
      cache.add(data.toMap());

      if (cache.length > _maxCacheSize) {
        cache.removeRange(0, cache.length - _maxCacheSize);
      }

      await _prefs!.setString(_cacheKey, jsonEncode(cache));
    } catch (e) {
      debugPrint('Cache statistic data failed: $e');
    }
  }

  /// 获取本地缓存的统计数据
  Future<List<Map<String, dynamic>>> _getCache() async {
    if (_prefs == null) return [];

    try {
      final cacheStr = _prefs!.getString(_cacheKey);
      if (cacheStr == null || cacheStr.isEmpty) return [];

      final List<dynamic> cache = jsonDecode(cacheStr);
      return cache.cast<Map<String, dynamic>>();
    } catch (e) {
      debugPrint('Get statistic cache failed: $e');
      return [];
    }
  }

  /// 清空本地缓存
  Future<void> clearCache() async {
    if (_prefs == null) return;
    await _prefs!.remove(_cacheKey);
  }

  /// 获取缓存数量
  Future<int> getCacheCount() async {
    final cache = await _getCache();
    return cache.length;
  }

  /// 上报初始化失败
  static Future<void> _reportInitFail(String error, String stack) async {
    // 初始化失败时无法使用正常上报流程，仅打印日志
    debugPrint('SYSTEM_INIT_FAIL: $error\n$stack');
  }

  /// 上报统计失败
  Future<void> _reportStatisticFail(String error, String stack) async {
    try {
      await report(
        StatisticData(
          key: StatisticKeys.systemStatisticFail,
          type: StatisticType.system,
          value: {'error': error, 'stack': stack},
        ),
      );
    } catch (_) {
      // 避免无限循环
    }
  }
}
