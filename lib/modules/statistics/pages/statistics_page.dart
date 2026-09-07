import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/task_provider.dart';
import '../../../providers/points_provider.dart';
import '../../../providers/pomodoro_provider.dart';
import '../../../providers/scratch_provider.dart';
import '../../tasks/models/task_model.dart';
import '../../scratch/models/scratch_model.dart';
import '../../calendar/pages/calendar_page.dart';
import './widgets/today_overview_widget.dart';
import './widgets/view_selector_widget.dart';
import './widgets/task_statistics_widget.dart';
import './widgets/points_statistics_widget.dart';
import './widgets/pomodoro_statistics_widget.dart';
import './widgets/scratch_statistics_widget.dart';

enum StatisticsModule { task, points, pomodoro, scratch }

class StatisticsPage extends StatefulWidget {
  final DateTime? selectedDate;

  const StatisticsPage({super.key, this.selectedDate});

  @override
  State<StatisticsPage> createState() => _StatisticsPageState();
}

class _StatisticsPageState extends State<StatisticsPage> {
  StatisticsModule _currentModule = StatisticsModule.task;
  StatisticsView _currentView = StatisticsView.day;
  DateTime? _displayDate;

  final Map<StatisticsModule, String> _moduleNames = {
    StatisticsModule.task: '任务',
    StatisticsModule.points: '积分',
    StatisticsModule.pomodoro: '番茄',
    StatisticsModule.scratch: '刮刮卡',
  };

  @override
  void initState() {
    super.initState();
    _displayDate = widget.selectedDate;
  }

  @override
  Widget build(BuildContext context) {
    final taskProvider = context.watch<TaskProvider>();
    final pointsProvider = context.watch<PointsProvider>();
    final pomodoroProvider = context.watch<PomodoroProvider>();
    final scratchProvider = context.watch<ScratchProvider>();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildHeader(),
        const SizedBox(height: 16),
        TodayOverviewWidget(
          completedToday: _getTodayCompletedTasks(taskProvider.rawTasks),
          totalToday: _getTodayTasks(taskProvider.rawTasks).length,
          todayPoints: _getTodayPoints(taskProvider.rawTasks),
          todayPomodoros: pomodoroProvider.statistics.todayPomodoros,
          todayScratchCount: _getTodayScratchCount(
            scratchProvider.lotteryRecords,
          ),
        ),
        const SizedBox(height: 16),
        ViewSelectorWidget(
          currentView: _currentView,
          onViewChanged: (view) => setState(() {
            _currentView = view;
            _displayDate = null;
          }),
        ),
        const SizedBox(height: 16),
        _buildModuleContent(
          taskProvider,
          pointsProvider,
          pomodoroProvider,
          scratchProvider,
        ),
      ],
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        InkWell(
          onTap: _showModuleSelector,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _buildTitleText(),
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(Icons.keyboard_arrow_down, color: Colors.grey.shade600),
              ],
            ),
          ),
        ),
        TextButton.icon(
          onPressed: () async {
            final result = await Navigator.of(context).push<DateTime>(
              MaterialPageRoute(builder: (_) => const CalendarPage()),
            );
            if (result != null) {
              setState(() {
                _displayDate = result;
                _currentView = StatisticsView.day;
              });
            }
          },
          icon: const Icon(Icons.calendar_today, size: 18),
          label: const Text('日历'),
        ),
      ],
    );
  }

  String _buildTitleText() {
    final moduleName = _moduleNames[_currentModule]!;
    if (_displayDate != null) {
      final month = _displayDate!.month;
      final day = _displayDate!.day;
      return '$moduleName统计-$month.$day';
    }
    return '$moduleName统计';
  }

  void _showModuleSelector() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  '选择统计模块',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                ...StatisticsModule.values.map((module) {
                  final isSelected = module == _currentModule;
                  return ListTile(
                    leading: Icon(
                      _getModuleIcon(module),
                      color: isSelected ? Colors.blue : null,
                    ),
                    title: Text(
                      _moduleNames[module]!,
                      style: TextStyle(
                        fontWeight: isSelected
                            ? FontWeight.bold
                            : FontWeight.normal,
                        color: isSelected ? Colors.blue : null,
                      ),
                    ),
                    trailing: isSelected
                        ? const Icon(Icons.check, color: Colors.blue)
                        : null,
                    onTap: () {
                      setState(() => _currentModule = module);
                      Navigator.of(context).pop();
                    },
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }

  IconData _getModuleIcon(StatisticsModule module) {
    switch (module) {
      case StatisticsModule.task:
        return Icons.task_alt;
      case StatisticsModule.points:
        return Icons.stars;
      case StatisticsModule.pomodoro:
        return Icons.timer;
      case StatisticsModule.scratch:
        return Icons.casino;
    }
  }

  Widget _buildModuleContent(
    TaskProvider taskProvider,
    PointsProvider pointsProvider,
    PomodoroProvider pomodoroProvider,
    ScratchProvider scratchProvider,
  ) {
    switch (_currentModule) {
      case StatisticsModule.task:
        return _buildTaskContent(taskProvider);
      case StatisticsModule.points:
        return _buildPointsContent(pointsProvider);
      case StatisticsModule.pomodoro:
        return _buildPomodoroContent(pomodoroProvider);
      case StatisticsModule.scratch:
        return _buildScratchContent(scratchProvider);
    }
  }

  Widget _buildTaskContent(TaskProvider taskProvider) {
    final allTasks = taskProvider.rawTasks;
    final dateRange = _getDateRange();
    final tasksInRange = _getTasksInRange(allTasks, dateRange);
    final completedTasks = tasksInRange.where((t) => t.isOK).length;
    final totalTasks = tasksInRange.length;
    final completionRate = totalTasks == 0 ? 0.0 : completedTasks / totalTasks;

    return TaskStatisticsWidget(
      tasks: tasksInRange,
      completedTasks: completedTasks,
      totalTasks: totalTasks,
      completionRate: completionRate,
      isDayView: _currentView == StatisticsView.day,
      currentView: _currentView,
      dateRange: dateRange,
    );
  }

  Widget _buildPointsContent(PointsProvider pointsProvider) {
    final records = pointsProvider.records;
    final totalEarned = records
        .where((r) => r.points > 0)
        .fold<int>(0, (sum, r) => sum + r.points);
    final totalSpent = records
        .where((r) => r.points < 0)
        .fold<int>(0, (sum, r) => sum + r.points.abs());

    return PointsStatisticsWidget(
      currentPoints: pointsProvider.currentPoints,
      totalEarned: totalEarned,
      totalSpent: totalSpent,
    );
  }

  Widget _buildPomodoroContent(PomodoroProvider pomodoroProvider) {
    final stats = pomodoroProvider.statistics;
    return PomodoroStatisticsWidget(
      todayFocusMinutes: stats.todayFocusMinutes,
      todayPomodoros: stats.todayPomodoros,
      totalFocusMinutes: stats.totalFocusMinutes,
      totalPomodoros: stats.totalPomodoros,
    );
  }

  Widget _buildScratchContent(ScratchProvider scratchProvider) {
    final records = scratchProvider.lotteryRecords;
    final totalScratchCount = records.length;
    final winCount = records.where((r) => r.prizeValue > 0).length;
    final totalCost = records.fold<int>(0, (sum, r) => sum + r.costPoints);
    final totalWinValue = records.fold<int>(0, (sum, r) => sum + r.prizeValue);

    return ScratchStatisticsWidget(
      totalScratchCount: totalScratchCount,
      winCount: winCount,
      totalCost: totalCost,
      totalWinValue: totalWinValue,
    );
  }

  List<Task> _getTodayTasks(List<Task> tasks) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return tasks.where((task) {
      final taskDate = DateTime(
        task.cplTime.year,
        task.cplTime.month,
        task.cplTime.day,
      );
      return taskDate == today;
    }).toList();
  }

  int _getTodayCompletedTasks(List<Task> tasks) {
    return _getTodayTasks(tasks).where((t) => t.isOK).length;
  }

  int _getTodayPoints(List<Task> tasks) {
    return _getTodayTasks(
      tasks,
    ).where((t) => t.isOK).fold<int>(0, (sum, t) => sum + t.rewardPoints);
  }

  int _getTodayScratchCount(List<LotteryRecord> records) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return records.where((r) {
      final recordDate = DateTime(
        r.drawTime.year,
        r.drawTime.month,
        r.drawTime.day,
      );
      return recordDate == today;
    }).length;
  }

  DateTimeRange _getDateRange() {
    if (_displayDate != null) {
      return DateTimeRange(start: _displayDate!, end: _displayDate!);
    }

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    switch (_currentView) {
      case StatisticsView.day:
        return DateTimeRange(start: today, end: today);
      case StatisticsView.threeDays:
        return DateTimeRange(
          start: today.subtract(const Duration(days: 2)),
          end: today,
        );
      case StatisticsView.week:
        return DateTimeRange(
          start: today.subtract(const Duration(days: 6)),
          end: today,
        );
      case StatisticsView.month:
        return DateTimeRange(
          start: today.subtract(const Duration(days: 29)),
          end: today,
        );
      case StatisticsView.year:
        return DateTimeRange(
          start: DateTime(now.year - 1, now.month, now.day),
          end: today,
        );
    }
  }

  List<Task> _getTasksInRange(List<Task> tasks, DateTimeRange range) {
    return tasks.where((task) {
      final taskDate = DateTime(
        task.cplTime.year,
        task.cplTime.month,
        task.cplTime.day,
      );
      return !taskDate.isBefore(range.start) && !taskDate.isAfter(range.end);
    }).toList();
  }
}
