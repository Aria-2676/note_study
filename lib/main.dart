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
import 'components/task_dialog.dart';

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
    provider.task.selectDate(DateTime.now());
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
    TaskDialog.showAddOrEditTaskDialog(context, task: task);
  }
}
