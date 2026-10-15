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

  /// GitHub Contents API 上的清单地址。
  ///
  /// 这是**近实时**的一路：它读的是仓库当前内容，没有 jsDelivr 对分支引用
  /// 的最长约 12 小时缓存，发布后立刻能被发现，专门用来兜住「CDN 还没刷新」
  /// 的时间窗。代价：未认证调用限速 60 次/小时/IP，所以排在所有 CDN 之后
  /// 兜底（自签小圈子分发 + 每小时一次自动检查，远用不完）。
  static const String manifestApiUrl =
      'https://api.github.com/repos/Aria-2676/note_study/contents/update.json';

  AppUpdateService({
    List<Uri> Function()? candidateProvider,
    Uri? contentsApiUrl,
    this.timeout = const Duration(seconds: 15),
  }) : _candidateProvider = candidateProvider ?? defaultCandidates,
       _contentsApiUrl = contentsApiUrl ?? Uri.parse(manifestApiUrl);

  final List<Uri> Function() _candidateProvider;

  /// Contents API 兜底地址（可注入仅为测试）。
  final Uri _contentsApiUrl;

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
  /// 顺序：jsDelivr 各节点（gcore → testingcf → cdn）→ raw 源站 →
  /// GitHub Contents API（近实时，限速兜底）。单个候选失败只记日志并继续，
  /// 这样某个节点抽风不会让功能整体不可用；全部失败才抛 [AppUpdateException]。
  Future<AppUpdateManifest> fetchManifest() async {
    Object? lastError;
    for (final uri in _candidateProvider()) {
      try {
        final body = await _httpGetString(uri, viaContentsApi: false);
        return AppUpdateManifest.fromJson(jsonDecode(body));
      } catch (error, stack) {
        lastError = error;
        AppLogger.warn('AppUpdateService', '获取更新清单失败: $uri', error, stack);
      }
    }

    // 最后一路：GitHub Contents API（JSON 信封里装 base64 内容）。
    try {
      final body = await _httpGetString(
        _contentsApiUrl,
        viaContentsApi: true,
      );
      return AppUpdateManifest.fromJson(jsonDecode(body));
    } catch (error, stack) {
      lastError = error;
      AppLogger.warn(
        'AppUpdateService',
        '获取更新清单失败（Contents API）: $_contentsApiUrl',
        error,
        stack,
      );
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

  /// 拉取并解码清单文本。
  ///
  /// [viaContentsApi] 为 true 时，响应是 GitHub Contents API 的 JSON 信封
  /// （`{encoding: "base64", content: "..."}`），需要先拆信封、base64 解码；
  /// 为 false 时响应体就是清单原文。
  ///
  /// 所有请求都带 `Cache-Control: no-cache`：中间透明缓存（运营商/企业网关）
  /// 不得缓存清单，尽量缩短「发布 → 客户端发现」的延迟。
  Future<String> _httpGetString(Uri uri, {required bool viaContentsApi}) async {
    final client = HttpClient()..connectionTimeout = timeout;
    try {
      final request = await client.getUrl(uri);
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      request.headers.set(HttpHeaders.cacheControlHeader, 'no-cache');
      request.headers.set('Pragma', 'no-cache');
      if (viaContentsApi) {
        request.headers.set('Accept', 'application/vnd.github+json');
      }
      final response = await request.close().timeout(timeout);
      if (response.statusCode != HttpStatus.ok) {
        throw AppUpdateException('HTTP ${response.statusCode}');
      }
      final rawBody = await response.transform(utf8.decoder).join().timeout(timeout);
      if (!viaContentsApi) return rawBody;

      final envelope = jsonDecode(rawBody);
      if (envelope is! Map ||
          envelope['encoding']?.toString() != 'base64' ||
          envelope['content'] is! String) {
        throw const AppUpdateException('Contents API 响应结构异常');
      }
      // Contents API 的 base64 内容按 76 列插了换行，解码前必须剥掉。
      final compact = (envelope['content'] as String).replaceAll(RegExp(r'\s'), '');
      return utf8.decode(base64.decode(compact));
    } finally {
      client.close(force: true);
    }
  }
}
