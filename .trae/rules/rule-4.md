规范 4：编码与入口约束

main.dart 强制顺序
WidgetsFlutterBinding.ensureInitialized()
→ WidgetService.init()
→ StatisticService.init()
→ 并行：SettingsProvider.initialize() 与 PomodoroNotificationService.init()
  （两者互不依赖，并行以缩短冷启动；两个通知服务之间保持串行）
→ PomodoroBackgroundService.init()
→ runApp；
MaterialApp 绑定 settingsProvider.themeMode；
home 为 AppUpdatePromptHost(child: TasksHomePage()) —— 更新弹窗宿主必须位于
Navigator 之下才能 showDialog，不要把它挪出 MaterialApp。

编码规则
遵循 Dart 规范；单行 ≤ 120 字符；缩进 2 空格（遵循 dart format 默认，不使用 Tab）；
类 / 方法必加 /// 文档注释；复杂逻辑注释写「为什么」而非「做了什么」；
所有异步必捕获异常，禁止崩溃；禁止空 catch。

异常与解析
边界层使用自定义异常（GameException / AppUpdateException / FileDownloadException）；
跨层委托必须转换异常类型，保持调用方 catch 种类不因重构失效；
解析外部数据用 fail-soft：顶层结构错则抛 FormatException，单字段错只丢弃该字段；
安全校验不放行：URL 只接受 http/https；先校验哈希再执行安装/解压。

禁止行为
非 Widget 层禁止 listen: true；
禁止在 ProxyProvider update 中写业务逻辑；
禁止统计逻辑触发 UI 重建；
禁止生成、记录或输出签名口令等敏感凭据。
