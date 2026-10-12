import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:v5_app/core/updater/models/hot_theme_config.dart';
import 'package:v5_app/core/updater/services/hot_theme_loader.dart';

/// 覆盖 [HotThemeLoader.apply] 的分支决策。
///
/// **只测 apply，不测 load**：`load()` 依赖 `HotAssetStore` 去查盘，
/// 那条链路由 `hot_asset_store_test.dart` 覆盖；这里刻意只锁定「拿到配置之后
/// 怎么落到 ThemeData」这一段纯逻辑，避免两处测试互相纠缠。
void main() {
  group('HotThemeLoader.apply', () {
    test('空配置时原样返回 base，同一个实例', () {
      final base = ThemeData.light(useMaterial3: true);

      final applied = HotThemeLoader.apply(
        base,
        HotThemeConfig.empty,
        fallbackBrightness: Brightness.light,
      );

      // 这是「空配置不无谓重建 ThemeData」这条约束的真正落点：
      // applyTo 做不到（copyWith 必然新建实例），短路必须在这一层完成。
      expect(identical(applied, base), isTrue, reason: '空配置不该重建 ThemeData');
    });

    test('非空配置时返回新实例且有实际改动', () {
      final base = ThemeData.light(useMaterial3: true);
      final config = HotThemeConfig.fromJson({'seedColor': '#6200EE'});

      final applied = HotThemeLoader.apply(
        base,
        config,
        fallbackBrightness: Brightness.light,
      );

      expect(identical(applied, base), isFalse);
      expect(applied.colorScheme.primary, isNot(base.colorScheme.primary));
    });

    test('只含 useMaterial3 的配置等同空配置（走短路）', () {
      final base = ThemeData.light(useMaterial3: true);
      // 该字段已废弃、applyTo 刻意不覆写，因此 isEmpty 把它排除在外。
      final config = HotThemeConfig.fromJson({'useMaterial3': false});

      final applied = HotThemeLoader.apply(
        base,
        config,
        fallbackBrightness: Brightness.light,
      );

      expect(config.isEmpty, isTrue);
      expect(identical(applied, base), isTrue);
    });

    test('fallbackBrightness 透传给 applyTo', () {
      final base = ThemeData.light(useMaterial3: true);
      final config = HotThemeConfig.fromJson({'seedColor': '#6200EE'});

      final applied = HotThemeLoader.apply(
        base,
        config,
        fallbackBrightness: Brightness.dark,
      );

      // 配置里没写 brightness，应当跟随调用方给出的 dark。
      expect(applied.colorScheme.brightness, Brightness.dark);
    });
  });
}
