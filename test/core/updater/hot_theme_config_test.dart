import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:v5_app/core/updater/models/hot_theme_config.dart';

void main() {
  group('HotThemeConfig 解析', () {
    test('完整配置应全部解析出来', () {
      final config = HotThemeConfig.fromJson({
        'seedColor': '#6200EE',
        'brightness': 'dark',
        'primary': '#112233',
        'secondary': '#445566',
        'error': '#778899',
        'cardRadius': 16,
        'useMaterial3': false,
      });

      expect(config.seedColor, const Color(0xFF6200EE));
      expect(config.brightness, Brightness.dark);
      expect(config.primary, const Color(0xFF112233));
      expect(config.secondary, const Color(0xFF445566));
      expect(config.error, const Color(0xFF778899));
      expect(config.cardRadius, 16);
      expect(config.useMaterial3, isFalse, reason: '字段仍可解析，但不参与 applyTo');
      expect(config.isEmpty, isFalse);
    });

    test('支持 #AARRGGBB 八位色值', () {
      final config = HotThemeConfig.fromJson({'primary': '#80112233'});

      expect(config.primary, const Color(0x80112233));
    });

    test('brightness 大小写不敏感', () {
      expect(
        HotThemeConfig.fromJson({'brightness': 'DARK'}).brightness,
        Brightness.dark,
      );
      expect(
        HotThemeConfig.fromJson({'brightness': ' light '}).brightness,
        Brightness.light,
      );
    });

    test('根节点不是对象时返回空配置而不是抛异常', () {
      expect(HotThemeConfig.fromJson(null).isEmpty, isTrue);
      expect(HotThemeConfig.fromJson('oops').isEmpty, isTrue);
      expect(HotThemeConfig.fromJson([1, 2]).isEmpty, isTrue);
    });

    test('单个字段非法只丢该字段，其余照常生效', () {
      final config = HotThemeConfig.fromJson({
        'seedColor': 'not-a-color', // 非法
        'primary': '#123456', // 合法
        'brightness': 'purple', // 非法
        'cardRadius': -5, // 非法（负数）
      });

      expect(config.seedColor, isNull);
      expect(config.brightness, isNull);
      expect(config.cardRadius, isNull);
      expect(config.primary, const Color(0xFF123456), reason: '合法字段不受牵连');
      expect(config.isEmpty, isFalse);
    });

    test('圆角超出上限被丢弃', () {
      expect(HotThemeConfig.fromJson({'cardRadius': 9999}).cardRadius, isNull);
      expect(HotThemeConfig.fromJson({'cardRadius': 64}).cardRadius, 64);
      expect(HotThemeConfig.fromJson({'cardRadius': 0}).cardRadius, 0);
    });

    test('空对象解析出 isEmpty', () {
      expect(HotThemeConfig.fromJson({}).isEmpty, isTrue);
    });

    test('只写了 useMaterial3 也视为空配置（该字段不生效）', () {
      final config = HotThemeConfig.fromJson({'useMaterial3': false});

      expect(config.useMaterial3, isFalse);
      expect(config.isEmpty, isTrue, reason: '不该为不生效的字段重建 ThemeData');
    });
  });

  group('HotThemeConfig 应用', () {
    // 注意：「空配置不重建 ThemeData」这条约束**不在** applyTo 上——
    // ThemeData.copyWith 无条件新建实例（永远不 `return this`），所以
    // applyTo 无论配置是否为空都会产出新对象，这是 Flutter 的既定行为。
    // 真正做短路的是上一层 HotThemeLoader.apply（isEmpty 时直接 `return base`）。

    test('空配置下 applyTo 仍等价于原主题（不改变任何可观察属性）', () {
      final base = ThemeData.light(useMaterial3: true);

      final applied = HotThemeConfig.empty.applyTo(
        base,
        fallbackBrightness: Brightness.light,
      );

      // 不做 identical 断言：copyWith 必然新建实例。这里断言的是
      // 「等价」——颜色方案与圆角都没被动过。
      expect(applied.colorScheme.primary, base.colorScheme.primary);
      expect(applied.colorScheme.brightness, base.colorScheme.brightness);
      expect(applied.cardTheme.shape, base.cardTheme.shape);
    });

    test('空配置 + 不同 fallback 仍会把亮度对齐到 fallback', () {
      // 这不是缺陷，而是 applyTo 的既定语义：它是「已经被决定要应用」之后的
      // 执行体，不做 isEmpty 判断。isEmpty 的短路在 HotThemeLoader.apply 层。
      // 这条用例把该语义固定下来，防止有人日后误以为 applyTo 会自行短路。
      final base = ThemeData.light(useMaterial3: true);

      final applied = HotThemeConfig.empty.applyTo(
        base,
        fallbackBrightness: Brightness.dark,
      );

      expect(applied.colorScheme.brightness, Brightness.dark);
    });

    test('seedColor 会推导出主色，且亮度正确', () {
      final config = HotThemeConfig.fromJson({'seedColor': '#6200EE'});
      final base = ThemeData.light(useMaterial3: true);

      final applied = config.applyTo(
        base,
        fallbackBrightness: Brightness.light,
      );

      expect(applied.brightness, Brightness.light);
      expect(applied.colorScheme.primary, isNot(base.colorScheme.primary));
    });

    test('primary 定点覆写优先于 seedColor 推导', () {
      final config = HotThemeConfig.fromJson({
        'seedColor': '#6200EE',
        'primary': '#FF0000',
      });

      final applied = config.applyTo(
        ThemeData.light(useMaterial3: true),
        fallbackBrightness: Brightness.light,
      );

      expect(applied.colorScheme.primary, const Color(0xFFFF0000));
    });

    test('未指定 brightness 时跟随 fallback', () {
      final config = HotThemeConfig.fromJson({'primary': '#123456'});
      final base = ThemeData.dark(useMaterial3: true);

      final applied = config.applyTo(base, fallbackBrightness: Brightness.dark);

      expect(applied.brightness, Brightness.dark);
    });

    test('cardRadius 会改到 CardTheme 上', () {
      final config = HotThemeConfig.fromJson({'cardRadius': 4});

      final applied = config.applyTo(
        ThemeData.light(useMaterial3: true),
        fallbackBrightness: Brightness.light,
      );

      final shape = applied.cardTheme.shape;
      expect(shape, isA<RoundedRectangleBorder>());
      expect(
        (shape! as RoundedRectangleBorder).borderRadius,
        BorderRadius.circular(4),
      );
    });

    test('useMaterial3 不覆写宿主设置（该参数已废弃）', () {
      final base = ThemeData.light(useMaterial3: true);
      final config = HotThemeConfig.fromJson({
        'primary': '#123456',
        'useMaterial3': false,
      });

      final applied = config.applyTo(
        base,
        fallbackBrightness: Brightness.light,
      );

      expect(applied.useMaterial3, isTrue, reason: '跟随宿主，不被清单改动');
    });

    test('未指定 cardRadius 时不动 host 的 CardTheme', () {
      final base = ThemeData.light(useMaterial3: true);
      final config = HotThemeConfig.fromJson({'primary': '#123456'});

      final applied = config.applyTo(
        base,
        fallbackBrightness: Brightness.light,
      );

      expect(applied.cardTheme, base.cardTheme);
    });
  });
}
