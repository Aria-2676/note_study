import '../models/task.dart';
import '../data/settings_repository.dart';
import '../data/task_repository.dart';

/// 插件 ↔ 宿主的数据通道（宿主侧）。
///
/// 插件永远不碰数据库，只调这里的方法。第一版只开**只读查询 + 插件私有 KV**：
/// 写能力（改任务、加积分）暂时不开 —— 它们要配套的幂等与冲突处理，
/// 而现在的插件还用不到。
///
/// 返回结构固定：成功 `{ok: true, result: ...}`，失败 `{ok: false, error: {code, message}}`。
/// **失败不抛异常**：JS 那侧只需要看 `ok`，不用区分是业务错还是崩了。
class PluginBridge {
  PluginBridge({
    required this.pluginId,
    required this.permissions,
    required TaskRepository tasks,
    required SettingsRepository settings,
    required this.contract,
  })  : _tasks = tasks,
        _settings = settings;

  final String pluginId;
  final Set<String> permissions;
  final int contract;

  final TaskRepository _tasks;
  final SettingsRepository _settings;

  Future<Map<String, Object?>> dispatch(String method, Map<String, Object?> params) async {
    try {
      return switch (method) {
        'system.info' => _ok(<String, Object?>{
            'pluginId': pluginId,
            'contract': contract,
            'permissions': (permissions.toList()..sort()),
          }),
        'task.count' => await _taskCount(params),
        'task.list' => await _taskList(params),
        'tag.list' => await _tagList(),
        'store.get' => await _storeGet(params),
        'store.set' => await _storeSet(params),
        'store.remove' => await _storeRemove(params),
        _ => _error('unknown_method', '未知方法：$method'),
      };
    } on _BridgeError catch (error) {
      return _error(error.code, error.message);
    } catch (error) {
      return _error('internal', '$error');
    }
  }

  // ---- task ----

  Future<Map<String, Object?>> _taskCount(Map<String, Object?> params) async {
    _require(PluginPermissions.taskRead);
    final (from, to) = _range(params);
    final tasks = await _tasks.tasksBetween(from, to, limit: 500);
    return _ok(<String, Object?>{
      'from': TaskDate.dayKey(from),
      'to': TaskDate.dayKey(to),
      'total': tasks.length,
      'done': tasks.where((t) => t.isDone).length,
    });
  }

  Future<Map<String, Object?>> _taskList(Map<String, Object?> params) async {
    _require(PluginPermissions.taskRead);
    final (from, to) = _range(params);
    final limit = (params['limit'] is int ? params['limit']! as int : 100).clamp(1, 200);
    final tasks = await _tasks.tasksBetween(from, to, limit: limit);

    return _ok(<Object?>[
      for (final task in tasks)
        <String, Object?>{
          'id': task.id,
          'title': task.title,
          'dueDate': TaskDate.dayKey(task.dueDate),
          'isDone': task.isDone,
          'priority': task.priority,
          'estimatedMinutes': task.estimatedMinutes,
          'tags': <String>[for (final tag in task.tags) tag.name],
        },
    ]);
  }

  Future<Map<String, Object?>> _tagList() async {
    _require(PluginPermissions.tagRead);
    final tags = await _tasks.allTags();
    return _ok(<Object?>[
      for (final tag in tags) <String, Object?>{'id': tag.id, 'name': tag.name},
    ]);
  }

  // ---- 插件私有 KV ----

  String _kvKey(String key) => 'plg.$pluginId.$key';

  Future<Map<String, Object?>> _storeGet(Map<String, Object?> params) async {
    final key = _stringParam(params, 'key');
    final value = await _settings.get(_kvKey(key));
    return _ok(<String, Object?>{'value': value});
  }

  Future<Map<String, Object?>> _storeSet(Map<String, Object?> params) async {
    final key = _stringParam(params, 'key');
    final value = params['value'];
    if (value == null) {
      throw const _BridgeError('bad_params', 'value 不能为空');
    }
    await _settings.set(_kvKey(key), '$value');
    return _ok(<String, Object?>{'saved': true});
  }

  Future<Map<String, Object?>> _storeRemove(Map<String, Object?> params) async {
    final key = _stringParam(params, 'key');
    await _settings.set(_kvKey(key), '');
    return _ok(<String, Object?>{'removed': true});
  }

  // ---- 工具 ----

  void _require(String permission) {
    if (!permissions.contains(permission)) {
      throw _BridgeError('permission_denied', '缺少权限：$permission');
    }
  }

  (DateTime, DateTime) _range(Map<String, Object?> params) {
    final rawFrom = params['from'] ?? params['date'];
    final rawTo = params['to'];
    final from = rawFrom is String ? TaskDate.parseDay(rawFrom) : DateTime.now();
    final to = rawTo is String ? TaskDate.parseDay(rawTo) : from;
    if (to.isBefore(from)) {
      throw const _BridgeError('bad_params', 'to 不能早于 from');
    }
    return (DateTime(from.year, from.month, from.day), DateTime(to.year, to.month, to.day));
  }

  String _stringParam(Map<String, Object?> params, String name) {
    final value = params[name];
    if (value is! String || value.isEmpty) {
      throw _BridgeError('bad_params', '$name 必须是非空字符串');
    }
    return value;
  }

  static Map<String, Object?> _ok(Object? result) =>
      <String, Object?>{'ok': true, 'result': result};

  static Map<String, Object?> _error(String code, String message) => <String, Object?>{
        'ok': false,
        'error': <String, Object?>{'code': code, 'message': message},
      };
}

/// 权限常量，和 `PluginManifest.knownPermissions` 一一对应。
class PluginPermissions {
  const PluginPermissions._();

  static const String taskRead = 'task:read';
  static const String tagRead = 'tag:read';
}

class _BridgeError implements Exception {
  const _BridgeError(this.code, this.message);

  final String code;
  final String message;
}
