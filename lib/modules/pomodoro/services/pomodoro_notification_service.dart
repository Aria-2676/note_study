import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:vibration/vibration.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../models/pomodoro_model.dart';

/// 番茄钟提醒服务
/// 负责音效、震动和通知提醒
class PomodoroNotificationService {
  static final PomodoroNotificationService _instance =
      PomodoroNotificationService._internal();
  factory PomodoroNotificationService() => _instance;
  PomodoroNotificationService._internal();

  final AudioPlayer _audioPlayer = AudioPlayer();
  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  static bool _initialized = false;

  /// 初始化通知服务
  static Future<void> init() async {
    if (_initialized) return;

    try {
      final instance = PomodoroNotificationService();
      await instance._initNotifications();
      _initialized = true;
      debugPrint('PomodoroNotificationService initialized successfully');
    } catch (e, stack) {
      debugPrint('PomodoroNotificationService init failed: $e\n$stack');
    }
  }

  Future<void> _initNotifications() async {
    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notifications.initialize(
      settings,
      onDidReceiveNotificationResponse: (response) {
        debugPrint('Notification tapped: ${response.payload}');
      },
    );
  }

  /// 播放提示音
  Future<void> playSound() async {
    try {
      await _audioPlayer.play(AssetSource('sounds/pomodoro_complete.mp3'));
    } catch (e) {
      debugPrint('Play sound failed: $e');
      await _playSystemSound();
    }
  }

  Future<void> _playSystemSound() async {
    try {
      await _audioPlayer.play(
        UrlSource(
          'https://assets.mixkit.co/active_storage/s/2869/2869-preview.mp3',
        ),
      );
    } catch (e) {
      debugPrint('Play system sound failed: $e');
    }
  }

  /// 震动提醒
  Future<void> vibrate() async {
    try {
      final hasVibrator = await Vibration.hasVibrator();
      if (hasVibrator == true) {
        await Vibration.vibrate(pattern: [0, 500, 200, 500]);
      }
    } catch (e) {
      debugPrint('Vibration failed: $e');
    }
  }

  /// 发送通知
  Future<void> showNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    try {
      const androidDetails = AndroidNotificationDetails(
        'pomodoro_channel',
        '番茄钟提醒',
        channelDescription: '番茄钟计时结束提醒',
        importance: Importance.high,
        priority: Priority.high,
        showWhen: true,
      );

      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      const details = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      await _notifications.show(
        DateTime.now().millisecondsSinceEpoch ~/ 1000,
        title,
        body,
        details,
        payload: payload,
      );
    } catch (e) {
      debugPrint('Show notification failed: $e');
    }
  }

  /// 发送阶段完成提醒
  Future<void> notifyPhaseComplete(PomodoroMode mode) async {
    final title = mode == PomodoroMode.work ? '专注时间结束' : '休息时间结束';
    final body = mode == PomodoroMode.work ? '做得很好！休息一下吧' : '休息结束，准备开始新的专注';

    await showNotification(title: title, body: body);
  }

  /// 发送所有提醒
  Future<void> notifyAll({
    required bool soundEnabled,
    required bool vibrationEnabled,
    required bool notificationEnabled,
    PomodoroMode? mode,
  }) async {
    if (soundEnabled) {
      await playSound();
    }

    if (vibrationEnabled) {
      await vibrate();
    }

    if (notificationEnabled && mode != null) {
      await notifyPhaseComplete(mode);
    }
  }

  /// 取消所有通知
  Future<void> cancelAllNotifications() async {
    await _notifications.cancelAll();
  }

  /// 释放资源
  Future<void> dispose() async {
    await _audioPlayer.dispose();
  }
}
