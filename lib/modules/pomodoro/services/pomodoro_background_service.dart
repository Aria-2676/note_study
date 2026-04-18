import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/pomodoro_model.dart';

/// 番茄钟后台服务
/// 负责后台计时、状态保存和恢复
class PomodoroBackgroundService {
  static final PomodoroBackgroundService _instance =
      PomodoroBackgroundService._internal();
  factory PomodoroBackgroundService() => _instance;
  PomodoroBackgroundService._internal();

  static const String _keyRemainingSeconds = 'pomodoro_remaining_seconds';
  static const String _keyElapsedSeconds = 'pomodoro_elapsed_seconds';
  static const String _keyMode = 'pomodoro_mode';
  static const String _keyStartTime = 'pomodoro_start_time';
  static const String _keyIsRunning = 'pomodoro_is_running';
  static const String _keyRelatedTaskId = 'pomodoro_related_task_id';
  static const String _keyRelatedTaskTitle = 'pomodoro_related_task_title';

  Timer? _backgroundTimer;
  int _remainingSeconds = 0;
  int _elapsedSeconds = 0;
  PomodoroMode _mode = PomodoroMode.work;
  bool _isRunning = false;
  DateTime? _startTime;
  int? _relatedTaskId;
  String? _relatedTaskTitle;

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  static bool _initialized = false;

  /// 初始化后台服务
  static Future<void> init() async {
    if (_initialized) return;

    try {
      final instance = PomodoroBackgroundService();
      await instance._initNotifications();
      await instance._restoreState();
      _initialized = true;
      debugPrint('PomodoroBackgroundService initialized successfully');
    } catch (e, stack) {
      debugPrint('PomodoroBackgroundService init failed: $e\n$stack');
    }
  }

  Future<void> _initNotifications() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notifications.initialize(settings);
  }

  /// 保存当前状态
  Future<void> saveState({
    required int remainingSeconds,
    required int elapsedSeconds,
    required PomodoroMode mode,
    required bool isRunning,
    DateTime? startTime,
    int? relatedTaskId,
    String? relatedTaskTitle,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_keyRemainingSeconds, remainingSeconds);
      await prefs.setInt(_keyElapsedSeconds, elapsedSeconds);
      await prefs.setString(_keyMode, mode.name);
      await prefs.setBool(_keyIsRunning, isRunning);
      await prefs.setInt(_keyRelatedTaskId, relatedTaskId ?? -1);
      await prefs.setString(_keyRelatedTaskTitle, relatedTaskTitle ?? '');
      if (startTime != null) {
        await prefs.setString(_keyStartTime, startTime.toIso8601String());
      }
    } catch (e) {
      debugPrint('Save pomodoro state failed: $e');
    }
  }

  /// 恢复状态
  Future<Map<String, dynamic>?> restoreState() async {
    return await _restoreState();
  }

  Future<Map<String, dynamic>?> _restoreState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final isRunning = prefs.getBool(_keyIsRunning) ?? false;

      if (!isRunning) return null;

      final remainingSeconds = prefs.getInt(_keyRemainingSeconds) ?? 0;
      final elapsedSeconds = prefs.getInt(_keyElapsedSeconds) ?? 0;
      final modeName = prefs.getString(_keyMode) ?? 'work';
      final startTimeStr = prefs.getString(_keyStartTime);
      final relatedTaskId = prefs.getInt(_keyRelatedTaskId);
      final relatedTaskTitle = prefs.getString(_keyRelatedTaskTitle);

      _remainingSeconds = remainingSeconds;
      _elapsedSeconds = elapsedSeconds;
      _mode = PomodoroMode.values.firstWhere(
        (e) => e.name == modeName,
        orElse: () => PomodoroMode.work,
      );
      _isRunning = isRunning;
      _startTime = startTimeStr != null
          ? DateTime.tryParse(startTimeStr)
          : null;
      _relatedTaskId = relatedTaskId != null && relatedTaskId > 0
          ? relatedTaskId
          : null;
      _relatedTaskTitle = relatedTaskTitle?.isNotEmpty == true
          ? relatedTaskTitle
          : null;

      if (_startTime != null && _isRunning) {
        final elapsedSinceStart = DateTime.now().difference(_startTime!).inSeconds;
        _remainingSeconds = (_remainingSeconds - elapsedSinceStart).clamp(0, _remainingSeconds);
        _elapsedSeconds += elapsedSinceStart;

        if (_remainingSeconds <= 0) {
          _remainingSeconds = 0;
          _isRunning = false;
        }
      }

      return {
        'remainingSeconds': _remainingSeconds,
        'elapsedSeconds': _elapsedSeconds,
        'mode': _mode,
        'isRunning': _isRunning,
        'startTime': _startTime,
        'relatedTaskId': _relatedTaskId,
        'relatedTaskTitle': _relatedTaskTitle,
      };
    } catch (e) {
      debugPrint('Restore pomodoro state failed: $e');
      return null;
    }
  }

  /// 清除保存的状态
  Future<void> clearState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyRemainingSeconds);
      await prefs.remove(_keyElapsedSeconds);
      await prefs.remove(_keyMode);
      await prefs.remove(_keyStartTime);
      await prefs.remove(_keyIsRunning);
      await prefs.remove(_keyRelatedTaskId);
      await prefs.remove(_keyRelatedTaskTitle);
    } catch (e) {
      debugPrint('Clear pomodoro state failed: $e');
    }
  }

  /// 开始后台计时
  void startBackgroundTimer({
    required int remainingSeconds,
    required PomodoroMode mode,
    required Function() onComplete,
    required Function(int) onTick,
  }) {
    _remainingSeconds = remainingSeconds;
    _mode = mode;
    _isRunning = true;
    _startTime = DateTime.now();

    _backgroundTimer?.cancel();
    _backgroundTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingSeconds > 0) {
        _remainingSeconds--;
        _elapsedSeconds++;
        onTick(_remainingSeconds);

        if (_remainingSeconds % 60 == 0) {
          _updateNotification();
        }
      } else {
        stopBackgroundTimer();
        onComplete();
      }
    });

    _showForegroundNotification();
  }

  /// 停止后台计时
  void stopBackgroundTimer() {
    _backgroundTimer?.cancel();
    _backgroundTimer = null;
    _isRunning = false;
    _cancelNotification();
  }

  /// 显示前台通知
  Future<void> _showForegroundNotification() async {
    if (!Platform.isAndroid) return;

    const androidDetails = AndroidNotificationDetails(
      'pomodoro_foreground',
      '番茄钟计时',
      channelDescription: '番茄钟后台计时通知',
      importance: Importance.low,
      priority: Priority.low,
      ongoing: true,
      showWhen: false,
    );

    const details = NotificationDetails(android: androidDetails);

    await _notifications.show(
      8888,
      '番茄钟运行中',
      '${_mode.displayName} - ${_formatTime(_remainingSeconds)}',
      details,
    );
  }

  /// 更新通知
  Future<void> _updateNotification() async {
    if (!_isRunning) return;
    await _showForegroundNotification();
  }

  /// 取消通知
  Future<void> _cancelNotification() async {
    await _notifications.cancel(8888);
  }

  String _formatTime(int seconds) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  /// 获取当前状态
  Map<String, dynamic> get currentState => {
        'remainingSeconds': _remainingSeconds,
        'elapsedSeconds': _elapsedSeconds,
        'mode': _mode,
        'isRunning': _isRunning,
        'startTime': _startTime,
        'relatedTaskId': _relatedTaskId,
        'relatedTaskTitle': _relatedTaskTitle,
      };

  /// 是否正在运行
  bool get isRunning => _isRunning;

  /// 释放资源
  void dispose() {
    _backgroundTimer?.cancel();
    _cancelNotification();
  }
}
