import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:workmanager/workmanager.dart';

import '../../utils/app_logger.dart';
import '../models/app_update_decision.dart';
import 'app_update_decider.dart';
import 'app_update_service.dart';
import 'app_update_settings.dart';

/// 后台版本检查：App 不在前台时也能周期性发现新版本并发本地通知。
///
/// 实现选型（为什么是 WorkManager 而不是真推送）：
/// - 项目没有后端，FCM 在国内无 GMS 的手机上基本不可用，自建推送服务器更不可能；
/// - WorkManager 是 Android 系统自带的周期任务调度（JobScheduler/Alarm 兜底），
///   **免费、无后端、无账号**；系统会按网络/电量情况弹性执行（标称 1 小时，
///   实际可能被厂商 ROM 推迟，深度定制系统上甚至可能被省电策略杀掉）。
///
/// 它做的事：在后台 isolate 拉清单 → 纯函数决策 → 命中新版本发**本地通知**。
/// 用户点通知只是拉起 App，弹窗/下载/安装仍由前台既有链路完成
/// （见 [AppUpdateProvider]）。同一版本只通知一次。
class BackgroundUpdateWorker {
  const BackgroundUpdateWorker._();

  static const String taskName = 'v5.appUpdate.periodicCheck';
  static const String taskUniqueId = 'v5-app-update-periodic-check';

  static const String channelId = 'app_update';
  static const String channelName = '应用更新';
  static const int notificationId = 0x7605; // 'v5' 语义，随意固定值

  /// 注册周期任务。重复调用安全（keepExisting，不会堆出多个任务）。
  ///
  /// 仅在 Android 注册：iOS 的后台刷新由系统严格控制且本 App 的更新落地
  /// 本来就只能跳 App Store，前台检查已足够。
  static Future<void> register() async {
    if (Platform.isAndroid) {
      await Workmanager().initialize(
        updateCheckCallbackDispatcher,
      );
      await Workmanager().registerPeriodicTask(
        taskUniqueId,
        taskName,
        frequency: const Duration(hours: 1),
        // update：已存在同 uniqueId 的任务时不重复创建，但会让新参数生效
        // （将来调整频率/约束后，老用户升级即生效，不必等系统删掉旧任务）。
        existingWorkPolicy: ExistingPeriodicWorkPolicy.update,
        constraints: Constraints(networkType: NetworkType.connected),
      );
    }
  }

  /// Android 13+ 通知运行时权限。
  ///
  /// 用户拒绝过后不再弹系统框（系统行为），返回 false；调用方据此决定
  /// 是否只做静默后台检查（检查照常，只是不发通知）。
  static Future<bool> ensureNotificationPermission() async {
    if (!Platform.isAndroid) return true;
    final android = FlutterLocalNotificationsPlugin()
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    final granted = await android?.requestNotificationsPermission();
    return granted ?? false;
  }
}

/// 后台任务的纯逻辑闸门：这次检查结果是否应该发通知。
///
/// 抽成纯函数是因为后台 isolate 里的真实调度无法在单元测试中复现，
/// 至少把「该不该打扰」这部分判定做到可测。
///
/// 规则：
/// - 决策必须要求弹窗（[AppUpdateDecision.shouldPrompt]），与前台同一把尺；
/// - 用户「关闭提醒」「跳过此版本」时前台本就不弹窗，后台更不该发通知
///   （这两种状态已在 [AppUpdateDecider] 内降级，shouldPrompt 为 false）；
/// - 同一版本只通知一次（[lastNotifiedVersion]）。
bool shouldNotifyInBackground({
  required AppUpdateDecision? decision,
  required String? lastNotifiedVersion,
}) {
  if (decision == null || !decision.shouldPrompt) return false;
  final version = decision.release?.version;
  if (version == null || version.isEmpty) return false;
  if (version == lastNotifiedVersion) return false;
  return true;
}

/// WorkManager 后台 isolate 的入口。必须是顶层函数 + `vm:entry-point`。
@pragma('vm:entry-point')
void updateCheckCallbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    WidgetsFlutterBinding.ensureInitialized();
    try {
      await _runBackgroundCheck();
    } catch (error, stack) {
      // 后台任务里出错只能记日志；返回 true 表示「任务已处理」，
      // 让系统按周期继续调度，而不是退避重试把电量打光。
      AppLogger.warn('BackgroundUpdateWorker', '后台检查失败', error, stack);
    }
    return true;
  });
}

Future<void> _runBackgroundCheck() async {
  final settings = const AppUpdateSettings();
  final env = await settings.readEnvironmentSnapshot();
  if (env.version.isEmpty) {
    // App 尚未完成过一次前台初始化，没有版本基线，没法判断新旧。
    return;
  }

  final manifest = await AppUpdateService().tryFetchManifest();
  if (manifest == null) return;

  final decision = AppUpdateDecider.decide(
    manifest: manifest,
    currentVersion: env.version,
    platform: env.platform,
    abi: env.abi,
    currentAssetBuild: await settings.assetBuild(),
    ignoredVersion: await settings.ignoredVersion(),
    notificationsDisabled: !(await settings.notificationsEnabled()),
  );

  final lastNotified = await settings.lastNotifiedVersion();
  if (!shouldNotifyInBackground(
    decision: decision,
    lastNotifiedVersion: lastNotified,
  )) {
    return;
  }

  final version = decision.release!.version;
  await _showUpdateNotification(version, decision.release!.notes);
  await settings.setLastNotifiedVersion(version);
}

Future<void> _showUpdateNotification(
  String version,
  List<String> notes,
) async {
  final plugin = FlutterLocalNotificationsPlugin();
  await plugin.initialize(
    const InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(),
    ),
  );

  await plugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >()
      ?.createNotificationChannel(
        const AndroidNotificationChannel(
          BackgroundUpdateWorker.channelId,
          BackgroundUpdateWorker.channelName,
          description: '有新版本可用时提醒',
          importance: Importance.high,
        ),
      );

  final body = notes.isNotEmpty
      ? notes.first
      : '检测到新版本 $version，点击查看更新';
  await plugin.show(
    BackgroundUpdateWorker.notificationId,
    '发现新版本 $version',
    body,
    const NotificationDetails(
      android: AndroidNotificationDetails(
        BackgroundUpdateWorker.channelId,
        BackgroundUpdateWorker.channelName,
        importance: Importance.high,
        priority: Priority.high,
      ),
      iOS: DarwinNotificationDetails(),
    ),
  );
}
