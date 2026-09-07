规范 4：编码与入口约束
main.dart 强制顺序
WidgetsFlutterBinding.ensureInitialized ()
→ WidgetService.init ()
→ StatisticService.init ()
→ runApp；
MaterialApp 绑定 settingsProvider.themeMode，首页固定 TasksHomePage。
编码规则
遵循 Dart 规范，单行≤120 字符，缩进 4 空格；
类 / 方法必加 /// 文档注释；
所有异步必捕获异常，禁止崩溃。
禁止行为
非 Widget 层禁止 listen: true；
禁止在 ProxyProvider update 中写业务逻辑；
禁止统计逻辑触发 UI 重建。