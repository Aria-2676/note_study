import 'dart:async';

import '../../core/data/v6_schema.dart';
import '../../core/extension/extension_hook.dart';
import '../models/task.dart';
import '../data/settings_repository.dart';
import '../data/task_repository.dart';

/// 插件 ↔ 宿主的数据通道（宿主侧）。
///
/// 插件永远不碰数据库，只调这里的方法。
///
/// **读写分权**：`task:read` 只能看，`task:write` 才能建/改/标记完成，
/// `task:delete` 单独一条（删是不可逆操作，不能和"改标题"共用一个开关）。
/// 没声明的权限一律 `permission_denied`，不是静默忽略 —— 静默会让插件作者
/// 以为写成功了，最后表现成"点了没反应"。
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
    this.onChanged,
  })  : _tasks = tasks,
        _settings = settings;

  final String pluginId;
  final Set<String> permissions;
  final int contract;

  /// 写成功之后通知宿主刷新（首页列表、日历标记都依赖它）。
  ///
  /// 插件页面自己会重画，但主包的 `TaskStore` 不知道库变了 ——
  /// 不通知就会出现"插件里加了一条，退出插件首页还是旧的"。
  final void Function()? onChanged;

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
        'task.create' => await _taskCreate(params),
        'task.update' => await _taskUpdate(params),
        'task.setDone' => await _taskSetDone(params),
        'task.delete' => await _taskDelete(params),
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

  // ---- task: 读 ----

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

  // ---- task: 写 ----

  Future<Map<String, Object?>> _taskCreate(Map<String, Object?> params) async {
    _require(PluginPermissions.taskWrite);

    final title = _titleOf(params['title']);
    final day = params.containsKey('date') ? _dayOf(params['date']) : DateTime.now();
    final priority = params.containsKey('priority') ? _priorityOf(params['priority']) : 'white';
    final minutes = _minutesOf(params['estimatedMinutes']);
    final description = _descriptionOf(params['description']);
    final tagIds = await _tagIdsOf(params['tagIds']);

    final id = await _tasks.insert(
      title: title,
      day: day,
      priority: priority,
      estimatedMinutes: minutes,
      description: description,
      tagIds: tagIds ?? const <int>[],
    );
    onChanged?.call();
    return _ok(<String, Object?>{'id': id});
  }

  Future<Map<String, Object?>> _taskUpdate(Map<String, Object?> params) async {
    _require(PluginPermissions.taskWrite);

    final id = _idOf(params['id']);
    final fields = <String, Object?>{};

    if (params.containsKey('title')) fields[TaskCol.title] = _titleOf(params['title']);
    if (params.containsKey('date')) {
      fields[TaskCol.cplTime] = TaskDate.dayKey(_dayOf(params['date']));
    }
    if (params.containsKey('priority')) {
      fields[TaskCol.priority] = _priorityOf(params['priority']);
    }
    if (params.containsKey('estimatedMinutes')) {
      fields[TaskCol.estimatedMinutes] = _minutesOf(params['estimatedMinutes']);
    }
    if (params.containsKey('description')) {
      fields[TaskCol.description] = _descriptionOf(params['description']);
    }

    final hasTags = params.containsKey('tagIds');
    if (fields.isEmpty && !hasTags) {
      throw const _BridgeError('bad_params', '没有要修改的字段');
    }
    final tagIds = hasTags ? await _tagIdsOf(params['tagIds']) : null;

    final updated = await _tasks.patch(id, fields, tagIds: tagIds);
    if (!updated) {
      throw _BridgeError('not_found', '任务 $id 不存在（可能已被删除）');
    }
    onChanged?.call();
    return _ok(<String, Object?>{'id': id, 'updated': true});
  }

  Future<Map<String, Object?>> _taskSetDone(Map<String, Object?> params) async {
    _require(PluginPermissions.taskWrite);

    final id = _idOf(params['id']);
    final done = params['done'];
    if (done is! bool) {
      throw const _BridgeError('bad_params', 'done 必须是 true / false');
    }
    final task = await _tasks.findById(id);
    if (task == null) {
      throw _BridgeError('not_found', '任务 $id 不存在（可能已被删除）');
    }

    await _tasks.setDone(id, done);
    // **重复标完成不再发事件**：插件页面刷新时可能重放一次 setDone(true)，
    // 每发一次事件货币插件就多发一次奖励。钩子必须只在状态真的变了才发。
    if (done && !task.isDone) {
      unawaited(HookBus.instance.emit(
        HookId.taskCompleted,
        payload: task.toHookPayload(),
      ));
    }
    onChanged?.call();
    return _ok(<String, Object?>{'id': id, 'isDone': done});
  }

  Future<Map<String, Object?>> _taskDelete(Map<String, Object?> params) async {
    _require(PluginPermissions.taskDelete);

    final id = _idOf(params['id']);
    final task = await _tasks.findById(id);
    if (task == null) {
      throw _BridgeError('not_found', '任务 $id 不存在（可能已被删除）');
    }
    // **删法跟用户设置走**，插件说了不算：用户开着回收站就进回收站。
    // 让插件自己决定"是否彻底删除"等于给它一个绕过保护的口子。
    final toRecycle = await _settings.getBool(
      SettingsKeys.recycleBinEnabled,
      fallback: false,
    );
    await _tasks.delete(id, toRecycle: toRecycle);
    if (toRecycle) {
      unawaited(HookBus.instance.emit(
        HookId.taskRecycled,
        payload: task.toHookPayload(),
      ));
    }
    onChanged?.call();
    return _ok(<String, Object?>{'id': id, 'deleted': true, 'toRecycle': toRecycle});
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

  // ---- 参数校验 ----
  //
  // 全部收在这里。插件的入参来自 JS，**一律当作不可信输入**：
  // 类型不对就拒绝，不做"宽松转换"—— 宽松转换只会让写错的插件悄悄写坏数据。

  static const Set<String> _priorities = <String>{
    'red',
    'orange',
    'yellow',
    'blue',
    'white',
  };

  static const int _maxTitleLength = 200;
  static const int _maxDescriptionLength = 2000;
  static const int _maxMinutes = 1440;

  int _idOf(Object? raw) {
    if (raw is int && raw > 0) return raw;
    if (raw is String) {
      final parsed = int.tryParse(raw);
      if (parsed != null && parsed > 0) return parsed;
    }
    throw const _BridgeError('bad_params', 'id 必须是正整数');
  }

  String _titleOf(Object? raw) {
    if (raw is! String) throw const _BridgeError('bad_params', 'title 必须是字符串');
    final title = raw.trim();
    if (title.isEmpty) throw const _BridgeError('bad_params', 'title 不能为空');
    if (title.length > _maxTitleLength) {
      throw const _BridgeError('bad_params', 'title 超过 200 字');
    }
    return title;
  }

  DateTime _dayOf(Object? raw) {
    if (raw is! String) throw const _BridgeError('bad_params', 'date 必须是 yyyy-MM-dd');
    final day = TaskDate.parseDay(raw);
    // parseDay 会把坏串兜成 1970-01-01，所以要回头比一次原串
    if (TaskDate.dayKey(day) != raw) {
      throw _BridgeError('bad_params', 'date 不是合法日期：$raw');
    }
    return day;
  }

  String _priorityOf(Object? raw) {
    if (raw is! String || !_priorities.contains(raw)) {
      throw const _BridgeError(
        'bad_params',
        'priority 只能是 red / orange / yellow / blue / white',
      );
    }
    return raw;
  }

  /// null 是合法值（= 不设估时），所以这里不能把 null 当错误
  int? _minutesOf(Object? raw) {
    if (raw == null || raw == '') return null;
    final minutes = raw is int ? raw : int.tryParse('$raw');
    if (minutes == null || minutes <= 0 || minutes > _maxMinutes) {
      throw const _BridgeError('bad_params', 'estimatedMinutes 必须是 1~1440 的整数或 null');
    }
    return minutes;
  }

  String? _descriptionOf(Object? raw) {
    if (raw == null) return null;
    if (raw is! String) throw const _BridgeError('bad_params', 'description 必须是字符串');
    final text = raw.trim();
    if (text.isEmpty) return null;
    if (text.length > _maxDescriptionLength) {
      throw const _BridgeError('bad_params', 'description 超过 2000 字');
    }
    return text;
  }

  /// 校验标签**真的存在**再写。等外键报错的话只能回一句 internal，
  /// 插件作者看不出是标签 id 写错了。
  Future<List<int>?> _tagIdsOf(Object? raw) async {
    if (raw == null) return null;
    if (raw is! List) throw const _BridgeError('bad_params', 'tagIds 必须是数组');

    final ids = <int>[];
    for (final item in raw) {
      final id = item is int ? item : int.tryParse('$item');
      if (id == null || id <= 0) {
        throw const _BridgeError('bad_params', 'tagIds 里只能放正整数');
      }
      ids.add(id);
    }
    if (ids.isEmpty) return const <int>[];

    final known = (await _tasks.allTags()).map((t) => t.id).toSet();
    final missing = ids.where((id) => !known.contains(id)).toList();
    if (missing.isNotEmpty) {
      throw _BridgeError('bad_params', '标签不存在：${missing.join(",")}');
    }
    return ids;
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

  /// 建任务、改字段、标记完成
  static const String taskWrite = 'task:write';

  /// 删任务。**单独一条**：不可逆，不能和"改标题"共用一个开关。
  static const String taskDelete = 'task:delete';

  static const String tagRead = 'tag:read';
}

class _BridgeError implements Exception {
  const _BridgeError(this.code, this.message);

  final String code;
  final String message;
}
