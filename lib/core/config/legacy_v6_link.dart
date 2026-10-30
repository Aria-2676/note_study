import '../updater/models/app_update_manifest.dart';

/// 一个可下载的产物。
class V6Artifact {
  const V6Artifact({
    required this.file,
    required this.sha256,
    required this.sizeBytes,
  });

  /// Release 里的文件名，也是 URL 的最后一段。
  final String file;
  final String sha256;
  final int sizeBytes;

  double get megabytes => sizeBytes / 1024 / 1024;
}

/// 6.x 新版的固定下载入口（V5 里显示）。
///
/// **为什么写死在代码里、而不是塞进更新清单**：
///
/// 自更新清单（`update.json`）只该回答"我这个 App 有没有新版本"。它一旦被指向
/// 6.0.0，两件事同时坏掉：
///   1. V5 再也不能发 5.5.27 —— 用户会看到"最新版是 6.0.0"，而那是另一个 App；
///   2. 那个 6.0.0 的弹窗和 V5 自己的版本号语义冲突，用户根本分不清在升什么。
///
/// 所以引流走独立常量：地址固定、不随清单变、也不受 CDN 缓存影响。
/// 指向 6.0.0；以后 6.x 出新版由 6.x 自己的更新器负责，这里不需要跟着改。
///
/// **按机型选包**：`--split-per-abi` 出了分架构的包，arm64 只有 22MB，
/// 通用整包 62MB。老实现直接下整包，等于让绝大多数用户多花 40MB 流量。
/// 拿不到 ABI 时才回落到整包（[fallback]）。
class LegacyV6Link {
  const LegacyV6Link._();

  static const String version = '6.0.0';

  /// GitHub 原始地址（当 primary，是为了复用 [DownloadMirrors] 的展开规则：
  /// 显式 mirrors 排最前，然后是两个公益加速前缀，最后才是 GitHub 直连）。
  static const String _githubBase =
      'https://github.com/Aria-2676/taskmaster-v6/releases/download/v6.0.0';

  /// Gitee 上的同一批文件（国内直连可用），字节与 GitHub 那批完全一致。
  static const String _giteeBase =
      'https://gitee.com/yaozhenqian/taskmaster-release/releases/download/v6.0.0';

  /// 分架构产物。键与 Flutter `--split-per-abi` 的后缀（也是 `getprop` 的取值）一致。
  ///
  /// sha256 是各包**各自**的 —— 不能拿整包那个去校验分架构包，会直接报摘要不符。
  static const Map<String, V6Artifact> artifacts = <String, V6Artifact>{
    'arm64-v8a': V6Artifact(
      file: 'app-arm64-v8a-release.apk',
      sha256: '07d51a1ec674c56133cb071931f9fae57f2595d3e3674cebc6c16e286801d6eb',
      sizeBytes: 22450209,
    ),
    'armeabi-v7a': V6Artifact(
      file: 'app-armeabi-v7a-release.apk',
      sha256: 'a5bfdb940c32d500b254b56f403254133654817539c2b637c4977b46fb9f9752',
      sizeBytes: 20252141,
    ),
    'x86_64': V6Artifact(
      file: 'app-x86_64-release.apk',
      sha256: '96bb8ae251d6fca9a9e7341eaa3226251310af85bbae269163ade9c8f6d06201',
      sizeBytes: 23999513,
    ),
  };

  /// 通用整包：任何机型都能装，代价是 62MB。
  ///
  /// 只在拿不到 ABI 时用。**不能按"反正都能装"就都下它** —— 那是 3 倍流量。
  static const V6Artifact fallback = V6Artifact(
    file: 'app-release.apk',
    sha256: 'a2988acae8a2f7991e0cd9b80e0099bc82565d603674964629fd82ea3f161ca3',
    sizeBytes: 61798023,
  );

  /// [abi] 取 `getprop ro.product.cpu.abi` 规整后的值（见 `AbiProperty`）。
  static V6Artifact artifactFor(String? abi) =>
      artifacts[abi] ?? fallback;

  /// 交给更新器的下载目标。
  ///
  /// 包名不同，装出来是**另一个 App**，当前的 V5 原样保留。
  static AppDownloadTarget targetFor(String? abi) {
    final artifact = artifactFor(abi);
    return AppDownloadTarget(
      url: '$_githubBase/${artifact.file}',
      mirrors: <String>['$_giteeBase/${artifact.file}'],
      sha256: artifact.sha256,
      sizeBytes: artifact.sizeBytes,
    );
  }

  /// 确认框正文。用户最怕的是"装完把我现在这个顶掉"，这句必须在。
  static String confirmBodyFor(String? abi) {
    final mb = artifactFor(abi).megabytes.toStringAsFixed(0);
    return '约 $mb MB。它和当前的「任务管家」是两个 App，不会覆盖；'
        '装完桌面上会多一个图标，V5 的任务和积分不会带过去。';
  }
}
