import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'core/services/widget_service.dart';
import 'core/services/statistic_service.dart';
import 'core/services/database/database_service.dart';
import 'modules/pomodoro/services/pomodoro_notification_service.dart';
import 'modules/pomodoro/services/pomodoro_background_service.dart';
import 'modules/tasks/repositories/task_repository.dart';
import 'modules/tasks/services/task_scheduler_service.dart';
import 'modules/statistics/repositories/statistics_repository.dart';
import 'providers/app_state_provider.dart';
import 'providers/settings_provider.dart';
import 'providers/points_provider.dart';
import 'providers/shop_provider.dart';
import 'providers/task_provider.dart';
import 'providers/tag_provider.dart';
import 'providers/pomodoro_provider.dart';
import 'providers/scratch_provider.dart';
import 'providers/statistics_provider.dart';
import 'modules/tasks/pages/tasks_home_page.dart';

/// 应用程序入口
/// 初始化顺序：WidgetsFlutterBinding → WidgetService → StatisticService → PomodoroServices → SettingsProvider → runApp
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await WidgetService.init();
  await StatisticService.init();
  await PomodoroNotificationService.init();
  await PomodoroBackgroundService.init();

  final settingsProvider = SettingsProvider();
  await settingsProvider.initialize();

  runApp(MyApp(settingsProvider: settingsProvider));
}

/// 应用程序根组件
class MyApp extends StatelessWidget {
  final SettingsProvider settingsProvider;

  const MyApp({super.key, required this.settingsProvider});

  @override
  Widget build(BuildContext context) {
    // 数据网关 + 仓储实现 + 调度服务，构造注入到 Provider
    final databaseGateway = DatabaseService.instance;
    final taskRepository = TaskRepositoryImpl(databaseGateway);
    final statisticsRepository = StatisticsRepositoryImpl(databaseGateway);
    final taskSchedulerService = TaskSchedulerService(
      taskRepository,
      databaseGateway,
    );

    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: settingsProvider),
        ChangeNotifierProvider(create: (_) => AppStateProvider()),
        ChangeNotifierProvider(create: (_) => PointsProvider()),
        ChangeNotifierProvider(create: (_) => TagProvider()),
        ChangeNotifierProvider(create: (_) => PomodoroProvider()),
        ChangeNotifierProvider(create: (_) => ScratchProvider()),
        ChangeNotifierProvider(
          create: (_) => StatisticsProvider(repository: statisticsRepository),
        ),
        ChangeNotifierProxyProvider<PointsProvider, ShopProvider>(
          create: (context) => ShopProvider(context.read<PointsProvider>()),
          update: (context, pointsProvider, shopProvider) =>
              shopProvider!..updatePointsProvider(pointsProvider),
        ),
        ChangeNotifierProxyProvider<PointsProvider, TaskProvider>(
          create: (context) => TaskProvider(
            context.read<PointsProvider>(),
            taskRepository: taskRepository,
            taskSchedulerService: taskSchedulerService,
          ),
          update: (context, pointsProvider, taskProvider) =>
              taskProvider!..updatePointsProvider(pointsProvider),
        ),
      ],
      child: Consumer<SettingsProvider>(
        builder: (context, settingsProvider, child) {
          return MaterialApp(
            title: '任务管家',
            debugShowCheckedModeBanner: false,
            theme: ThemeData.light(useMaterial3: true),
            darkTheme: ThemeData.dark(useMaterial3: true),
            themeMode: settingsProvider.themeMode,
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: const [Locale('zh', 'CN'), Locale('en', 'US')],
            locale: const Locale('zh', 'CN'),
            home: const TasksHomePage(),
          );
        },
      ),
    );
  }
}
