import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../providers/pomodoro_provider.dart';
import '../models/pomodoro_model.dart';
import '../adapters/pomodoro_statistic_adapter.dart';

/// 番茄钟历史记录页面
class PomodoroHistoryPage extends StatefulWidget {
  const PomodoroHistoryPage({super.key});

  @override
  State<PomodoroHistoryPage> createState() => _PomodoroHistoryPageState();
}

class _PomodoroHistoryPageState extends State<PomodoroHistoryPage> {
  List<PomodoroRecord> _records = [];
  bool _isLoading = true;
  DateTime _selectedDate = DateTime.now();
  final PomodoroStatisticAdapter _statisticAdapter = PomodoroStatisticAdapter();

  @override
  void initState() {
    super.initState();
    _loadRecords();
    _statisticAdapter.reportPageViewHistory();
  }

  Future<void> _loadRecords() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final provider = context.read<PomodoroProvider>();
      _records = await provider.getHistoryRecords(
        startDate: DateTime(_selectedDate.year, _selectedDate.month, 1),
        endDate: DateTime(_selectedDate.year, _selectedDate.month + 1, 1),
      );
    } catch (e) {
      debugPrint('Load records failed: $e');
    }

    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );

    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
      await _loadRecords();
    }
  }

  Future<void> _deleteRecord(int id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认删除'),
        content: const Text('确定要删除这条记录吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await context.read<PomodoroProvider>().deleteRecord(id);
      await _loadRecords();
    }
  }

  Future<void> _clearAllRecords() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认清空'),
        content: const Text('确定要清空所有历史记录吗？此操作不可恢复。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('清空'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await context.read<PomodoroProvider>().clearAllRecords();
      await _loadRecords();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('历史记录'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_today),
            onPressed: _selectDate,
            tooltip: '选择月份',
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'clear') {
                _clearAllRecords();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'clear',
                child: Text('清空记录'),
              ),
            ],
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _records.isEmpty
              ? _buildEmptyState()
              : _buildRecordsList(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.history,
            size: 64,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            '暂无记录',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            DateFormat('yyyy年MM月').format(_selectedDate),
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecordsList() {
    final dateFormat = DateFormat('MM月dd日');
    final timeFormat = DateFormat('HH:mm');

    final groupedRecords = <String, List<PomodoroRecord>>{};
    for (final record in _records) {
      final dateKey = dateFormat.format(record.startTime);
      groupedRecords.putIfAbsent(dateKey, () => []).add(record);
    }

    return Column(
      children: [
        _buildStatisticsCard(),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: groupedRecords.length,
            itemBuilder: (context, index) {
              final dateKey = groupedRecords.keys.elementAt(index);
              final records = groupedRecords[dateKey]!;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      dateKey,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  ...records.map((record) => _buildRecordCard(record, timeFormat)),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildStatisticsCard() {
    return Consumer<PomodoroProvider>(
      builder: (context, provider, child) {
        final stats = provider.statistics;
        return Card(
          margin: const EdgeInsets.all(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatItem(
                  icon: Icons.timer,
                  label: '今日',
                  value: '${stats.todayPomodoros}个',
                  color: Colors.red,
                ),
                _buildStatItem(
                  icon: Icons.access_time,
                  label: '今日专注',
                  value: '${stats.todayFocusMinutes}分钟',
                  color: Colors.blue,
                ),
                _buildStatItem(
                  icon: Icons.calendar_view_week,
                  label: '本周',
                  value: '${stats.weekPomodoros}个',
                  color: Colors.green,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Column(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }

  Widget _buildRecordCard(PomodoroRecord record, DateFormat timeFormat) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: record.mode.color.withValues(alpha: 0.2),
            shape: BoxShape.circle,
          ),
          child: Icon(
            record.mode == PomodoroMode.work ? Icons.work : Icons.coffee,
            color: record.mode.color,
          ),
        ),
        title: Text(
          record.mode.displayName,
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${timeFormat.format(record.startTime)} - ${record.endTime != null ? timeFormat.format(record.endTime!) : "进行中"}',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
            if (record.relatedTaskTitle != null)
              Text(
                '关联任务: ${record.relatedTaskTitle}',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${record.focusMinutes}分钟',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                if (record.isCompleted)
                  Icon(
                    Icons.check_circle,
                    color: Colors.green,
                    size: 16,
                  ),
              ],
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, size: 20),
              onPressed: () => _deleteRecord(record.id!),
              tooltip: '删除',
            ),
          ],
        ),
      ),
    );
  }
}
