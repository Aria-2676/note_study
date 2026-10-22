// v6 扩展位骨架 —— 入口注册。
//
// 插件不直接改动导航结构，只**声明**自己要出现在哪；主包按声明渲染。
// 卸载后入口自动消失，不留空位。

/// 允许插件注册入口的位置白名单。新增必须同步 `docs/plugin-contract.md` §5。
enum EntryWhere {
  /// 左侧半屏抽屉
  sidebar('sidebar'),

  /// 「我的」页
  profile('profile'),

  /// 设置页
  settings('settings');

  const EntryWhere(this.where);

  final String where;
}

class PluginEntry {
  const PluginEntry({
    required this.pluginId,
    required this.where,
    required this.label,
    this.route,
    this.iconName,
    this.order = 100,
  });

  final String pluginId;
  final EntryWhere where;
  final String label;

  /// 主包内的路由名（插件页面由主包统一托管）
  final String? route;

  /// **内置图标名**，不允许插件自带图片，避免风格割裂
  final String? iconName;

  /// 升序排列，越小越靠前
  final int order;
}

class EntryRegistry {
  EntryRegistry._();

  static final EntryRegistry instance = EntryRegistry._();

  final List<PluginEntry> _entries = <PluginEntry>[];

  void registerAll(List<PluginEntry> entries) => _entries.addAll(entries);

  void unregister(String pluginId) {
    _entries.removeWhere((e) => e.pluginId == pluginId);
  }

  /// 某位置下的入口，按 order 升序；同 order 按 label 稳定排序
  List<PluginEntry> entriesFor(EntryWhere where) {
    final list = _entries.where((e) => e.where == where).toList()
      ..sort((a, b) {
        final byOrder = a.order.compareTo(b.order);
        return byOrder != 0 ? byOrder : a.label.compareTo(b.label);
      });
    return list;
  }

  void clear() => _entries.clear();
}
