// 插件桥接（宿主侧）的契约测试。
//
// 重点在两件事：
//   1. **失败不抛异常**，一律返回 `{ok:false, error:{code,message}}`
//   2. **没声明权限就拿不到数据**，且插件之间的私有 KV 互不可见

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:v5_app/app/data/plugin_bridge.dart';
import 'package:v5_app/app/data/settings_repository.dart';
import 'package:v5_app/app/data/task_repository.dart';
import 'package:v5_app/app/models/task.dart';
import 'package:v5_app/core/data/v6_database.dart';
import 'package:v5_app/core/data/v6_plugin_tables.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfiNoIsolate;
  });

  late Database db;
  late TaskRepository tasks;
  late SettingsRepository settings;

  setUp(() async {
    db = await V6Database.open(
      path: inMemoryDatabasePath,
      pluginSchema: PluginSchemaRegistry(),
    );
    tasks = TaskRepository(db);
    settings = SettingsRepository(db);
  });

  tearDown(() => db.close());

  PluginBridge bridge({
    Set<String> permissions = const <String>{'task:read', 'tag:read'},
    String pluginId = 'demo_help',
  }) =>
      PluginBridge(
        pluginId: pluginId,
        permissions: permissions,
        tasks: tasks,
        settings: settings,
        contract: 1,
      );

  Map<String, Object?> errorOf(Map<String, Object?> response) =>
      Map<String, Object?>.from(response['error']! as Map);

  test('没声明权限：返回 permission_denied，不抛异常', () async {
    final response = await bridge(permissions: const <String>{})
        .dispatch('task.count', <String, Object?>{'date': '2026-10-22'});

    expect(response['ok'], isFalse);
    expect(errorOf(response)['code'], 'permission_denied');
  });

  test('task.count 返回总数与已完成数', () async {
    final day = DateTime(2026, 10, 22);
    await tasks.insert(title: 'a', day: day);
    final done = await tasks.insert(title: 'b', day: day);
    await tasks.setDone(done, true);

    final response = await bridge().dispatch('task.count', <String, Object?>{'date': '2026-10-22'});

    expect(response['ok'], isTrue);
    final result = Map<String, Object?>.from(response['result']! as Map);
    expect(result['total'], 2);
    expect(result['done'], 1);
    expect(result['from'], '2026-10-22');
  });

  test('task.list 只给裁剪后的字段，并遵守 limit', () async {
    final day = DateTime(2026, 10, 22);
    for (var i = 0; i < 5; i++) {
      await tasks.insert(title: '任务 $i', day: day);
    }

    final response = await bridge().dispatch('task.list', <String, Object?>{
      'from': '2026-10-22',
      'to': '2026-10-22',
      'limit': 2,
    });

    final list = List<Object?>.from(response['result']! as List);
    expect(list, hasLength(2));

    final first = Map<String, Object?>.from(list.first! as Map);
    expect(first.keys.toSet(), <String>{
      'id',
      'title',
      'dueDate',
      'isDone',
      'priority',
      'estimatedMinutes',
      'tags',
    });
    expect(first.containsKey('description'), isFalse, reason: '不该把整行原样吐给插件');
  });

  test('tag.list 返回 id 与名称', () async {
    await tasks.insertTag(const Tag(id: 0, name: '工作'));
    final response = await bridge().dispatch('tag.list', const <String, Object?>{});

    final list = List<Object?>.from(response['result']! as List);
    expect(list, hasLength(1));
    expect(Map<String, Object?>.from(list.first! as Map)['name'], '工作');
  });

  test('私有 KV：换个插件 id 就读不到', () async {
    final mine = bridge();
    await mine.dispatch('store.set', <String, Object?>{'key': 'lastTab', 'value': 'stats'});

    final read = await mine.dispatch('store.get', <String, Object?>{'key': 'lastTab'});
    expect(Map<String, Object?>.from(read['result']! as Map)['value'], 'stats');

    final other = bridge(pluginId: 'another_plugin');
    final leaked = await other.dispatch('store.get', <String, Object?>{'key': 'lastTab'});
    expect(Map<String, Object?>.from(leaked['result']! as Map)['value'], isNull);
  });

  test('系统信息里带契约版本与已授予权限', () async {
    final response = await bridge(permissions: const <String>{'task:read'})
        .dispatch('system.info', const <String, Object?>{});

    final result = Map<String, Object?>.from(response['result']! as Map);
    expect(result['pluginId'], 'demo_help');
    expect(result['contract'], 1);
    expect(result['permissions'], <String>['task:read']);
  });

  test('未知方法与坏参数都走错误码，不抛', () async {
    final unknown = await bridge().dispatch('task.deleteEverything', const <String, Object?>{});
    expect(errorOf(unknown)['code'], 'unknown_method');

    final bad = await bridge().dispatch('task.list', <String, Object?>{
      'from': '2026-10-23',
      'to': '2026-10-22',
    });
    expect(errorOf(bad)['code'], 'bad_params');

    final missingKey = await bridge().dispatch('store.get', const <String, Object?>{});
    expect(errorOf(missingKey)['code'], 'bad_params');
  });
}
