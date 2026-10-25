import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../core/data/v6_database.dart';
import '../core/plugin/plugin_index.dart';
import '../core/plugin/plugin_installer.dart';
import '../core/plugin/plugin_store.dart';
import '../core/plugin/plugin_manifest.dart';
import 'data/plugin_bridge.dart';
import 'pages/plugin_page.dart';
import 'pages/recycle_bin_page.dart';
import 'data/demo_seed.dart';
import 'data/settings_repository.dart';
import 'data/task_repository.dart';
import 'shell/main_shell.dart';
import 'state/plugin_market_store.dart';
import 'state/task_store.dart';

/// v6 主包预览壳。接 v6 数据层（`v6_tasks.db`），用独立入口启动，不动现有 `main.dart`：
/// ```bash
/// flutter run -t lib/main_v6_preview.dart
/// ```
///
/// [store] 用于测试注入（内存库）；不传则自己打开真实的 sqflite 库。
class V6PreviewApp extends StatefulWidget {
  const V6PreviewApp({super.key, this.store, this.autoSeed = true});

  final TaskStore? store;

  /// 首次启动（任务表为空）时写入演示数据
  final bool autoSeed;

  @override
  State<V6PreviewApp> createState() => _V6PreviewAppState();
}

class _V6PreviewAppState extends State<V6PreviewApp> {
  static const Color _seed = Color(0xFF6750A4);

  TaskStore? _store;
  PluginMarketStore? _market;
  Object? _error;

  @override
  void initState() {
    super.initState();
    if (widget.store != null) {
      _store = widget.store;
    } else {
      _openDatabase();
    }
  }

  Future<void> _openDatabase() async {
    try {
      final db = await V6Database.open();
      final repo = TaskRepository(db);
      if (widget.autoSeed) {
        await DemoSeed.runIfEmpty(repo);
      }

      final support = await getApplicationSupportDirectory();
      final installer = PluginInstaller(
        db: db,
        rootDir: Directory(p.join(support.path, 'plugins')),
        fetch: _assetFetch,
      );
      // 启动自愈：上次卸载/安装中断留下的残渣在这里清掉
      await installer.reconcile();

      // 回收站到期清理：没有后台服务，每次启动扫一遍就够了
      final settings = SettingsRepository(db);
      final retentionDays = await settings.getInt(
        SettingsKeys.recycleRetentionDays,
        fallback: SettingsKeys.defaultRetentionDays,
      );
      await repo.purgeRecycleOlderThan(Duration(days: retentionDays));

      if (!mounted) return;
      setState(() {
        _store = TaskStore(repo, settings);
        _market = PluginMarketStore(
          installer: installer,
          indexLoader: _loadIndex,
          // 首版从内置 asset 装包；接远程时只改这一行
          urlFor: (pkg) => Uri(scheme: 'asset', path: pkg.path),
        );
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e);
    }
  }

  /// 回收站页面。`MainShell` 没有仓储层，由应用层在这里组装。
  ///
  /// `marketStore` 为 null 时（测试注入 store）返回 null —— 入口会提示"未接入"。
  WidgetBuilder? _recyclePageBuilder(TaskStore store) {
    final market = _market;
    if (market == null) return null;
    final repo = TaskRepository(market.installer.db);
    return (_) => RecycleBinPage(
          repository: repo,
          retentionDays: store.retentionDays,
          // 恢复之后首页要能立刻看到
          onChanged: store.load,
        );
  }

  /// 把一个已装插件变成可打开的页面：入口路径、权限都取自包内 `plugin.json`。
  Future<PluginLaunchSpec> _launchPlugin(InstalledPlugin plugin) async {
    // 所有依赖都从 `_market.installer` 取，不另存字段。
    // 另存的那份在**热重载**后会变成 null（State 复用、新字段没被赋值），
    // 于是点开插件就抛 `Null check operator used on a null value` —— 一个
    // 只在开发期出现、却极难对上原因的假崩溃。
    final market = _market;
    if (market == null) {
      throw StateError('插件运行环境尚未就绪');
    }
    final installer = market.installer;
    final manifest = await installer.manifestOf(plugin);
    final directory = await installer.directoryOf(plugin);
    final db = installer.db;

    return PluginLaunchSpec(
      title: manifest.name,
      entryPath: p.join(directory, manifest.entry),
      bridge: PluginBridge(
        pluginId: plugin.pluginId,
        permissions: manifest.permissions,
        tasks: TaskRepository(db),
        settings: SettingsRepository(db),
        contract: PluginContract.current,
      ),
    );
  }

  static Future<PluginIndex> _loadIndex() async {
    final text = await rootBundle.loadString('assets/plugins/index.json');
    final decoded = jsonDecode(text);
    if (decoded is! Map) {
      throw const PluginFormatException('index.json 顶层必须是对象');
    }
    return PluginIndex.parse(Map<String, Object?>.from(decoded));
  }

  static Future<void> _assetFetch({
    required Uri url,
    required String destPath,
    void Function(int received, int? total)? onProgress,
  }) async {
    final data = await rootBundle.load(url.path);
    final bytes = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
    await File(destPath).writeAsBytes(bytes);
    onProgress?.call(bytes.length, bytes.length);
  }

  ThemeData _theme(Brightness brightness) => ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: _seed, brightness: brightness),
        useMaterial3: true,
      );

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '任务管家 v6 预览',
      debugShowCheckedModeBanner: false,
      theme: _theme(Brightness.light),
      darkTheme: _theme(Brightness.dark),
      home: _buildHome(),
    );
  }

  Widget _buildHome() {
    if (_error != null) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text('数据库打开失败：$_error', textAlign: TextAlign.center),
          ),
        ),
      );
    }
    final store = _store;
    if (store == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    // 测试注入 store 时没有插件基础设施，此时市场入口只提示未接入
    return MainShell(
      store: store,
      marketStore: _market,
      pluginLauncher: _launchPlugin,
      recyclePageBuilder: _recyclePageBuilder(store),
    );
  }
}
