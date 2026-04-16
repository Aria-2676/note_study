import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/services/widget_service.dart';
import 'core/services/statistic_service.dart';
import 'providers/app_state_provider.dart';
import 'providers/settings_provider.dart';
import 'providers/points_provider.dart';
import 'providers/shop_provider.dart';
import 'providers/task_provider.dart';
import 'providers/tag_provider.dart';
import 'modules/tasks/pages/tasks_home_page.dart';

/// 应用程序入口
/// 初始化顺序：WidgetsFlutterBinding → WidgetService → StatisticService → runApp
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await WidgetService.init();
  await StatisticService.init();

  runApp(const MyApp());
}

/// 应用程序根组件
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AppStateProvider()),
        ChangeNotifierProvider(create: (_) => SettingsProvider()),
        ChangeNotifierProvider(create: (_) => PointsProvider()),
        ChangeNotifierProvider(create: (_) => TagProvider()),
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
