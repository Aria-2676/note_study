import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/app_state_provider.dart';
import '../../../providers/points_provider.dart';
import '../../../providers/task_provider.dart';
import '../../../providers/shop_provider.dart';
import '../../../providers/settings_provider.dart';
import './task_page.dart';
import '../../statistics/pages/statistics_page.dart';
import '../../others/pages/others_page.dart';
import '../../profile/pages/profile_page.dart';
import '../../../data/models/task/task_model.dart';

class TasksHomePage extends StatefulWidget {
  const TasksHomePage({super.key});

  @override
  State<TasksHomePage> createState() => _TasksHomePageState();
}

class _TasksHomePageState extends State<TasksHomePage>
    with WidgetsBindingObserver {
  final ScrollController _calendarController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeProviders();
  }

  Future<void> _initializeProviders() async {
    await Future.microtask(() async {
      if (!mounted) return;
      await context.read<TaskProvider>().initialize();
      if (!mounted) return;
      await context.read<PointsProvider>().initialize();
      if (!mounted) return;
      await context.read<ShopProvider>().initialize();
      if (!mounted) return;
      await context.read<SettingsProvider>().initialize();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _calendarController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      context.read<TaskProvider>().syncFromWidget();
    }
  }

  void _scrollToToday() {
    const double itemWidth = 66.0;
    const int todayIndex = 7;
    final screenWidth = MediaQuery.of(context).size.width;
    final offset =
        (todayIndex * itemWidth) - (screenWidth / 2) + (itemWidth / 2);

    if (_calendarController.hasClients) {
      _calendarController.jumpTo(
        offset.clamp(0.0, _calendarController.position.maxScrollExtent),
      );
    }
  }

  void _resetToToday() {
    context.read<TaskProvider>().selectDate(DateTime.now());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToToday();
    });
  }

  @override
  Widget build(BuildContext context) {
    final appStateProvider = context.watch<AppStateProvider>();
    final pointsProvider = context.watch<PointsProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('任务管家'),
        centerTitle: true,
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.amber.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.amber),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.stars, color: Colors.amber, size: 18),
                const SizedBox(width: 4),
                Text(
                  '${pointsProvider.currentPoints}',
                  style: const TextStyle(
                    color: Colors.amber,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: IndexedStack(
        index: appStateProvider.currentTab,
        children: [
          TaskPage(
            calendarController: _calendarController,
            onResetToToday: _resetToToday,
            scrollToToday: _scrollToToday,
          ),
          const StatisticsPage(),
          const OthersPage(),
          const ProfilePage(),
        ],
      ),
      floatingActionButton: appStateProvider.currentTab == 0
          ? FloatingActionButton(
              onPressed: () => _showAddTaskDialog(context),
              child: const Icon(Icons.add),
            )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      bottomNavigationBar: NavigationBar(
        selectedIndex: appStateProvider.currentTab,
        onDestinationSelected: (index) {
          appStateProvider.setCurrentTab(index);
          if (index == 0) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _resetToToday();
            });
          }
        },
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home), label: '首页'),
          NavigationDestination(icon: Icon(Icons.bar_chart), label: '统计'),
          NavigationDestination(icon: Icon(Icons.apps), label: '其他'),
          NavigationDestination(icon: Icon(Icons.person), label: '我的'),
        ],
      ),
    );
  }

  void _showAddTaskDialog(BuildContext context) {
    final taskProvider = context.read<TaskProvider>();
    final titleController = TextEditingController();
    final descController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) {
        final navigator = Navigator.of(ctx);
        return AlertDialog(
          title: const Text('添加任务'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                decoration: const InputDecoration(labelText: '任务名称'),
              ),
              TextField(
                controller: descController,
                decoration: const InputDecoration(labelText: '描述（可选）'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => navigator.pop(),
              child: const Text('取消'),
            ),
            ElevatedButton(
              onPressed: () async {
                final title = titleController.text.trim();
                if (title.isEmpty) {
                  navigator.pop();
                  return;
                }
                final task = Task(
                  title: title,
                  description: descController.text.trim(),
                  cplTime: taskProvider.selectedDate,
                );
                await taskProvider.addTask(task);
                navigator.pop();
              },
              child: const Text('添加'),
            ),
          ],
        );
      },
    );
  }
}