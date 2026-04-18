import 'dart:async';
import 'package:flutter/material.dart';
import '../modules/pomodoro/models/pomodoro_model.dart';
import '../modules/pomodoro/repositories/pomodoro_repository.dart';
import '../modules/pomodoro/adapters/pomodoro_statistic_adapter.dart';

/// 番茄钟状态管理Provider
/// 负责番茄钟计时、设置、记录和统计
class PomodoroProvider extends ChangeNotifier {
  final PomodoroRepository _repository = PomodoroRepository();
  final PomodoroStatisticAdapter _statisticAdapter = PomodoroStatisticAdapter();

  Timer? _timer;
  DateTime? _startTime;

  PomodoroSettings _settings = const PomodoroSettings();
  PomodoroMode _mode = PomodoroMode.work;
  int _remainingSeconds = 25 * 60;
  int _elapsedSeconds = 0;
  bool _isRunning = false;
  int _completedPomodoros = 0;
  int _sessionPomodoros = 0;

  int? _relatedTaskId;
  String? _relatedTaskTitle;

  List<PomodoroRecord> _todayRecords = [];
  PomodoroStatistics _statistics = const PomodoroStatistics();

  PomodoroSettings get settings => _settings;
  PomodoroMode get mode => _mode;
  int get remainingSeconds => _remainingSeconds;
  int get elapsedSeconds => _elapsedSeconds;
  bool get isRunning => _isRunning;
  int get completedPomodoros => _completedPomodoros;
  int get sessionPomodoros => _sessionPomodoros;
  int? get relatedTaskId => _relatedTaskId;
  String? get relatedTaskTitle => _relatedTaskTitle;
  List<PomodoroRecord> get todayRecords => _todayRecords;
  PomodoroStatistics get statistics => _statistics;

  double get progress {
    final total = _settings.getDurationForMode(_mode);
    if (total == 0) return 0;
    return 1 - (_remainingSeconds / total);
  }

  String get formattedTime {
    final minutes = _remainingSeconds ~/ 60;
    final seconds = _remainingSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  /// 初始化Provider
  Future<void> initialize() async {
    await _loadSettings();
    await _loadStatistics();
    await _loadTodayRecords();
  }

  Future<void> _loadSettings() async {
    try {
      _settings = await _repository.getSettings();
      _remainingSeconds = _settings.getDurationForMode(_mode);
      notifyListeners();
    } catch (e) {
      debugPrint('Load pomodoro settings failed: $e');
    }
  }

  Future<void> _loadStatistics() async {
    try {
      _statistics = await _repository.getStatistics();
      _completedPomodoros = _statistics.todayPomodoros;
      notifyListeners();
    } catch (e) {
      debugPrint('Load pomodoro statistics failed: $e');
    }
  }

  Future<void> _loadTodayRecords() async {
    try {
      _todayRecords = await _repository.getRecordsByDate(DateTime.now());
      notifyListeners();
    } catch (e) {
      debugPrint('Load today records failed: $e');
    }
  }

  /// 开始计时
  void startTimer() {
    if (_isRunning) return;

    _isRunning = true;
    _startTime = DateTime.now();
    _startTick();

    _statisticAdapter.reportPomodoroStart(_mode);
    notifyListeners();
  }

  void _startTick() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingSeconds > 0) {
        _remainingSeconds--;
        _elapsedSeconds++;
        notifyListeners();
      } else {
        _onTimerComplete();
      }
    });
  }

  /// 暂停计时
  void pauseTimer() {
    if (!_isRunning) return;

    _timer?.cancel();
    _isRunning = false;
    _statisticAdapter.reportPomodoroPause(_mode);
    notifyListeners();
  }

  /// 继续计时
  void resumeTimer() {
    if (_isRunning) return;

    _isRunning = true;
    _startTick();
    notifyListeners();
  }

  /// 重置计时
  Future<void> resetTimer({bool saveRecord = false}) async {
    _timer?.cancel();

    if (saveRecord && _elapsedSeconds > 0) {
      await _saveRecord(isCompleted: false);
    }

    _isRunning = false;
    _elapsedSeconds = 0;
    _remainingSeconds = _settings.getDurationForMode(_mode);
    _startTime = null;

    _statisticAdapter.reportPomodoroReset(_mode);
    notifyListeners();
  }

  /// 跳过当前阶段
  Future<void> skipPhase() async {
    await _onTimerComplete(isSkipped: true);
  }

  Future<void> _onTimerComplete({bool isSkipped = false}) async {
    _timer?.cancel();
    _isRunning = false;

    final isCompleted = !isSkipped && _remainingSeconds == 0;

    await _saveRecord(isCompleted: isCompleted);

    if (_mode == PomodoroMode.work && isCompleted) {
      _completedPomodoros++;
      _sessionPomodoros++;

      _statisticAdapter.reportPomodoroComplete(
        _settings.workDuration,
        _relatedTaskId,
      );

      if (_sessionPomodoros % _settings.longBreakInterval == 0) {
        _switchMode(PomodoroMode.longBreak);
      } else {
        _switchMode(PomodoroMode.shortBreak);
      }

      if (_settings.autoStartBreak) {
        startTimer();
      }
    } else if (_mode != PomodoroMode.work) {
      _switchMode(PomodoroMode.work);

      if (_settings.autoStartWork) {
        startTimer();
      }
    } else {
      _switchMode(PomodoroMode.work);
    }

    await _loadStatistics();
    await _loadTodayRecords();

    notifyListeners();
  }

  Future<void> _saveRecord({required bool isCompleted}) async {
    if (_startTime == null) return;

    final record = PomodoroRecord(
      mode: _mode,
      durationSeconds: _settings.getDurationForMode(_mode),
      actualSeconds: _elapsedSeconds,
      startTime: _startTime!,
      endTime: DateTime.now(),
      relatedTaskId: _relatedTaskId,
      relatedTaskTitle: _relatedTaskTitle,
      isCompleted: isCompleted,
    );

    try {
      await _repository.addRecord(record);
    } catch (e) {
      debugPrint('Save pomodoro record failed: $e');
    }
  }

  /// 切换模式
  void switchMode(PomodoroMode newMode) {
    if (_isRunning) return;
    _switchMode(newMode);
    notifyListeners();
  }

  void _switchMode(PomodoroMode newMode) {
    _mode = newMode;
    _remainingSeconds = _settings.getDurationForMode(newMode);
    _elapsedSeconds = 0;
    _startTime = null;
  }

  /// 设置关联任务
  void setRelatedTask(int? taskId, String? taskTitle) {
    _relatedTaskId = taskId;
    _relatedTaskTitle = taskTitle;
    notifyListeners();
  }

  /// 清除关联任务
  void clearRelatedTask() {
    _relatedTaskId = null;
    _relatedTaskTitle = null;
    notifyListeners();
  }

  /// 更新设置
  Future<void> updateSettings(PomodoroSettings newSettings) async {
    _settings = newSettings;

    try {
      await _repository.saveSettings(newSettings);

      if (!_isRunning) {
        _remainingSeconds = newSettings.getDurationForMode(_mode);
      }

      _statisticAdapter.reportSettingsChanged();
      notifyListeners();
    } catch (e) {
      debugPrint('Save pomodoro settings failed: $e');
    }
  }

  /// 获取历史记录
  Future<List<PomodoroRecord>> getHistoryRecords({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    if (startDate != null && endDate != null) {
      return await _repository.getRecordsByDateRange(startDate, endDate);
    }
    return await _repository.getAllRecords();
  }

  /// 删除记录
  Future<void> deleteRecord(int id) async {
    try {
      await _repository.deleteRecord(id);
      await _loadStatistics();
      await _loadTodayRecords();
      notifyListeners();
    } catch (e) {
      debugPrint('Delete pomodoro record failed: $e');
    }
  }

  /// 清空所有记录
  Future<void> clearAllRecords() async {
    try {
      await _repository.clearRecords();
      _completedPomodoros = 0;
      _sessionPomodoros = 0;
      await _loadStatistics();
      await _loadTodayRecords();
      notifyListeners();
    } catch (e) {
      debugPrint('Clear pomodoro records failed: $e');
    }
  }

  /// 刷新统计数据
  Future<void> refreshStatistics() async {
    await _loadStatistics();
    await _loadTodayRecords();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
