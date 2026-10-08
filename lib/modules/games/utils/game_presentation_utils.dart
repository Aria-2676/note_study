import 'package:flutter/material.dart';

/// 清单字段到 UI 呈现的映射。
///
/// 图标刻意用白名单映射而非动态 `IconData`：Flutter 的图标 tree-shaking 会
/// 移除构建时未静态引用的字形，动态构造会在 release 下渲染成空白。
class GamePresentationUtils {
  const GamePresentationUtils._();

  static const IconData _fallbackIcon = Icons.videogame_asset;

  static const Map<String, IconData> _icons = {
    'grid_on': Icons.grid_on,
    'casino': Icons.casino,
    'extension': Icons.extension,
    'sports_esports': Icons.sports_esports,
    'psychology': Icons.psychology,
    'apps': Icons.apps,
    'memory': Icons.memory,
    'numbers': Icons.numbers,
    'palette': Icons.palette,
    'music_note': Icons.music_note,
  };

  /// 按名称取图标；未知名称回退到通用游戏图标。
  static IconData iconFor(String name) => _icons[name] ?? _fallbackIcon;

  /// 解析 `#RRGGBB` 或 `#AARRGGBB` 形式的颜色；非法时回退到紫色。
  static Color colorFor(String value) {
    final hex = value.trim().replaceFirst('#', '');
    if (hex.length != 6 && hex.length != 8) return const Color(0xFF9C27B0);
    final parsed = int.tryParse(hex, radix: 16);
    if (parsed == null) return const Color(0xFF9C27B0);
    return Color(hex.length == 6 ? 0xFF000000 | parsed : parsed);
  }

  /// 体积展示：把字节数格式化为 B / KB / MB。
  static String formatSize(int bytes) {
    if (bytes <= 0) return '未知';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}