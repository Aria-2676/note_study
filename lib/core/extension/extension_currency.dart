// v6 扩展位骨架 —— 货币框架。
//
// 关键设计（docs/main-package.md §4）：
//   **框架在主包，实现全在插件。** 主包不知道有"能量"或"积分"，
//   只知道"有个货币实现被注册了、当前生效的是它"。
// 因此本文件**不含任何具体货币**，也不碰任何数据库表。

/// 一笔货币流水。由各货币实现自行持久化，主包只消费这个视图。
class CurrencyRecord {
  const CurrencyRecord({
    required this.delta,
    required this.reason,
    required this.at,
    required this.source,
  });

  /// 正数为入账，负数为出账
  final int delta;

  /// 人类可读的原因（「完成任务：写完这节」「看了一集剧」）
  final String reason;

  final DateTime at;

  /// 来源分类：natural / task / shop / ledger / manual
  final String source;
}

/// 一种货币的实现契约。能量、积分各实现一份，装在两个插件里。
abstract class CurrencyDefinition {
  /// 唯一 id，小写（'energy' / 'points'）
  String get id;

  /// 展示名
  String get displayName;

  /// 仅用于"装了两套时推荐哪一个"，**不触发自动切换**
  int get priority;

  Future<int> balance();

  Future<void> earn(
    int amount, {
    required String reason,
    String source = 'manual',
  });

  /// 余额不足时返回 false，且**不得产生任何写入**（含流水）
  Future<bool> spend(
    int amount, {
    required String reason,
    String source = 'manual',
  });

  Future<List<CurrencyRecord>> records({int limit = 50});
}

/// 货币注册表。
class CurrencyRegistry {
  CurrencyRegistry._();

  static final CurrencyRegistry instance = CurrencyRegistry._();

  final Map<String, CurrencyDefinition> _installed = <String, CurrencyDefinition>{};

  String? _activeId;

  void register(CurrencyDefinition definition) {
    _installed[definition.id] = definition;
  }

  /// 卸载货币插件。**若卸载的正是当前生效货币，active 置空**
  /// （不做自动回落到另一套，避免用户不知道钱怎么换了）。
  void unregister(String id) {
    _installed.remove(id);
    if (_activeId == id) _activeId = null;
  }

  /// 已安装的货币，按 priority 降序（仅作展示顺序/推荐用）
  List<CurrencyDefinition> get installed {
    final list = _installed.values.toList()
      ..sort((a, b) => b.priority.compareTo(a.priority));
    return list;
  }

  bool isInstalled(String id) => _installed.containsKey(id);

  String? get activeId => _activeId;

  CurrencyDefinition? get active => _activeId == null ? null : _installed[_activeId];

  /// 显式切换。传 null 表示"不使用货币"（等同整块关闭）。
  /// 传未安装的 id 直接忽略，返回 false。
  bool setActive(String? id) {
    if (id == null) {
      _activeId = null;
      return true;
    }
    if (!_installed.containsKey(id)) return false;
    _activeId = id;
    return true;
  }

  void clear() {
    _installed.clear();
    _activeId = null;
  }
}
