import 'dart:async';
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
  /// V5 渠道的清单文件名。
  ///
  /// **已经发出去的 V5 包把这个地址写死在代码里**，所以它永远不能改名 ——
  /// 改了等于让所有 V5 用户再也收不到更新。
  ///
  /// V6 用的是另一份清单（见 [UpdateChannel]），两份互不影响：
  /// 6.0.0 之后 V5 停在 `update.json`，V6 只认 `update_v6.json`。
  static const String v5ManifestPath = 'update.json';

  /// GitHub Contents API 上的仓库内容地址前缀。
  static const String contentsApiBase =
      'https://api.github.com/repos/Aria-2676/note_study/contents';

  AppUpdateService({
    this.manifestPath = v5ManifestPath,
    List<Uri> Function()? candidateProvider,
    Uri? contentsApiUrl,
    this.timeout = const Duration(seconds: 15),
  }) : _candidateProvider =
           candidateProvider ?? (() => candidatesFor(manifestPath)),
       _contentsApiUrl = contentsApiUrl ?? contentsApiUri(manifestPath);

  /// 这份 service 读哪份清单。
  ///
  /// 默认是 V5 的那份（保持既有调用点的行为不变）；V6 由
  /// [UpdateChannel.v6] 显式指定 `update_v6.json`。
  final String manifestPath;

  final List<Uri> Function() _candidateProvider;

  /// Contents API 兜底地址（可注入仅为测试）。
  final Uri _contentsApiUrl;

  /// 单次 HTTP 请求的超时时间。
  final Duration timeout;

  /// 默认候选地址：主 CDN 在前，镜像在后，自动去重。
  static List<Uri> candidatesFor(String path) {
    return CdnBases.resolve(CdnBases.manifest, CdnBases.manifestFallbacks, path);
  }

  /// Contents API 地址。**必须跟着清单名走** ——
  /// 否则 V6 在 CDN 全部失败时会去读 V5 的清单，把 5.x 的更新当成自己的。
  static Uri contentsApiUri(String path) =>
      Uri.parse('$contentsApiBase/$path');

  /// 兼容旧调用点（默认渠道）。
  static List<Uri> defaultCandidates() => candidatesFor(v5ManifestPath);

  /// 并发拉所有源，**挑 `updatedAt` 最新的那份**。
  ///
  /// 为什么不能"第一个成功就用"：CDN 会缓存分支解析出来的那个提交（实测
  /// jsDelivr 的 gcore 节点会持续发旧文件，purge 也刷不掉），而"响应最快的
  /// 那个"完全可能是"最旧的那个"。5.5.26 就是这么写的 —— 清单改成 6.0.0 之后
  /// 客户端仍然提示"已是最新 5.5.26"，因为 gcore 先返回了旧缓存。
  ///
  /// 所以：并发全取，等一小会儿收齐，按清单里的 `updatedAt` 挑最新；
  /// 读不出时间的视为最旧。单个源失败只记日志，不影响结论。
  Future<AppUpdateManifest> fetchManifest() async {
    final sources = <(Uri, bool)>[
      for (final uri in _candidateProvider()) (uri, false),
      (_contentsApiUrl, true),
    ];

    final arrived = <AppUpdateManifest>[];
    final firstOk = Completer<void>();
    final allDone = Completer<void>();
    var left = sources.length;
    Object? lastError;

    for (final (uri, viaApi) in sources) {
      unawaited(() async {
        try {
          final body = await _httpGetString(uri, viaContentsApi: viaApi);
          arrived.add(AppUpdateManifest.fromJson(jsonDecode(body)));
          if (!firstOk.isCompleted) firstOk.complete();
        } catch (error, stack) {
          lastError = error;
          AppLogger.warn(
            'AppUpdateService',
            '获取更新清单失败: $uri',
            error,
            stack,
          );
        } finally {
          left--;
          if (left == 0 && !allDone.isCompleted) allDone.complete();
        }
      }());
    }

    // 等到"至少一个成功"或"全部结束"，再多等一小会儿收齐其它源 ——
    // 否则拿到的只是"响应最快的"，不等于"最新的"。
    await Future.any(<Future<void>>[firstOk.future, allDone.future]);
    await Future.any(<Future<void>>[
      allDone.future,
      Future<void>.delayed(const Duration(milliseconds: 600)),
    ]);

    if (arrived.isEmpty) {
      throw AppUpdateException('无法获取更新清单（$lastError）');
    }

    arrived.sort((a, b) => _freshness(b).compareTo(_freshness(a)));
    return arrived.first;
  }

  /// 清单的"新鲜度"。读不出 `updatedAt` 的按 epoch 算，永远排在后面。
  static DateTime _freshness(AppUpdateManifest manifest) =>
      manifest.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0);

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
