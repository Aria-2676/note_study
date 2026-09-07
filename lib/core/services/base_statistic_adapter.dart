import 'package:flutter/material.dart';
import 'statistic_service.dart';
import '../models/statistic_data.dart';

abstract class BaseStatisticAdapter {
  StatisticService get service;

  Future<void> _safeReport(
    StatisticData data, {
    String? moduleName,
  }) async {
    try {
      await service.report(data);
    } catch (e, stack) {
      final prefix = moduleName != null ? '$moduleName: ' : '';
      debugPrint('${prefix}Statistic report failed: $e\n$stack');
    }
  }

  Future<void> reportPageView(
    String key, {
    String? moduleName,
  }) async {
    await _safeReport(
      StatisticData(
        key: key,
        type: StatisticType.pageView,
        value: DateTime.now().toUtc().toIso8601String(),
      ),
      moduleName: moduleName,
    );
  }

  Future<void> reportClick(
    String key, {
    Map<String, dynamic>? value,
    String? moduleName,
  }) async {
    await _safeReport(
      StatisticData(
        key: key,
        type: StatisticType.click,
        value: value ?? DateTime.now().toUtc().toIso8601String(),
      ),
      moduleName: moduleName,
    );
  }

  Future<void> reportCount(
    String key, {
    dynamic value,
    String? moduleName,
  }) async {
    await _safeReport(
      StatisticData(
        key: key,
        type: StatisticType.count,
        value: value,
      ),
      moduleName: moduleName,
    );
  }
}