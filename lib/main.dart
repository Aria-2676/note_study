import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/services/widget_service.dart';
import 'providers/app_state_provider.dart';
import 'providers/settings_provider.dart';
import 'providers/points_provider.dart';
import 'providers/shop_provider.dart';
import 'providers/task_provider.dart';
import 'modules/tasks/pages/tasks_home_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await WidgetService.init();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AppStateProvider()),
        ChangeNotifierProvider(create: (_) => SettingsProvider()),
        ChangeNotifierProvider(create: (_) => PointsProvider()),
        ChangeNotifierProxyProvider<PointsProvider, ShopProvider>(
          create: (context) => ShopProvider(context.read<PointsProvider>()),
          update: (context, pointsProvider, shopProvider) => 
              ShopProvider(pointsProvider),
        ),
        ChangeNotifierProxyProvider<PointsProvider, TaskProvider>(
          create: (context) => TaskProvider(context.read<PointsProvider>()),
          update: (context, pointsProvider, taskProvider) => 
              TaskProvider(pointsProvider),
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