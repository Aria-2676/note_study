import 'package:flutter/material.dart';

/// 热更主题配置（`hot_assets/theme.json`）。
///
/// 只开放**颜色与形状种子**这类"改一个数就能换皮"的字段，不开放任意 ThemeData
/// 覆写：后者等于把 Flutter 内部结构暴露给外网 JSON，一旦 SDK 升级或字段写错，
/// 整个 App 的外观（甚至可用性）都会崩。这里的原则是
/// **每个字段都可单独丢弃，丢完还能用内置默认值**。
///
/// JSON 形态：
/// ```json
/// {
///   "seedColor": "#6200EE",
///   "brightness": "light",
///   "primary": "#6200EE",
///   "secondary": "#03DAC6",
///   "error": "#F44336",
///   "cardRadius": 12,
///   "useMaterial3": true
/// }
/// ```
/// 全部字段可选；未知字段忽略。
class HotThemeConfig {
  /// 主色种子。Material 3 会由它推导整套色调。
  final Color? seedColor;

  /// 强制亮/暗；null 表示跟随用户设置。
  final Brightness? brightness;

  /// 直接指定主色（优先于 [seedColor] 推导出的值）。
  final Color? primary;

  /// 直接指定次要色。
  final Color? secondary;

  /// 直接指定错误色。
  final Color? error;

  /// 卡片圆角半径；null 表示沿用默认。
  final double? cardRadius;

  /// 是否启用 Material 3。
  ///
  /// **仅解析、不生效**：`ThemeData.useMaterial3` 自 v3.13 起已废弃，Flutter 要求
  /// 由 `ThemeData` 构造器决定。保留该字段只为兼容可能已下发的旧清单，
  /// 避免解析时报「未知字段」；[applyTo] 不会覆写它。
  final bool? useMaterial3;

  const HotThemeConfig({
    this.seedColor,
    this.brightness,
    this.primary,
    this.secondary,
    this.error,
    this.cardRadius,
    this.useMaterial3,
  });

  /// 空配置：等价于「没有热更主题」。
  static const HotThemeConfig empty = HotThemeConfig();

  /// 是否**没有任何会实际生效**的字段。
  ///
  /// 注意 [useMaterial3] **不计入**：它已废弃且 [applyTo] 刻意不覆写它，
  /// 若把它算进来，一份只写了该字段的清单会被当成「有内容」而白白重建 ThemeData。
  bool get isEmpty =>
      seedColor == null &&
      brightness == null &&
      primary == null &&
      secondary == null &&
      error == null &&
      cardRadius == null;

  /// 从 JSON 解析。
  ///
  /// **fail-soft 到底**：根节点类型不对也返回 [empty]，不抛异常。理由是它属于
  /// 「有更好、没有也行」的增强项，不该因为一个云端笔误让 App 起不来。
  static HotThemeConfig fromJson(Object? raw) {
    if (raw is! Map) return empty;

    return HotThemeConfig(
      seedColor: _parseColor(raw['seedColor']),
      brightness: _parseBrightness(raw['brightness']),
      primary: _parseColor(raw['primary']),
      secondary: _parseColor(raw['secondary']),
      error: _parseColor(raw['error']),
      cardRadius: _parseRadius(raw['cardRadius']),
      useMaterial3: raw['useMaterial3'] is bool
          ? raw['useMaterial3'] as bool
          : null,
    );
  }

  /// 以 [base] 为底生成应用后的 [ThemeData]。
  ///
  /// [fallbackBrightness] 是「配置里没写 brightness 时」应当使用的亮度，
  /// 由调用方（跟随系统/用户设置）决定。
  ThemeData applyTo(ThemeData base, {required Brightness fallbackBrightness}) {
    final effectiveBrightness = brightness ?? fallbackBrightness;

    // 有 seedColor 就走「种子推导」，这是 Material 3 推荐路径；否则用
    // colorScheme 的 copyWith 做定点覆写。两条路都不改 base 的其它设置，
    // 保证热更主题只影响颜色，不会意外动到排版与组件默认尺寸。
    var scheme = base.colorScheme;
    if (seedColor != null) {
      scheme = ColorScheme.fromSeed(
        seedColor: seedColor!,
        brightness: effectiveBrightness,
      );
    } else if (scheme.brightness != effectiveBrightness) {
      scheme = scheme.copyWith(brightness: effectiveBrightness);
    }

    scheme = scheme.copyWith(
      primary: primary ?? scheme.primary,
      secondary: secondary ?? scheme.secondary,
      error: error ?? scheme.error,
    );

    final radius = cardRadius;
    // 刻意**不覆写 useMaterial3**：该参数已废弃（v3.13 起），Flutter 建议由
    // ThemeData 构造器决定 Material 版本。热更主题是「换皮」而不是「换设计语言」，
    // 跟着宿主走即可；配置里保留该字段只为兼容旧清单，解析出来但不生效。
    return base.copyWith(
      colorScheme: scheme,
      cardTheme: radius == null
          ? base.cardTheme
          : base.cardTheme.copyWith(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(radius),
              ),
            ),
    );
  }

  /// 解析 `#RRGGBB` / `#AARRGGBB`；非法时返回 null（丢弃该字段）。
  static Color? _parseColor(Object? raw) {
    if (raw is! String) return null;
    final hex = raw.trim().replaceFirst('#', '');
    if (hex.length != 6 && hex.length != 8) return null;
    final parsed = int.tryParse(hex, radix: 16);
    if (parsed == null) return null;
    return Color(hex.length == 6 ? 0xFF000000 | parsed : parsed);
  }

  /// 解析 `light` / `dark`（大小写不敏感）；其它值返回 null。
  static Brightness? _parseBrightness(Object? raw) {
    switch (raw?.toString().trim().toLowerCase()) {
      case 'light':
        return Brightness.light;
      case 'dark':
        return Brightness.dark;
      default:
        return null;
    }
  }

  /// 解析圆角半径：必须是 0~64 的有限数，否则丢弃。
  ///
  /// 上限是为了防手滑写成 `9999` 把卡片变成圆球；类型上接受 [num] 是因为
  /// JSON 里 `12` 是 int、`12.5` 是 double，两者都该能用。
  static double? _parseRadius(Object? raw) {
    if (raw is! num) return null;
    final value = raw.toDouble();
    if (!value.isFinite || value < 0 || value > 64) return null;
    return value;
  }
}
