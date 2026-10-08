/// 小游戏分发地址配置。
///
/// 游戏包与清单托管在 GitHub 仓库，通过 CDN 分发。地址可在构建时用
/// `--dart-define` 覆盖，避免把地址写死在代码里：
///
/// ```powershell
/// flutter build apk --dart-define=GAME_CDN_BASE=https://example.com/base
/// ```
class GameCdnConfig {
  const GameCdnConfig._();

  /// 清单所在仓库路径（相对仓库根目录）。
  static const String manifestPath = 'game_center/manifest.json';

  /// 可变地址基址：用于拉取 manifest。
  ///
  /// 默认走 jsDelivr 的 GitHub 代理；jsDelivr 对分支引用有约 12 小时缓存，
  /// 因此新游戏上架后列表刷新可能有延迟。
  static const String manifestBase = String.fromEnvironment(
    'GAME_CDN_BASE',
    defaultValue: 'https://cdn.jsdelivr.net/gh/Aria-2676/note_study@main',
  );

  /// 不可变地址基址：用于拉取游戏包。
  ///
  /// 刻意**不用** `cdn.jsdelivr.net`：实测它对 `.zip` 会 301 重定向到
  /// `raw.githubusercontent.com`（该主机在国内常被间歇性 reset），而
  /// `gcore.jsdelivr.net` / `testingcf.jsdelivr.net` 可直连返回 200。
  ///
  /// 发布时仍可注入 commit SHA（`...@<sha>`），使同一路径的内容永久不变，
  /// 从而让 sha256 校验真正具备意义。
  static const String packageBase = String.fromEnvironment(
    'GAME_CDN_SHA_BASE',
    defaultValue: 'https://gcore.jsdelivr.net/gh/Aria-2676/note_study@main',
  );

  /// 主基址不可达时的回退基址列表（按顺序尝试）。
  ///
  /// 优先 jsDelivr 的镜像节点：实测本机 `cdn.jsdelivr.net` / `gcore.jsdelivr.net`
  /// / `testingcf.jsdelivr.net` 均可正常返回，而 `raw.githubusercontent.com`
  /// 虽 TCP 可连、HTTP 却常被中途重置（Connection reset by peer），故置末位兜底。
  static const List<String> manifestFallbackBases = [
    'https://gcore.jsdelivr.net/gh/Aria-2676/note_study@main',
    'https://testingcf.jsdelivr.net/gh/Aria-2676/note_study@main',
    'https://raw.githubusercontent.com/Aria-2676/note_study/main',
  ];

  /// 按顺序返回所有候选的 manifest 地址（主基址在前）。
  static List<Uri> manifestUris() {
    final bases = <String>{manifestBase, ...manifestFallbackBases};
    return bases.map((base) => Uri.parse('$base/$manifestPath')).toList();
  }

  /// 由清单中的相对路径构造游戏包下载地址。
  static Uri packageUri(String relativePath) {
    return Uri.parse('$packageBase/$relativePath');
  }
}