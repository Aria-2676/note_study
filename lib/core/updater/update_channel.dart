import 'services/app_update_service.dart';
import 'services/app_update_settings.dart';

/// 一条更新渠道 = **一份清单 + 一套本地状态**。两者必须成对切换。
///
/// 6.0.0 对 V5 是一次性的"引流"：V5 用户会在更新弹窗里看到 6.0.0，
/// 可以选择升级，也可以点「跳过此版本」不再被打扰。**这次之后两条线分开**：
///
/// | 渠道 | 清单 | 谁在用 |
/// |---|---|---|
/// | v5 | `update.json` | 所有已发布的 5.x 包（地址写死在代码里，改了就断供） |
/// | v6 | `update_v6.json` | 6.0.0 及之后 |
///
/// 只换清单文件是不够的 —— 本地状态也必须隔离，理由见
/// [AppUpdateSettings.scope] 的注释（资源包构建号串了会永久静默跳过热更）。
class UpdateChannel {
  const UpdateChannel({
    required this.name,
    required this.manifestPath,
    required this.settingsScope,
  });

  /// 渠道名，只用于日志和报错，不参与任何判断。
  final String name;

  /// 相对仓库根目录的清单文件名。
  final String manifestPath;

  /// 本地状态键前缀；空串表示 V5 原有的键名。
  final String settingsScope;

  /// V5 渠道。
  ///
  /// **这份清单在发完 6.0.0 之后冻结**：不再改 `latest.version`，也不再改
  /// `minSupported`。两个原因：
  /// - 改 `latest.version` 会让 V5 用户以为还有新版本，实际拿到的是同一个包
  /// - 把 `minSupported` 提到 6.0.0 就等于**强制更新**，用户失去「跳过」的权利
  static const UpdateChannel v5 = UpdateChannel(
    name: 'v5',
    manifestPath: AppUpdateService.v5ManifestPath,
    settingsScope: '',
  );

  /// V6 渠道。每次 V6 发版只改这份。
  static const UpdateChannel v6 = UpdateChannel(
    name: 'v6',
    manifestPath: 'update_v6.json',
    settingsScope: 'v6',
  );

  /// 造一份读本渠道清单的 service。
  AppUpdateService createService() =>
      AppUpdateService(manifestPath: manifestPath);

  /// 本渠道专属的本地状态。
  AppUpdateSettings get settings => AppUpdateSettings(scope: settingsScope);

  @override
  String toString() => 'UpdateChannel($name → $manifestPath)';
}
