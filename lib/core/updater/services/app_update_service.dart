import 'dart:convert';
import 'dart:io';

import '../../config/cdn_bases.dart';
import '../../utils/app_logger.dart';
import '../models/app_update_decision.dart';
import '../models/app_update_manifest.dart';
import 'app_update_decider.dart';
import 'app_update_exception.dart';

/// App 版本检查：拉取云端 `update.json` 并给出更新结论。
///
/// 与游戏模块共用同一套 CDN 基址与「主站优先、镜像回退」策略（见 [CdnBases]），
/// 因此**不需要任何后端**——把 `update.json` 提交到仓库根目录即可生效。
///
/// 职责边界：本类只负责「拉取 + 交给决策器判定」，不负责下载安装包、
/// 不做持久化、不弹 UI。那些是上层的事。
class AppUpdateService {
  /// 更新清单相对仓库根目录的路径。
  static const String manifestPath = 'update.json';

  AppUpdateService({
    List<Uri> Function()? candidateProvider,
    this.timeout = const Duration(seconds: 15),
  }) : _candidateProvider = candidateProvider ?? defaultCandidates;

  final List<Uri> Function() _candidateProvider;

  /// 单次 HTTP 请求的超时时间。
  final Duration timeout;

  /// 默认候选地址：主 CDN 在前，镜像在后，自动去重。
  static List<Uri> defaultCandidates() {
    return CdnBases.resolve(
      CdnBases.manifest,
      CdnBases.manifestFallbacks,
      manifestPath,
    );
  }

  /// 按候选顺序依次尝试拉取更新清单。
  ///
  /// 全部候选都失败时抛 [AppUpdateException]；单个候选失败只记日志并继续，
  /// 这样某个 jsDelivr 节点抽风不会让功能整体不可用。
  Future<AppUpdateManifest> fetchManifest() async {
    Object? lastError;
    for (final uri in _candidateProvider()) {
      try {
        final body = await _httpGetString(uri);
        return AppUpdateManifest.fromJson(jsonDecode(body));
      } catch (error, stack) {
        lastError = error;
        AppLogger.warn('AppUpdateService', '获取更新清单失败: $uri', error, stack);
      }
    }
    throw AppUpdateException('无法获取更新清单（$lastError）');
  }

  /// 拉取失败时返回 null。
  ///
  /// 版本检查是「锦上添花」，网络异常时应当静默跳过，而不是把错误抛给用户。
  Future<AppUpdateManifest?> tryFetchManifest() async {
    try {
      return await fetchManifest();
    } on AppUpdateException {
      return null;
    }
  }

  /// 一次完整的版本检查：拉清单 → 决策。
  ///
  /// 参数含义见 [AppUpdateDecider.decide]。
  Future<AppUpdateDecision> check({
    required String currentVersion,
    required String platform,
    int currentAssetBuild = 0,
    String? ignoredVersion,
    bool notificationsDisabled = false,
  }) async {
    final manifest = await tryFetchManifest();
    return AppUpdateDecider.decide(
      manifest: manifest,
      currentVersion: currentVersion,
      platform: platform,
      currentAssetBuild: currentAssetBuild,
      ignoredVersion: ignoredVersion,
      notificationsDisabled: notificationsDisabled,
    );
  }

  Future<String> _httpGetString(Uri uri) async {
    final client = HttpClient()..connectionTimeout = timeout;
    try {
      final request = await client.getUrl(uri);
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      final response = await request.close().timeout(timeout);
      if (response.statusCode != HttpStatus.ok) {
        throw AppUpdateException('HTTP ${response.statusCode}');
      }
      return await response.transform(utf8.decoder).join().timeout(timeout);
    } finally {
      client.close(force: true);
    }
  }
}
