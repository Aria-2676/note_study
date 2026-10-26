// 任务管家 V5 —— 本仓库已冻结为 V5 归档。
//
// V6 在另一个仓库（Aria-2676/taskmaster-v6），两条线各自维护：
// 这里只应该出现"修老用户问题"的改动，功能开发一律去 V6。
//
// 注意：V5 的 update.json 停在 6.0.0（唯一的跨线引流），不要再改它。
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'core/services/widget_service.dart';
import 'core/services/statistic_service.dart';
import 'core/services/database/database_service.dart';
import 'core/updater/models/hot_theme_config.dart';
import 'core/updater/providers/app_update_provider.dart';
import 'core/updater/services/app_update_launcher.dart';
import 'core/updater/services/background_update_worker.dart';
import 'core/updater/services/hot_theme_loader.dart';
import 'core/updater/widgets/app_update_dialog.dart';
import 'modules/pomodoro/services/pomodoro_notification_service.dart';
import 'modules/pomodoro/services/pomodoro_background_service.dart';
import 'modules/tasks/repositories/task_repository.dart';
import 'modules/tasks/services/task_scheduler_service.dart';
import 'modules/statistics/repositories/statistics_repository.dart';
import 'modules/games/providers/game_provider.dart';
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

  final settingsProvider = SettingsProvider();
  // 设置读取会首次打开数据库（冷启动的主要耗时），与通知/番茄钟初始化互不依赖，
  // 故并行以缩短启动；两个通知服务之间保持串行，避免插件内部状态竞争。
  final settingsFuture = settingsProvider.initialize();
  // 热更主题只在启动时读一次：主题变更需要整树重建，运行中热换会闪屏，
  // 而换主题是低频操作，重启生效可接受。读不到就用内置主题，不阻断启动。
  final hotThemeFuture = HotThemeLoader.load();
  await PomodoroNotificationService.init();
  await PomodoroBackgroundService.init();
  await settingsFuture;

  runApp(
    MyApp(settingsProvider: settingsProvider, hotTheme: await hotThemeFuture),
  );

  // 清理历次更新遗留在缓存目录的安装包 / 资源包：安装器接手后不能立刻删，
  // 事后也没有清理点，只能等下次启动回收。不阻断启动，失败静默。
  unawaited(AppUpdateLauncher.cleanupStaleFiles());

  // 后台周期性版本检查：不阻断启动，失败也不影响 App 正常使用。
  // 通知权限在 Android 13+ 上首启询问一次（拒绝后系统不再弹框，
  // 后台检查照常，只是发不出通知）。
  unawaited(
    BackgroundUpdateWorker.register().then((_) {
      return BackgroundUpdateWorker.ensureNotificationPermission();
    }).catchError((Object error, StackTrace stack) {
      debugPrint('BackgroundUpdateWorker register failed: $error\n$stack');
      return false;
    }),
  );
}

/// 应用程序根组件
class MyApp extends StatelessWidget {
  final SettingsProvider settingsProvider;

  /// 热更主题配置；无热更主题时为 [HotThemeConfig.empty]。
  final HotThemeConfig hotTheme;

  const MyApp({
    super.key,
    required this.settingsProvider,
    this.hotTheme = HotThemeConfig.empty,
  });

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
        ChangeNotifierProvider(create: (_) => AppStateProvider()),
        ChangeNotifierProvider.value(value: settingsProvider),
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
        ChangeNotifierProxyProvider<PointsProvider, GameProvider>(
          create: (context) => GameProvider(context.read<PointsProvider>()),
          update: (context, pointsProvider, gameProvider) =>
              gameProvider!..updatePointsProvider(pointsProvider),
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
        ChangeNotifierProvider(
          create: (_) {
            final provider = AppUpdateProvider();
            // 版本检查不阻断启动：初始化失败或网络不通时安静跳过，
            // 后续回到前台还会再按间隔重试（见 AppUpdatePromptHost）。
            unawaited(provider.initialize().then((_) => provider.checkIfDue()));
            return provider;
          },
        ),
      ],
      child: Consumer<SettingsProvider>(
        builder: (context, settingsProvider, child) {
          return MaterialApp(
            title: '任务管家',
            debugShowCheckedModeBanner: false,
            // 内置主题先建好，再让热更主题在其上做定点覆写。两者分开是为了
            // 保证「没有热更主题」时与改造前的表现完全一致。
            theme: HotThemeLoader.apply(
              ThemeData.light(useMaterial3: true),
              hotTheme,
              fallbackBrightness: Brightness.light,
            ),
            darkTheme: HotThemeLoader.apply(
              ThemeData.dark(useMaterial3: true),
              hotTheme,
              fallbackBrightness: Brightness.dark,
            ),
            themeMode: settingsProvider.themeMode,
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: const [Locale('zh', 'CN'), Locale('en', 'US')],
            locale: const Locale('zh', 'CN'),
            home: const AppUpdatePromptHost(child: TasksHomePage()),
          );
        },
      ),
    );
  }
}
