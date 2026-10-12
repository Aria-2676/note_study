import '../../utils/version_utils.dart';

/// App 更新清单（`update.json`）的解析结果。
///
/// 设计原则与游戏清单一致：**顶层结构非法 → 抛 [FormatException]；
/// 局部字段非法 → 丢弃该局部而不是整份失败**。更新清单是外网文件，
/// 一个笔误不该让整个「版本检查」功能瘫痪。
class AppUpdateManifest {
  /// 清单结构版本，用于将来做兼容处理。
  final int schemaVersion;

  /// 清单生成时间。
  final DateTime? updatedAt;

  /// 最低可支持的客户端版本；低于它的客户端**强制**更新。
  ///
  /// 留空表示不强制。用于旧版协议不兼容、必须换包的情况。
  final String? minSupported;

  /// 最新的整包版本；为 null 表示当前没有整包更新。
  final AppRelease? release;

  /// 资源热更新包；为 null 表示没有资源更新。
  final AssetUpdatePackage? assets;

  const AppUpdateManifest({
    required this.schemaVersion,
    this.updatedAt,
    this.minSupported,
    this.release,
    this.assets,
  });

  /// 从 JSON 解析。
  ///
  /// [FormatException] 只在「根节点不是对象」时抛出。
  factory AppUpdateManifest.fromJson(Object? raw) {
    if (raw is! Map) {
      throw const FormatException('更新清单根节点必须是 JSON 对象');
    }

    final schema = raw['schemaVersion'];
    final minSupportedRaw = raw['minSupported'];

    return AppUpdateManifest(
      schemaVersion: schema is int ? schema : 1,
      updatedAt: DateTime.tryParse(raw['updatedAt']?.toString() ?? ''),
      // 版本号至少要含一个数字才认；否则视为未设置（宁可漏提示，不可误强制）。
      minSupported:
          minSupportedRaw is String && VersionUtils.isValid(minSupportedRaw)
          ? minSupportedRaw
          : null,
      release: AppRelease.tryFromJson(raw['latest'] ?? raw['release']),
      assets: AssetUpdatePackage.tryFromJson(raw['assets']),
    );
  }

  /// 是否存在任何可用更新。
  bool get hasAnyUpdate => release != null || assets != null;

  Map<String, dynamic> toJson() => {
    'schemaVersion': schemaVersion,
    if (updatedAt != null) 'updatedAt': updatedAt!.toUtc().toIso8601String(),
    if (minSupported != null) 'minSupported': minSupported,
    if (release != null) 'latest': release!.toJson(),
    if (assets != null) 'assets': assets!.toJson(),
  };
}

/// 一个可下载的整包产物（按平台区分）。
class AppDownloadTarget {
  /// 下载地址；必须是 http/https。
  final String url;

  /// 文件的 sha256（小写十六进制）；为空表示下载后不做校验。
  final String sha256;

  /// 文件体积（字节）；未知时为 0。
  final int sizeBytes;

  const AppDownloadTarget({
    required this.url,
    this.sha256 = '',
    this.sizeBytes = 0,
  });

  /// 从 JSON 构造；地址非法时返回 null（该平台的产物被丢弃）。
  static AppDownloadTarget? tryFromJson(Object? raw) {
    if (raw is! Map) return null;
    final url = raw['url'];
    if (url is! String || !isSafeDownloadUrl(url)) return null;
    final sha = raw['sha256'];
    final size = raw['sizeBytes'];
    return AppDownloadTarget(
      url: url,
      sha256: sha is String ? sha.toLowerCase() : '',
      sizeBytes: size is int && size > 0 ? size : 0,
    );
  }

  /// 下载地址是否安全：只允许 http/https，拒绝 `file:` / `javascript:` 等。
  ///
  /// 清单来自外网，地址会被直接交给平台层去下载甚至安装，因此必须在这里把住。
  static bool isSafeDownloadUrl(String raw) {
    final uri = Uri.tryParse(raw);
    if (uri == null || !uri.isAbsolute) return false;
    return uri.scheme == 'https' || uri.scheme == 'http';
  }

  Map<String, dynamic> toJson() => {
    'url': url,
    'sha256': sha256,
    'sizeBytes': sizeBytes,
  };
}

/// 最新的整包版本。
class AppRelease {
  /// 版本号，形如 `5.6.0`。
  final String version;

  /// 清单里显式声明的变更级别；缺省时为 null，由调用方按版本号差值推断。
  final VersionChangeLevel? declaredLevel;

  /// 更新说明（每行一条）。
  final List<String> notes;

  /// 发布时间。
  final DateTime? publishedAt;

  /// 平台标识（`android` / `ios` / `windows` …）→ 下载产物。
  final Map<String, AppDownloadTarget> downloads;

  const AppRelease({
    required this.version,
    this.declaredLevel,
    this.notes = const [],
    this.publishedAt,
    this.downloads = const {},
  });

  /// 从 JSON 构造；版本号非法时返回 null。
  static AppRelease? tryFromJson(Object? raw) {
    if (raw is! Map) return null;
    final version = raw['version'];
    if (version is! String || !VersionUtils.isValid(version)) return null;

    final downloads = <String, AppDownloadTarget>{};
    final rawDownloads = raw['downloads'];
    if (rawDownloads is Map) {
      for (final entry in rawDownloads.entries) {
        final target = AppDownloadTarget.tryFromJson(entry.value);
        if (target != null) downloads[entry.key.toString()] = target;
      }
    }

    return AppRelease(
      version: version,
      declaredLevel: _parseLevel(raw['level']),
      notes: _parseNotes(raw['notes']),
      publishedAt: DateTime.tryParse(raw['publishedAt']?.toString() ?? ''),
      downloads: downloads,
    );
  }

  /// 相对 [current] 的变更级别：清单显式声明优先，否则按版本号差值推断。
  VersionChangeLevel levelAgainst(String current) {
    return declaredLevel ?? VersionUtils.differenceLevel(version, current);
  }

  /// 指定平台是否有可下载的产物。
  bool supportsPlatform(String platform) => downloads.containsKey(platform);

  static VersionChangeLevel? _parseLevel(Object? raw) {
    if (raw is VersionChangeLevel) return raw;
    switch (raw?.toString().trim().toLowerCase()) {
      case 'major':
        return VersionChangeLevel.major;
      case 'minor':
        return VersionChangeLevel.minor;
      case 'patch':
        return VersionChangeLevel.patch;
      default:
        return null;
    }
  }

  static List<String> _parseNotes(Object? raw) {
    if (raw is String) {
      return raw
          .split('\n')
          .map((line) => line.trim())
          .where((line) => line.isNotEmpty)
          .toList(growable: false);
    }
    if (raw is List) {
      return raw
          .map((item) => item?.toString().trim() ?? '')
          .where((line) => line.isNotEmpty)
          .toList(growable: false);
    }
    return const [];
  }

  Map<String, dynamic> toJson() => {
    'version': version,
    if (declaredLevel != null) 'level': declaredLevel!.name,
    'notes': notes,
    if (publishedAt != null) 'publishedAt': publishedAt!.toUtc().toIso8601String(),
    'downloads': downloads.map((key, value) => MapEntry(key, value.toJson())),
  };
}

/// 资源热更新包。
///
/// 用**单调递增的整数构建号**而不是版本号：资源包会一天里重打好几次，
/// 用 `major.minor.patch` 既容易撞号又要点数不等的位数，整数最不容易出错。
class AssetUpdatePackage {
  /// 构建号；必须比本地已应用的大才会更新。
  final int build;

  /// 压缩包地址（zip）。
  final String url;

  /// 压缩包的 sha256（小写十六进制）；为空表示不校验。
  final String sha256;

  /// 压缩包体积（字节）；未知时为 0。
  final int sizeBytes;

  const AssetUpdatePackage({
    required this.build,
    required this.url,
    this.sha256 = '',
    this.sizeBytes = 0,
  });

  /// 从 JSON 构造；构建号或地址非法时返回 null。
  static AssetUpdatePackage? tryFromJson(Object? raw) {
    if (raw is! Map) return null;
    final build = raw['build'];
    final url = raw['url'];
    if (build is! int || build <= 0) return null;
    if (url is! String || !AppDownloadTarget.isSafeDownloadUrl(url)) return null;
    final sha = raw['sha256'];
    final size = raw['sizeBytes'];
    return AssetUpdatePackage(
      build: build,
      url: url,
      sha256: sha is String ? sha.toLowerCase() : '',
      sizeBytes: size is int && size > 0 ? size : 0,
    );
  }

  Map<String, dynamic> toJson() => {
    'build': build,
    'url': url,
    'sha256': sha256,
    'sizeBytes': sizeBytes,
  };
}
