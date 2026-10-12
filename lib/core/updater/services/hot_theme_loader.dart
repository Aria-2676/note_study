import 'package:flutter/material.dart';

import '../../utils/app_logger.dart';
import '../models/hot_theme_config.dart';
import 'hot_asset_store.dart';

/// 热更主题的加载器。
///
/// 与 [HotAssetStore] 分开是因为职责不同：store 只管「按路径取文件」，
/// 本类负责「取 theme.json → 解析 → 落到 ThemeData」这条链路，并处理加载时机。
///
/// 读取时机刻意放在**启动时一次**：主题变了需要整树重建，运行中热换会造成
/// 明显闪烁，而主题变更本身是低频操作（用户在设置页改了才生效），
/// 重启一次完全可以接受。
class HotThemeLoader {
  const HotThemeLoader._();

  /// 热更主题文件的相对路径。
  static const String assetPath = 'theme.json';

  /// 读取热更主题配置；没有该文件或解析失败时返回 [HotThemeConfig.empty]。
  ///
  /// 全程不抛异常——主题是增强项，取不到就用内置默认值。
  static Future<HotThemeConfig> load() async {
    try {
      final raw = await HotAssetStore.instance.readAsJson(assetPath);
      if (raw == null) return HotThemeConfig.empty;
      final config = HotThemeConfig.fromJson(raw);
      if (config.isEmpty) {
        AppLogger.warn('HotThemeLoader', 'theme.json 未解析出任何有效字段，沿用内置主题');
        return HotThemeConfig.empty;
      }
      return config;
    } catch (error, stack) {
      AppLogger.warn('HotThemeLoader', '读取热更主题失败，沿用内置主题', error, stack);
      return HotThemeConfig.empty;
    }
  }

  /// 把热更主题叠加到内置主题上。
  ///
  /// [fallbackBrightness] 由调用方按用户设置给出（当前 App 只有亮/暗两档）。
  static ThemeData apply(
    ThemeData base,
    HotThemeConfig config, {
    required Brightness fallbackBrightness,
  }) {
    if (config.isEmpty) return base;
    return config.applyTo(base, fallbackBrightness: fallbackBrightness);
  }
}
