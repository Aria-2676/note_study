import '../../../core/services/database/database_service.dart';
import '../models/pomodoro_model.dart';

/// 番茄钟数据仓储
/// 负责番茄钟记录和设置的增删改查操作
class PomodoroRepository {
  final DatabaseService _dbService = DatabaseService.instance;

  /// 添加番茄钟记录
  Future<int> addRecord(PomodoroRecord record) async {
    return await _dbService.insertPomodoroRecord(record);
  }

  /// 获取所有番茄钟记录
  Future<List<PomodoroRecord>> getAllRecords() async {
    return await _dbService.getAllPomodoroRecords();
  }

  /// 获取指定日期的番茄钟记录
  Future<List<PomodoroRecord>> getRecordsByDate(DateTime date) async {
    return await _dbService.getPomodoroRecordsByDate(date);
  }

  /// 获取日期范围内的番茄钟记录
  Future<List<PomodoroRecord>> getRecordsByDateRange(
    DateTime start,
    DateTime end,
  ) async {
    return await _dbService.getPomodoroRecordsByDateRange(start, end);
  }

  /// 获取关联任务的番茄钟记录
  Future<List<PomodoroRecord>> getRecordsByTaskId(int taskId) async {
    return await _dbService.getPomodoroRecordsByTaskId(taskId);
  }

  /// 删除番茄钟记录
  Future<void> deleteRecord(int id) async {
    await _dbService.deletePomodoroRecord(id);
  }

  /// 清空所有番茄钟记录
  Future<void> clearRecords() async {
    await _dbService.clearPomodoroRecords();
  }

  /// 获取番茄钟统计数据
  Future<PomodoroStatistics> getStatistics() async {
    final totalPomodoros = await _dbService.getTotalPomodoroCount();
    final totalFocusMinutes = await _dbService.getTotalFocusMinutes();
    final todayPomodoros = await _dbService.getTodayPomodoroCount();
    final todayFocusMinutes = await _dbService.getTodayFocusMinutes();
    final weekPomodoros = await _dbService.getWeekPomodoroCount();
    final weekFocusMinutes = await _dbService.getWeekFocusMinutes();
    final taskFocusMinutes = await _dbService.getTaskFocusMinutes();

    return PomodoroStatistics(
      totalPomodoros: totalPomodoros,
      totalFocusMinutes: totalFocusMinutes,
      todayPomodoros: todayPomodoros,
      todayFocusMinutes: todayFocusMinutes,
      weekPomodoros: weekPomodoros,
      weekFocusMinutes: weekFocusMinutes,
      taskFocusMinutes: taskFocusMinutes,
    );
  }

  /// 获取今日番茄钟数量
  Future<int> getTodayCount() async {
    return await _dbService.getTodayPomodoroCount();
  }

  /// 获取今日专注分钟数
  Future<int> getTodayFocusMinutes() async {
    return await _dbService.getTodayFocusMinutes();
  }

  /// 获取本周专注分钟数
  Future<int> getWeekFocusMinutes() async {
    return await _dbService.getWeekFocusMinutes();
  }

  /// 获取本周番茄钟数量
  Future<int> getWeekCount() async {
    return await _dbService.getWeekPomodoroCount();
  }

  /// 获取番茄钟设置
  Future<PomodoroSettings> getSettings() async {
    return await _dbService.getPomodoroSettings();
  }

  /// 保存番茄钟设置
  Future<void> saveSettings(PomodoroSettings settings) async {
    await _dbService.savePomodoroSettings(settings);
  }
}
