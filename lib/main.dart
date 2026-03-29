import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'models/task.dart';
import 'providers/app_provider.dart';
import 'services/widget_service.dart';
import 'pages/task_page.dart';
import 'pages/statistics_page.dart';
import 'pages/others_page.dart';
import 'pages/mine_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await WidgetService.init();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AppProvider(),
      child: Consumer<AppProvider>(
        builder: (context, provider, child) {
          return MaterialApp(
            title: '任务管家',
            debugShowCheckedModeBanner: false,
            theme: ThemeData.light(useMaterial3: true),
            darkTheme: ThemeData.dark(useMaterial3: true),
            themeMode: provider.themeMode,
            home: const HomePage(),
          );
        },
      ),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with WidgetsBindingObserver {
  final ScrollController _calendarController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final provider = context.read<AppProvider>();
      await provider.initialize();
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

    // 当应用从后台恢复到前台时，同步小组件数据
    if (state == AppLifecycleState.resumed) {
      final provider = context.read<AppProvider>();
      provider.syncFromWidget();
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
    final provider = context.read<AppProvider>();
    provider.selectDate(DateTime.now());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToToday();
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('任务管家'),
        centerTitle: true,
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.amber.withOpacity(0.2),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.amber),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.stars, color: Colors.amber, size: 18),
                const SizedBox(width: 4),
                Text(
                  '${provider.currentPoints}',
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
        index: provider.currentTab,
        children: [
          TaskPage(
            calendarController: _calendarController,
            onResetToToday: _resetToToday,
            scrollToToday: _scrollToToday,
          ),
          const StatisticsPage(),
          const OthersPage(),
          const MinePage(),
        ],
      ),
      floatingActionButton: provider.currentTab == 0
          ? FloatingActionButton(
              onPressed: () => _showAddOrEditTaskDialog(context),
              child: const Icon(Icons.add),
            )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      bottomNavigationBar: NavigationBar(
        selectedIndex: provider.currentTab,
        onDestinationSelected: (index) {
          provider.setCurrentTab(index);
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

  void _showAddOrEditTaskDialog(BuildContext context, {Task? task}) {
    final provider = context.read<AppProvider>();
    final titleController = TextEditingController(text: task?.title ?? '');
    final descController = TextEditingController(text: task?.description ?? '');
    final rewardPointsController = TextEditingController(
      text: task?.rewardPoints.toString() ?? '0',
    );
    final selectDate = task?.cplTime ?? provider.selectedDate;
    String recurrence = task?.recurrence ?? 'none';
    bool isWord = task?.isWord ?? false;
    String priority = task?.priority ?? 'white';
    DateTime currentDate = selectDate;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom,
              ),
              child: Container(
                padding: const EdgeInsets.all(16),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        task == null ? '添加任务' : '编辑任务',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: titleController,
                        decoration: const InputDecoration(
                          labelText: '任务名称',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: descController,
                        decoration: const InputDecoration(
                          labelText: '任务描述（可选）',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: rewardPointsController,
                        decoration: const InputDecoration(
                          labelText: '完成奖励积分',
                          border: OutlineInputBorder(),
                          hintText: '0',
                          helperText: '未完成将扣除一半积分（取整）',
                        ),
                        keyboardType: TextInputType.number,
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          const Text('任务日期：'),
                          TextButton(
                            onPressed: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: currentDate,
                                firstDate: DateTime.now().subtract(
                                  const Duration(days: 365),
                                ),
                                lastDate: DateTime.now().add(
                                  const Duration(days: 365),
                                ),
                              );
                              if (picked != null)
                                setState(() => currentDate = picked);
                            },
                            child: Text(
                              '${currentDate.year}-${currentDate.month.toString().padLeft(2, '0')}-${currentDate.day.toString().padLeft(2, '0')}',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: recurrence,
                              decoration: const InputDecoration(
                                labelText: '循环',
                                border: OutlineInputBorder(),
                              ),
                              items: const [
                                DropdownMenuItem(
                                  value: 'none',
                                  child: Text('无'),
                                ),
                                DropdownMenuItem(
                                  value: 'daily',
                                  child: Text('每天'),
                                ),
                                DropdownMenuItem(
                                  value: 'weekly',
                                  child: Text('每周'),
                                ),
                                DropdownMenuItem(
                                  value: 'monthly',
                                  child: Text('每月'),
                                ),
                              ],
                              onChanged: (v) {
                                if (v != null) setState(() => recurrence = v);
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: priority,
                              decoration: const InputDecoration(
                                labelText: '优先级',
                                border: OutlineInputBorder(),
                              ),
                              items: [
                                DropdownMenuItem(
                                  value: 'red',
                                  child: Row(
                                    children: [
                                      SizedBox(
                                        width: 12,
                                        height: 12,
                                        child: DecoratedBox(
                                          decoration: BoxDecoration(
                                            color: Colors.red,
                                            borderRadius: BorderRadius.circular(
                                              2,
                                            ),
                                          ),
                                        ),
                                      ),
                                      SizedBox(width: 8),
                                      Text('红色'),
                                    ],
                                  ),
                                ),
                                DropdownMenuItem(
                                  value: 'orange',
                                  child: Row(
                                    children: [
                                      SizedBox(
                                        width: 12,
                                        height: 12,
                                        child: DecoratedBox(
                                          decoration: BoxDecoration(
                                            color: Colors.orange,
                                            borderRadius: BorderRadius.circular(
                                              2,
                                            ),
                                          ),
                                        ),
                                      ),
                                      SizedBox(width: 8),
                                      Text('橙色'),
                                    ],
                                  ),
                                ),
                                DropdownMenuItem(
                                  value: 'yellow',
                                  child: Row(
                                    children: [
                                      SizedBox(
                                        width: 12,
                                        height: 12,
                                        child: DecoratedBox(
                                          decoration: BoxDecoration(
                                            color: Colors.yellow,
                                            borderRadius: BorderRadius.circular(
                                              2,
                                            ),
                                          ),
                                        ),
                                      ),
                                      SizedBox(width: 8),
                                      Text('黄色'),
                                    ],
                                  ),
                                ),
                                DropdownMenuItem(
                                  value: 'blue',
                                  child: Row(
                                    children: [
                                      SizedBox(
                                        width: 12,
                                        height: 12,
                                        child: DecoratedBox(
                                          decoration: BoxDecoration(
                                            color: Colors.blue,
                                            borderRadius: BorderRadius.circular(
                                              2,
                                            ),
                                          ),
                                        ),
                                      ),
                                      SizedBox(width: 8),
                                      Text('蓝色'),
                                    ],
                                  ),
                                ),
                                DropdownMenuItem(
                                  value: 'white',
                                  child: Row(
                                    children: [
                                      SizedBox(
                                        width: 12,
                                        height: 12,
                                        child: DecoratedBox(
                                          decoration: BoxDecoration(
                                            color: Colors.grey,
                                            borderRadius: BorderRadius.circular(
                                              2,
                                            ),
                                          ),
                                        ),
                                      ),
                                      SizedBox(width: 8),
                                      Text('白色'),
                                    ],
                                  ),
                                ),
                              ],
                              onChanged: (v) {
                                if (v != null) setState(() => priority = v);
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                Switch(
                                  value: isWord,
                                  onChanged: (v) => setState(() => isWord = v),
                                ),
                                const Text('单词任务'),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      ElevatedButton(
                        onPressed: () async {
                          final title = titleController.text.trim();
                          if (title.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('任务名称不能为空')),
                            );
                            return;
                          }

                          final rewardPoints =
                              int.tryParse(rewardPointsController.text) ?? 0;

                          final newTask = Task(
                            id: task?.id,
                            title: title,
                            description: descController.text.trim().isEmpty
                                ? null
                                : descController.text.trim(),
                            cplTime: currentDate,
                            recurrence: recurrence,
                            isWord: isWord,
                            isOK: task?.isOK ?? false,
                            completedAt: task?.completedAt,
                            rewardPoints: rewardPoints,
                            isDeducted: task?.isDeducted ?? false,
                            priority: priority,
                          );

                          if (task == null) {
                            await provider.addTask(newTask);
                          } else {
                            await provider.updateTask(newTask);
                          }
                          if (mounted) Navigator.of(context).pop();
                        },
                        child: Text(task == null ? '保存任务' : '更新任务'),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
