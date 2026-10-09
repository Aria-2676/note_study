import '../utils/game_version_utils.dart';

/// 游戏包的下载与校验信息。
class GamePackageInfo {
  /// 相对仓库根目录的包路径，例如 `game_center/packages/game_2048_v1.0.0.zip`。
  final String path;

  /// 包的 sha256（小写十六进制），用于下载后完整性校验。
  final String sha256;

  /// 包体积（字节），用于展示与下载进度预估。
  final int sizeBytes;

  const GamePackageInfo({
    required this.path,
    required this.sha256,
    required this.sizeBytes,
  });

  /// 从清单 JSON 构造；字段缺失或类型不符时返回 null 由调用方跳过该游戏。
  static GamePackageInfo? tryFromJson(Object? raw) {
    if (raw is! Map) return null;
    final path = raw['path'];
    final sha256 = raw['sha256'];
    final size = raw['sizeBytes'];
    if (path is! String || sha256 is! String) return null;
    final normalized = GamePathUtils.normalizeRelative(path);
    if (normalized == null) return null;
    return GamePackageInfo(
      path: normalized,
      sha256: sha256.toLowerCase(),
      sizeBytes: size is int ? size : 0,
    );
  }

  Map<String, dynamic> toJson() => {
    'path': path,
    'sha256': sha256,
    'sizeBytes': sizeBytes,
  };
}

/// 清单中的单个游戏条目。
class GameInfo {
  /// 游戏唯一标识，用于目录名与积分流水描述。
  final String id;

  /// 展示名称。
  final String name;

  /// 一句话简介。
  final String description;

  /// 图标标识（由 UI 映射为具体图标，避免动态 IconData 破坏 tree-shaking）。
  final String icon;

  /// 主题色，形如 `#FF9800`。
  final String color;

  /// 进入一次的积分单价；为 0 表示免费。
  final int cost;

  /// 云端最新版本号。
  final String latestVersion;

  /// 包信息。
  final GamePackageInfo package;

  /// 游戏入口文件（相对包根目录），例如 `index.html`。
  final String entry;

  const GameInfo({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
    required this.color,
    required this.cost,
    required this.latestVersion,
    required this.package,
    required this.entry,
  });

  /// 从清单 JSON 构造；关键字段缺失或非法时返回 null，由调用方跳过。
  static GameInfo? tryFromJson(Object? raw) {
    if (raw is! Map) return null;

    final id = GamePathUtils.normalizeRelative(raw['id']?.toString());
    final name = raw['name'];
    final version = raw['latestVersion'];
    final entry = GamePathUtils.normalizeRelative(raw['entry']?.toString());
    final package = GamePackageInfo.tryFromJson(raw['package']);

    if (id == null || name is! String || name.isEmpty) return null;
    if (version is! String || !GameVersionUtils.isValid(version)) return null;
    if (entry == null || package == null) return null;

    final cost = raw['cost'];
    return GameInfo(
      id: id,
      name: name,
      description: raw['description'] as String? ?? '',
      icon: raw['icon'] as String? ?? 'extension',
      color: raw['color'] as String? ?? '#9C27B0',
      cost: cost is int && cost >= 0 ? cost : 0,
      latestVersion: version,
      package: package,
      entry: entry,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'description': description,
    'icon': icon,
    'color': color,
    'cost': cost,
    'latestVersion': latestVersion,
    'package': package.toJson(),
    'entry': entry,
  };
}

/// 游戏清单（远端或内置）。
class GameManifest {
  /// 清单结构版本，用于将来兼容处理。
  final int schemaVersion;

  /// 清单生成时间。
  final DateTime? updatedAt;

  /// 全部可用游戏；非法条目已在解析时剔除。
  final List<GameInfo> games;

  const GameManifest({
    required this.schemaVersion,
    required this.games,
    this.updatedAt,
  });

  /// 从 JSON 解析清单。
  ///
  /// 顶层结构非法时抛出 [FormatException]；单个游戏条目非法时**跳过该条目**
  /// 而不整份失败，避免一个小错误导致整个游戏中心不可用。
  factory GameManifest.fromJson(Object? raw) {
    if (raw is! Map) {
      throw const FormatException('清单根节点必须是 JSON 对象');
    }
    final rawGames = raw['games'];
    if (rawGames is! List) {
      throw const FormatException('清单缺少 games 数组');
    }

    final games = <GameInfo>[];
    for (final item in rawGames) {
      final game = GameInfo.tryFromJson(item);
      if (game != null) games.add(game);
    }

    final schema = raw['schemaVersion'];
    return GameManifest(
      schemaVersion: schema is int ? schema : 1,
      updatedAt: DateTime.tryParse(raw['updatedAt']?.toString() ?? ''),
      games: games,
    );
  }

  /// 按 id 查找游戏。
  GameInfo? gameById(String id) {
    for (final game in games) {
      if (game.id == id) return game;
    }
    return null;
  }
}

/// 清单/安装路径的安全校验工具。
class GamePathUtils {
  const GamePathUtils._();

  static final RegExp _windowsDrive = RegExp(r'^[a-zA-Z]:');

  /// 校验并规范化相对路径；不合法（绝对路径、包含 `..`、空串）时返回 null。
  static String? normalizeRelative(String? raw) {
    if (raw == null) return null;
    final trimmed = raw.trim().replaceAll('\\', '/');
    if (trimmed.isEmpty) return null;
    if (trimmed.startsWith('/')) return null;
    if (_windowsDrive.hasMatch(trimmed)) return null;
    final segments = trimmed.split('/');
    if (segments.any((s) => s == '..' || s.isEmpty)) return null;
    return segments.join('/');
  }
}