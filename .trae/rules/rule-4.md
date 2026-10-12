规范 4：编码、入口与异常

main.dart 顺序（强制）
WidgetsFlutterBinding.ensureInitialized()
→ WidgetService.init()
→ StatisticService.init()
→ 并行：SettingsProvider.initialize() 与 PomodoroNotificationService.init()
  （两者互不依赖，并行以缩短冷启动；两个通知服务之间保持串行）
→ PomodoroBackgroundService.init()
→ runApp；
MaterialApp 绑定 settingsProvider.themeMode；
home 为 AppUpdatePromptHost(child: TasksHomePage())
  —— 更新弹窗宿主必须在 MaterialApp/Navigator 之下，否则 showDialog 无效。

编码
遵循 Dart 规范；单行 ≤ 120 字符；缩进 2 空格（dart format 默认，不用 Tab）；
类 / 方法加 /// 文档注释；注释写「为什么」而非「做了什么」；
禁止保留注释掉的死代码，禁止拼音注释。

异常（强制）
所有异步 I/O（网络、文件、DB）必须捕获异常；
边界层用自定义异常（GameException / AppUpdateException / FileDownloadException /
ZipExtractorException），不要到处抛裸 Exception；
禁止空 catch —— 至少要 AppLogger.warn / debugPrint 留痕；「有意忽略」必须写明理由；
跨层委托必须转换异常类型：
  core 抛 FileDownloadException / ZipExtractorException，
  游戏模块对外仍抛 GameException（on X catch (e) { throw GameException(e.message); }），
  保证调用方的 catch 种类不因重构而失效。

外部数据解析（fail-soft）
顶层结构不对 → 抛 FormatException（必须让上层知道）；
单个字段非法 → 只丢弃该字段，不要整份报废；
理由：清单来自外网，一个笔误不该让整个功能瘫痪。

安全校验（不放行）
下载 URL 只接受 http / https（拒绝 file:、javascript:）；
需要校验的产物（APK / 资源包）先校验哈希，再执行下一步；
校验失败绝不允许进入安装 / 解压 / 落位。

禁止
非 Widget 层禁止 listen: true；
禁止在 ProxyProvider 的 update 中写业务逻辑；
禁止统计逻辑触发 UI 重建；
禁止生成、记录或输出签名口令等敏感凭据。
