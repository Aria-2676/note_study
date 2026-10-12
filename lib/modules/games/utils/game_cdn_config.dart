import '../../../core/config/cdn_bases.dart';

/// 小游戏分发地址配置。
///
/// 基址已上移到 [CdnBases]（与 App 更新包共用同一批 CDN 镜像，避免两处各写一份），
/// 这里只保留「游戏相关」的路径常量与候选地址拼装。公共 API 与之前完全一致。
class GameCdnConfig {
  const GameCdnConfig._();

  /// 清单所在仓库路径（相对仓库根目录）。
  static const String manifestPath = 'game_center/manifest.json';

  /// 可变地址基址：用于拉取 manifest。
  ///
  /// 默认走 jsDelivr 的 GitHub 代理；jsDelivr 对分支引用有约 12 小时缓存，
  /// 因此新游戏上架后列表刷新可能有延迟。
  static const String manifestBase = CdnBases.manifest;

  /// 不可变地址基址：用于拉取游戏包（首选）。
  ///
  /// 刻意**不用** `cdn.jsdelivr.net` 作为首选：实测它对 `.zip` 会 301 重定向到
  /// `raw.githubusercontent.com`（该主机在国内常被间歇性 reset），而
  /// `gcore.jsdelivr.net` / `testingcf.jsdelivr.net` 可直连返回 200。
  static const String packageBase = CdnBases.largeFile;

  /// 主基址不可达时的回退基址列表（按顺序尝试）。
  static const List<String> manifestFallbackBases = CdnBases.manifestFallbacks;

  /// 游戏包的回退基址列表（按顺序尝试）。
  static const List<String> packageFallbackBases = CdnBases.largeFileFallbacks;

  /// 按顺序返回所有候选的 manifest 地址（主基址在前）。
  static List<Uri> manifestUris() {
    return CdnBases.resolve(manifestBase, manifestFallbackBases, manifestPath);
  }

  /// 按顺序返回所有候选的游戏包地址（主基址在前）。
  static List<Uri> packageUris(String relativePath) {
    return CdnBases.resolve(packageBase, packageFallbackBases, relativePath);
  }
}
