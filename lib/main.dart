import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/services/widget_service.dart';
import 'core/services/statistic_service.dart';
import 'modules/pomodoro/services/pomodoro_notification_service.dart';
import 'modules/pomodoro/services/pomodoro_background_service.dart';
import 'providers/app_state_provider.dart';
import 'providers/settings_provider.dart';
import 'providers/points_provider.dart';
import 'providers/shop_provider.dart';
import 'providers/task_provider.dart';
import 'providers/tag_provider.dart';
import 'providers/pomodoro_provider.dart';
import 'providers/scratch_provider.dart';
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
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: settingsProvider),
        ChangeNotifierProvider(create: (_) => AppStateProvider()),
        ChangeNotifierProvider(create: (_) => PointsProvider()),
        ChangeNotifierProvider(create: (_) => TagProvider()),
        ChangeNotifierProvider(create: (_) => PomodoroProvider()),
        ChangeNotifierProvider(create: (_) => ScratchProvider()),
        ChangeNotifierProxyProvider<PointsProvider, ShopProvider>(
          create: (context) => ShopProvider(context.read<PointsProvider>()),
          update: (context, pointsProvider, shopProvider) =>
              shopProvider!..updatePointsProvider(pointsProvider),
        ),
        ChangeNotifierProxyProvider<PointsProvider, TaskProvider>(
          create: (context) => TaskProvider(context.read<PointsProvider>()),
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
            home: const TasksHomePage(),
          );
        },
      ),
    );
  }
}
