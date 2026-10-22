import 'plugin_manifest.dart';

/// 索引里的一项：一句话描述 + 从哪儿下。
///
/// 索引**不含** manifest 全文 —— 安装后才以包内 `plugin.json` 为准。
/// 这样可以避免"索引说 1.0、包里是 2.0"这种不一致。
class PluginIndexEntry {
  const PluginIndexEntry({
    required this.id,
    required this.name,
    required this.version,
    required this.contract,
    required this.package,
    this.description,
    this.icon,
  });

  factory PluginIndexEntry.fromJson(Map<String, Object?> json) {
    final id = json['id'];
    final name = json['name'];
    final version = json['version'];
    final contract = json['contract'];

    if (id is! String || !PluginManifest.idPattern.hasMatch(id)) {
      throw PluginFormatException('索引项 id 非法：$id');
    }
    if (name is! String || name.trim().isEmpty) {
      throw const PluginFormatException('索引项 name 不能为空');
    }
    if (version is! String || !PluginManifest.versionPattern.hasMatch(version)) {
      throw PluginFormatException('索引项 version 必须是 x.y.z：$version');
    }
    if (contract is! int) {
      throw const PluginFormatException('索引项 contract 必须是整数');
    }

    final pkg = json['package'];
    if (pkg is! Map) {
      throw PluginFormatException('索引项 $id 缺少 package');
    }

    return PluginIndexEntry(
      id: id,
      name: name.trim(),
      version: version,
      contract: contract,
      description: json['description'] is String ? json['description']! as String : null,
      icon: json['icon'] is String ? json['icon']! as String : null,
      package: PluginPackage.fromJson(Map<String, Object?>.from(pkg)),
    );
  }

  final String id;
  final String name;
  final String version;
  final int contract;
  final String? description;
  final String? icon;
  final PluginPackage package;

  /// 当前宿主能不能装这一项
  bool get installable => PluginContract.accepts(contract);
}

/// `plugins/index.json`。
///
/// 设计原则：**索引是信任根**，但不是权威内容。它决定"有哪些可装"，
/// 装完之后一切以包内 `plugin.json` 为准。
class PluginIndex {
  const PluginIndex({required this.schemaVersion, required this.plugins});

  factory PluginIndex.parse(Map<String, Object?> json) {
    final schema = json['schemaVersion'];
    if (schema is! int) {
      throw const PluginFormatException('索引缺少 schemaVersion');
    }
    if (schema != supportedSchema) {
      throw PluginFormatException(
        '索引 schemaVersion=$schema 不受支持（当前 $supportedSchema）',
      );
    }

    final raw = json['plugins'];
    if (raw is! List) {
      throw const PluginFormatException('索引缺少 plugins 数组');
    }

    final seen = <String>{};
    final entries = <PluginIndexEntry>[];
    for (final item in raw) {
      if (item is! Map) {
        throw const PluginFormatException('plugins 里有一项不是对象');
      }
      final entry = PluginIndexEntry.fromJson(Map<String, Object?>.from(item));
      // 重复 id 会让"装的是哪个"变成不确定的，直接判为坏索引
      if (!seen.add(entry.id)) {
        throw PluginFormatException('索引里 id 重复：${entry.id}');
      }
      entries.add(entry);
    }

    return PluginIndex(schemaVersion: schema, plugins: entries);
  }

  static const int supportedSchema = 1;

  /// 空索引：首版"货架"用它，避免为了一个空列表去联网。
  static const PluginIndex empty = PluginIndex(schemaVersion: supportedSchema, plugins: <PluginIndexEntry>[]);

  final int schemaVersion;
  final List<PluginIndexEntry> plugins;

  PluginIndexEntry? findById(String id) {
    for (final p in plugins) {
      if (p.id == id) return p;
    }
    return null;
  }
}
