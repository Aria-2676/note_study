/// 本地已安装游戏的记录。
class InstalledGame {
  /// 游戏 id，与清单中的 [GameInfo.id] 对应。
  final String gameId;

  /// 本地已安装的版本号。
  final String installedVersion;

  /// 安装完成时间。
  final DateTime installedAt;

  /// 安装后的目录体积（字节）。
  final int sizeBytes;

  /// 入口文件（相对该版本目录），例如 `index.html`。
  final String entry;

  const InstalledGame({
    required this.gameId,
    required this.installedVersion,
    required this.installedAt,
    required this.sizeBytes,
    required this.entry,
  });

  /// 从索引 JSON 构造；关键字段非法时返回 null。
  static InstalledGame? tryFromJson(String gameId, Object? raw) {
    if (raw is! Map) return null;
    final version = raw['installedVersion'];
    final entry = raw['entry'];
    if (version is! String || version.isEmpty) return null;
    if (entry is! String || entry.isEmpty) return null;
    final size = raw['sizeBytes'];
    return InstalledGame(
      gameId: gameId,
      installedVersion: version,
      installedAt:
          DateTime.tryParse(raw['installedAt']?.toString() ?? '') ??
          DateTime.now(),
      sizeBytes: size is int ? size : 0,
      entry: entry,
    );
  }

  Map<String, dynamic> toJson() => {
    'installedVersion': installedVersion,
    'installedAt': installedAt.toIso8601String(),
    'sizeBytes': sizeBytes,
    'entry': entry,
  };
}

/// 已安装游戏索引。
///
/// 以文件形式存放在应用私有目录，**仅作缓存**：真实来源是磁盘上的游戏目录，
/// 索引损坏或丢失时可通过扫描目录重建。这样避免了为游戏模块改动全局数据库 schema。
class InstalledGamesIndex {
  /// 索引结构版本。
  final int schemaVersion;

  /// gameId -> 安装记录。
  final Map<String, InstalledGame> games;

  const InstalledGamesIndex({
    required this.games,
    this.schemaVersion = 1,
  });

  /// 空索引。
  static const InstalledGamesIndex empty = InstalledGamesIndex(games: {});

  /// 从 JSON 解析；结构非法时抛出 [FormatException]。
  factory InstalledGamesIndex.fromJson(Object? raw) {
    if (raw is! Map) {
      throw const FormatException('安装索引根节点必须是 JSON 对象');
    }
    final rawGames = raw['games'];
    if (rawGames is! Map) {
      throw const FormatException('安装索引缺少 games 对象');
    }

    final games = <String, InstalledGame>{};
    for (final entry in rawGames.entries) {
      final parsed = InstalledGame.tryFromJson(entry.key.toString(), entry.value);
      if (parsed != null) games[entry.key.toString()] = parsed;
    }

    final schema = raw['schemaVersion'];
    return InstalledGamesIndex(
      schemaVersion: schema is int ? schema : 1,
      games: games,
    );
  }

  /// 查询某个游戏的安装记录。
  InstalledGame? byId(String gameId) => games[gameId];

  /// 返回写入/替换一条记录后的新索引。
  InstalledGamesIndex put(InstalledGame game) {
    return InstalledGamesIndex(
      schemaVersion: schemaVersion,
      games: {...games, game.gameId: game},
    );
  }

  /// 返回移除某游戏后的新索引。
  InstalledGamesIndex remove(String gameId) {
    final next = {...games}..remove(gameId);
    return InstalledGamesIndex(schemaVersion: schemaVersion, games: next);
  }

  Map<String, dynamic> toJson() => {
    'schemaVersion': schemaVersion,
    'games': games.map((key, value) => MapEntry(key, value.toJson())),
  };
}