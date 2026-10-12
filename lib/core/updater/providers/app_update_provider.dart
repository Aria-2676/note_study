import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../utils/app_logger.dart';
import '../models/app_update_decision.dart';
import '../models/app_update_manifest.dart';
import '../services/app_asset_applier.dart';
import '../services/app_update_decider.dart';
import '../services/app_update_exception.dart';
import '../services/app_update_launcher.dart';
import '../services/app_update_service.dart';
import '../services/app_update_settings.dart';

/// 版本检查与更新流程的状态中枢。
///
/// 依赖全部可注入（服务 / 设置 / 平台启动器 / 资源落地器 / 版本号来源），
/// 因此决策与节流逻辑可以脱离真实平台被测试。
class AppUpdateProvider extends ChangeNotifier {
  AppUpdateProvider({
    AppUpdateService? service,
    AppUpdateSettings? settings,
    AppUpdateLauncher? launcher,
    AppAssetApplier? assetApplier,
    Future<String> Function()? currentVersionLoader,
    Future<String> Function()? platformLoader,
  }) : _service = service ?? AppUpdateService(),
       _settings = settings ?? const AppUpdateSettings(),
       _launcher = launcher ?? const AppUpdateLauncher(),
       _assetApplier = assetApplier ?? const AppAssetApplier(),
       _versionLoader = currentVersionLoader ?? loadVersionFromPackageInfo,
       _platformLoader = platformLoader ?? loadPlatform;

  final AppUpdateService _service;
  final AppUpdateSettings _settings;
  final AppUpdateLauncher _launcher;
  final AppAssetApplier _assetApplier;
  final Future<String> Function() _versionLoader;
  final Future<String> Function() _platformLoader;

  AppUpdateManifest? _manifest;
  AppUpdateDecision _decision = AppUpdateDecision.none;
  String _currentVersion = '';
  String _currentPlatform = 'android';
  bool _isChecking = false;
  bool _isApplying = false;
  bool _isApplyingAssets = false;
  bool _notificationsEnabled = true;
  bool _promptPending = false;
  double _applyProgress = 0;
  String? _message;

  /// 当前判定结论。
  AppUpdateDecision get decision => _decision;

  /// 本机安装的版本号（来自 package_info）。
  String get currentVersion => _currentVersion;

  /// 正在检查更新。
  bool get isChecking => _isChecking;

  /// 正在下载/安装。
  bool get isApplying => _isApplying;

  /// 是否允许大版本弹窗提醒。
  bool get notificationsEnabled => _notificationsEnabled;

  /// 下载进度 0~1（仅应用内下载时有意义）。
  double get applyProgress => _applyProgress;

  /// 一次性的可读反馈（检查结果、失败原因），由 UI 取走后应调用 [clearMessage]。
  String? get message => _message;

  /// 是否存在可用更新。
  bool get hasUpdate => _decision.hasUpdate;

  /// 是否有待弹出的更新提示。
  bool get promptPending => _promptPending;

  /// 当前平台对应的下载产物；没有则为 null。
  AppDownloadTarget? get downloadTarget {
    final release = _decision.release;
    if (release == null) return null;
    return release.downloads[_currentPlatform];
  }

  /// 更新说明（逐行）。
  List<String> get releaseNotes => _decision.release?.notes ?? const [];

  /// 读取当前版本号与本地开关。应用启动时调用一次。
  Future<void> initialize() async {
    try {
      _currentVersion = await _versionLoader();
      _currentPlatform = await _platformLoader();
      _notificationsEnabled = await _settings.notificationsEnabled();
    } catch (error, stack) {
      AppLogger.warn('AppUpdateProvider', '读取版本信息失败', error, stack);
    }
    notifyListeners();
  }

  /// 冷启动 / 回到前台时调用：**只有超过间隔才真正发请求**。
  ///
  /// 版本检查走的是公共 CDN，没必要每次启动都打一次。
  /// 检查完若只有资源热更新，会顺手静默应用（不弹窗、不打扰用户）。
  Future<void> checkIfDue() async {
    if (await _settings.isAutoCheckDue()) {
      await check();
      await applyPendingAssetsSilently();
    }
  }

  /// 检查更新。
  ///
  /// [manual] 表示用户主动点击「检查更新」：此时不再受「跳过此版本」影响，
  /// 否则用户点了按钮却什么反馈都没有，体验很怪。
  Future<void> check({bool manual = false}) async {
    if (_isChecking) return;
    _isChecking = true;
    _message = null;
    notifyListeners();

    try {
      if (_currentVersion.isEmpty) {
        _currentVersion = await _versionLoader();
        _currentPlatform = await _platformLoader();
      }
      final manifest = await _service.tryFetchManifest();
      if (manifest != null) _manifest = manifest;
      await _recompute(manual: manual);
      await _settings.markChecked();

      if (manual) {
        _message = _decision.hasUpdate
            ? '发现新版本 ${_decision.release?.version ?? ''}'.trim()
            : '已是最新版本（$_currentVersion）';
      }
    } catch (error, stack) {
      AppLogger.warn('AppUpdateProvider', '检查更新失败', error, stack);
      if (manual) _message = '检查更新失败，请稍后重试';
    } finally {
      _isChecking = false;
      notifyListeners();
    }
  }

  /// 用当前缓存重新判定（开关变化时无需重新联网）。
  Future<void> _recompute({bool manual = false}) async {
    final ignored = manual ? null : await _settings.ignoredVersion();
    _decision = AppUpdateDecider.decide(
      manifest: _manifest,
      currentVersion: _currentVersion,
      platform: _currentPlatform,
      currentAssetBuild: await _settings.assetBuild(),
      ignoredVersion: ignored,
      notificationsDisabled: !_notificationsEnabled,
    );
    _promptPending = _decision.shouldPrompt;
  }

  /// 静默应用资源热更新（如果有）。
  ///
  /// 设计取向：资源热更**完全不打扰用户**——不弹窗、不出提示、失败也不报错，
  /// 只在日志里留痕，下次检查时自然重试。这符合它「后台修补资源」的定位。
  ///
  /// 应用成功后才写回 `assetBuild`，避免失败时把构建号推进到「已应用」状态
  /// 而导致该资源包被永久跳过。
  Future<void> applyPendingAssetsSilently() async {
    if (_isApplyingAssets) return;
    final assets = _decision.assets;
    if (assets == null) return;

    _isApplyingAssets = true;
    try {
      await _assetApplier.apply(assets);
      await _settings.setAssetBuild(assets.build);
      // 构建号变了，重新判定一次：资源已是最新则不再重复出现在结论里。
      await _recompute();
    } catch (error, stack) {
      AppLogger.warn('AppUpdateProvider', '资源热更新应用失败（下次检查会重试）', error, stack);
    } finally {
      _isApplyingAssets = false;
      notifyListeners();
    }
  }

  /// 用户点了「稍后」：本次不再弹，下次启动仍会提醒。
  void dismissPrompt() {
    if (!_promptPending) return;
    _promptPending = false;
    notifyListeners();
  }

  /// 用户点了「跳过此版本」：只跳过这一个版本，下个版本还会提醒。
  Future<void> ignoreCurrentVersion() async {
    final version = _decision.release?.version;
    if (version != null) {
      await _settings.setIgnoredVersion(version);
    }
    _promptPending = false;
    await _recompute();
    notifyListeners();
  }

  /// 开关「大版本更新提醒」。
  Future<void> setNotificationsEnabled(bool enabled) async {
    if (_notificationsEnabled == enabled) return;
    _notificationsEnabled = enabled;
    notifyListeners();
    await _settings.setNotificationsEnabled(enabled);
    await _recompute();
    notifyListeners();
  }

  /// 执行更新：下载并调起安装器，或打开下载页。
  Future<AppUpdateLaunchResult> applyUpdate() async {
    if (_isApplying) return AppUpdateLaunchResult.failed;
    final target = downloadTarget;
    if (target == null) {
      _message = '当前平台没有可用的安装包';
      notifyListeners();
      return AppUpdateLaunchResult.failed;
    }

    _isApplying = true;
    _applyProgress = 0;
    _message = null;
    notifyListeners();

    try {
      final result = await _launcher.apply(
        target,
        onProgress: (progress) {
          // 与游戏下载同理：按整数百分比去重，避免每个数据块都重建界面。
          if ((progress * 100).floor() == (_applyProgress * 100).floor()) return;
          _applyProgress = progress;
          notifyListeners();
        },
      );
      if (result == AppUpdateLaunchResult.failed) {
        _message = '打开下载页失败，请稍后重试';
      }
      return result;
    } on AppUpdateException catch (error) {
      _message = error.message;
      return AppUpdateLaunchResult.failed;
    } catch (error, stack) {
      AppLogger.warn('AppUpdateProvider', '应用更新失败', error, stack);
      _message = '更新失败，请稍后重试';
      return AppUpdateLaunchResult.failed;
    } finally {
      _isApplying = false;
      notifyListeners();
    }
  }

  /// UI 展示过一次反馈后清掉它，避免重复弹出。
  void clearMessage() {
    if (_message == null) return;
    _message = null;
    notifyListeners();
  }

  /// 通过 package_info 读取本机版本号。
  static Future<String> loadVersionFromPackageInfo() async {
    final info = await PackageInfo.fromPlatform();
    return info.version;
  }

  /// 当前平台标识，与 `update.json` 里 downloads 的 key 对应。
  static Future<String> loadPlatform() async {
    if (kIsWeb) return 'web';
    if (Platform.isAndroid) return 'android';
    if (Platform.isIOS) return 'ios';
    if (Platform.isWindows) return 'windows';
    if (Platform.isMacOS) return 'macos';
    if (Platform.isLinux) return 'linux';
    return 'unknown';
  }
}
