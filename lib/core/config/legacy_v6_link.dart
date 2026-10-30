import '../updater/models/app_update_manifest.dart';

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
/// 指向 6.0.0 的**整包**（fat APK，任何机型都能装）；以后 6.x 出新版由 6.x
/// 自己的更新器负责，这里不需要跟着改。
class LegacyV6Link {
  const LegacyV6Link._();

  static const String version = '6.0.0';

  /// GitHub 原始地址。
  ///
  /// 当 primary 只是为了复用 [DownloadMirrors] 的展开规则：显式 mirrors 排最前
  /// （Gitee），之后是两个公益加速前缀，最后才是 GitHub 直连。
  static const String apkUrlGithub =
      'https://github.com/Aria-2676/taskmaster-v6/releases/download/v6.0.0/app-release.apk';

  /// Gitee 上的同一份文件（国内直连可用）。字节与 GitHub 那份完全一致。
  static const String apkUrlGitee =
      'https://gitee.com/yaozhenqian/taskmaster-release/releases/download/v6.0.0/app-release.apk';

  /// 6.0.0 整包的 sha256。**换包必须同时改这里**，否则下载下来会被校验拒绝。
  static const String sha256 =
      'a2988acae8a2f7991e0cd9b80e0099bc82565d603674964629fd82ea3f161ca3';

  /// 6.0.0 整包体积（字节）。显示"约 62 MB"，也给下载器一个进度基准。
  static const int sizeBytes = 61798023;

  /// 确认框正文。用户最怕的是"装完把我现在这个顶掉"，这句必须在。
  static const String confirmBody =
      '约 62 MB。它和当前的「任务管家」是两个 App，不会覆盖；'
      '装完桌面上会多一个图标，V5 的任务和积分不会带过去。';

  static AppDownloadTarget get target => const AppDownloadTarget(
        url: apkUrlGithub,
        mirrors: <String>[apkUrlGitee],
        sha256: sha256,
        sizeBytes: sizeBytes,
      );
}
