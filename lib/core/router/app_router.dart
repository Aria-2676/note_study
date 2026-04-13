import 'package:flutter/material.dart';
import '../../modules/tasks/pages/tasks_home_page.dart';
import '../../modules/tasks/pages/task_page.dart';
import '../../modules/tasks/pages/recycle_bin_page.dart';
import '../../modules/calendar/pages/calendar_page.dart';
import '../../modules/statistics/pages/statistics_page.dart';
import '../../modules/shop/pages/shop_page.dart';
import '../../modules/shop/pages/warehouse_page.dart';
import '../../modules/profile/pages/profile_page.dart';
import '../../modules/profile/pages/settings_page.dart';
import '../../modules/profile/pages/widget_guide_page.dart';
import '../../modules/help/pages/help_page.dart';
import '../../modules/scratch/pages/scratch_card_page.dart';
import '../../modules/others/pages/others_page.dart';
import '../../modules/others/pages/pomodoro_page.dart';

class AppRouter {
  static const String home = '/';
  static const String task = '/task';
  static const String calendar = '/calendar';
  static const String statistics = '/statistics';
  static const String shop = '/shop';
  static const String mine = '/mine';
  static const String scratch = '/scratch';
  static const String warehouse = '/warehouse';
  static const String setting = '/settings';
  static const String help = '/help';
  static const String recycleBin = '/recycle-bin';
  static const String widgetGuide = '/widget-guide';
  static const String others = '/others';
  static const String pomodoro = '/pomodoro';

  static Route<dynamic> generateRoute(RouteSettings routeSettings) {
    switch (routeSettings.name) {
      case task:
        return MaterialPageRoute(
          builder: (_) => const TaskPage(),
        );
      case home:
        return MaterialPageRoute(builder: (_) => const TasksHomePage());
      case calendar:
        return MaterialPageRoute(builder: (_) => const CalendarPage());
      case statistics:
        return MaterialPageRoute(builder: (_) => const StatisticsPage());
      case shop:
        return MaterialPageRoute(builder: (_) => const ShopPage());
      case mine:
        return MaterialPageRoute(builder: (_) => const ProfilePage());
      case scratch:
        return MaterialPageRoute(builder: (_) => const ScratchCardPage());
      case warehouse:
        return MaterialPageRoute(builder: (_) => const WarehousePage());
      case setting:
        return MaterialPageRoute(builder: (_) => const SettingsPage());
      case help:
        return MaterialPageRoute(builder: (_) => const HelpPage());
      case recycleBin:
        return MaterialPageRoute(builder: (_) => const RecycleBinPage());
      case widgetGuide:
        return MaterialPageRoute(builder: (_) => const WidgetGuidePage());
      case others:
        return MaterialPageRoute(builder: (_) => const OthersPage());
      case pomodoro:
        return MaterialPageRoute(builder: (_) => const PomodoroPage());
      default:
        return MaterialPageRoute(
          builder: (_) => const Scaffold(
            body: Center(child: Text('页面未找到')),
          ),
        );
    }
  }

  static void push(BuildContext context, String routeName, {Object? arguments}) {
    Navigator.pushNamed(context, routeName, arguments: arguments);
  }

  static void pushReplacement(BuildContext context, String routeName, {Object? arguments}) {
    Navigator.pushReplacementNamed(context, routeName, arguments: arguments);
  }

  static void pop(BuildContext context) {
    Navigator.pop(context);
  }

  static void popUntil(BuildContext context, String routeName) {
    Navigator.popUntil(context, ModalRoute.withName(routeName));
  }

  static void popToRoot(BuildContext context) {
    Navigator.popUntil(context, (route) => route.isFirst);
  }

  static void pushAndRemoveUntil(BuildContext context, String routeName) {
    Navigator.pushNamedAndRemoveUntil(context, routeName, (route) => false);
  }
}