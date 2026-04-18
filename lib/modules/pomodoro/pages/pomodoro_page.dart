import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/pomodoro_provider.dart';
import '../../../providers/task_provider.dart';
import '../services/pomodoro_notification_service.dart';
import '../adapters/pomodoro_statistic_adapter.dart';
import './pomodoro_settings_page.dart';
import './pomodoro_history_page.dart';
import './widgets/mode_selector_widget.dart';
import './widgets/timer_display_widget.dart';
import './widgets/related_task_widget.dart';
import './widgets/control_buttons_widget.dart';
import './widgets/statistics_card_widget.dart';

class PomodoroPage extends StatefulWidget {
  const PomodoroPage({super.key});

  @override
  State<PomodoroPage> createState() => _PomodoroPageState();
}

class _PomodoroPageState extends State<PomodoroPage>
    with WidgetsBindingObserver {
  final PomodoroStatisticAdapter _statisticAdapter = PomodoroStatisticAdapter();
  final PomodoroNotificationService _notificationService =
      PomodoroNotificationService();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initProvider();
    _statisticAdapter.reportPageViewHome();
  }

  Future<void> _initProvider() async {
    try {
      await context.read<PomodoroProvider>().initialize();
    } catch (e) {
      debugPrint('PomodoroProvider初始化失败: $e');
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final provider = context.read<PomodoroProvider>();
    if (state == AppLifecycleState.paused && provider.isRunning) {
      _notificationService.showNotification(
        title: '番茄钟运行中',
        body: provider.formattedTime,
      );
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _onTimerComplete(PomodoroProvider provider) async {
    final settings = provider.settings;
    await _notificationService.notifyAll(
      soundEnabled: settings.soundEnabled,
      vibrationEnabled: settings.vibrationEnabled,
      notificationEnabled: settings.notificationEnabled,
      mode: provider.mode,
    );
  }

  void _showTaskSelector(PomodoroProvider provider) async {
    final taskProvider = context.read<TaskProvider>();
    final tasks = taskProvider.rawTasks;

    if (tasks.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('暂无可关联的任务')));
      return;
    }

    final selected = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('选择关联任务'),
        content: SizedBox(
          width: double.maxFinite,
          height: 300,
          child: ListView.builder(
            itemCount: tasks.length,
            itemBuilder: (context, index) {
              final task = tasks[index];
              return ListTile(
                title: Text(task.title),
                subtitle: task.description != null
                    ? Text(task.description!, maxLines: 1)
                    : null,
                onTap: () {
                  Navigator.pop(context, {'id': task.id, 'title': task.title});
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context, {'id': null, 'title': null});
            },
            child: const Text('清除关联'),
          ),
        ],
      ),
    );

    if (selected != null) {
      provider.setRelatedTask(selected['id'], selected['title']);
    }
  }

  void _showResetDialog(PomodoroProvider provider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('重置计时'),
        content: const Text('确定要重置当前计时吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              provider.resetTimer(saveRecord: true);
              Navigator.pop(context);
            },
            child: const Text('保存并重置'),
          ),
          TextButton(
            onPressed: () {
              provider.resetTimer(saveRecord: false);
              Navigator.pop(context);
            },
            child: const Text('直接重置'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('番茄钟'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const PomodoroHistoryPage()),
              );
            },
            tooltip: '历史记录',
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const PomodoroSettingsPage()),
              );
            },
            tooltip: '设置',
          ),
        ],
      ),
      body: Consumer<PomodoroProvider>(
        builder: (context, provider, child) {
          return Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ModeSelectorWidget(
                    currentMode: provider.mode,
                    isRunning: provider.isRunning,
                    onModeChanged: (mode) => provider.switchMode(mode),
                  ),
                  const SizedBox(height: 32),
                  TimerDisplayWidget(
                    mode: provider.mode,
                    formattedTime: provider.formattedTime,
                    progress: provider.progress,
                    isRunning: provider.isRunning,
                  ),
                  const SizedBox(height: 24),
                  RelatedTaskWidget(
                    mode: provider.mode,
                    relatedTaskTitle: provider.relatedTaskTitle,
                    onTap: () => _showTaskSelector(provider),
                    onClear: () => provider.clearRelatedTask(),
                  ),
                  const SizedBox(height: 32),
                  ControlButtonsWidget(
                    mode: provider.mode,
                    isRunning: provider.isRunning,
                    onStartPause: () {
                      if (provider.isRunning) {
                        provider.pauseTimer();
                      } else {
                        provider.startTimer();
                      }
                    },
                    onReset: () => _showResetDialog(provider),
                    onSkip: () async {
                      await provider.skipPhase();
                      await _onTimerComplete(provider);
                    },
                  ),
                  const SizedBox(height: 32),
                  StatisticsCardWidget(statistics: provider.statistics),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
