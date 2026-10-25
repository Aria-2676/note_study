import 'package:flutter/foundation.dart';

import '../data/settings_repository.dart';
import '../data/task_repository.dart';
import '../models/task.dart';

/// 首页的数据状态。**只持有"当前这一天"的任务**，不做全量缓存。
///
/// 之所以不用 Provider 包：v6 主包的外壳只需要一个可监听对象，
/// `ChangeNotifier` + `ListenableBuilder` 已经够，少一层依赖少一个失效点。
class TaskStore extends ChangeNotifier {
  TaskStore(this._repo, this._settings);

  final TaskRepository _repo;
  final SettingsRepository _settings;

  DateTime _day = DateTime.now();
  List<Task> _tasks = const <Task>[];
  List<Tag> _tags = const <Tag>[];
  bool _loading = true;
  bool _ready = false;
  bool _settingsLoaded = false;
  bool _confirmBeforeDelete = true;
  bool _recycleBinEnabled = false;
  int _retentionDays = SettingsKeys.defaultRetentionDays;
  String? _tagFilter;

  DateTime get day => _day;
  List<Task> get tasks => _tasks;
  List<Tag> get tags => _tags;
  bool get loading => _loading;

  /// 首次加载是否已经完成。**只用于"要不要显示全屏 loading"**。
  ///
  /// 不能用 `loading` 来判断：切日期时如果把整个 body 换成加载圈，
  /// 日历条会被销毁再重建，滚动位置随之跳回选中日期那一周，
  /// 看起来就是"点一下日期，日历条自己滑了一下"。
  bool get ready => _ready;

  String? get tagFilter => _tagFilter;

  /// 删除前是否弹确认框。默认开，用户勾过"不再提醒"后为 false。
  bool get confirmBeforeDelete => _confirmBeforeDelete;

  Future<void> setConfirmBeforeDelete(bool value) async {
    if (_confirmBeforeDelete == value) return;
    _confirmBeforeDelete = value;
    notifyListeners();
    await _settings.setBool(SettingsKeys.confirmBeforeDelete, value);
  }

  /// 删除后是否先进回收站。**默认关** —— 默认直接删掉，不留垃圾。
  bool get recycleBinEnabled => _recycleBinEnabled;

  Future<void> setRecycleBinEnabled(bool value) async {
    if (_recycleBinEnabled == value) return;
    _recycleBinEnabled = value;
    notifyListeners();
    await _settings.setBool(SettingsKeys.recycleBinEnabled, value);
  }

  /// 回收站保留天数。到期由启动时的清理任务物理删除。
  int get retentionDays => _retentionDays;

  /// 改保留时长。**改短会立刻触发一次清理**，返回被清掉的条数。
  ///
  /// 为什么不让"倒计时"自己生效：清理是机会式的（启动时扫一遍），
  /// 没有后台定时器。如果只改设置不清理，用户会看到"即将清理"却一直挂着，
  /// 直到下次冷启动 —— 界面在骗人。
  Future<int> setRetentionDays(int days) async {
    if (_retentionDays == days) return 0;
    _retentionDays = days;
    notifyListeners();
    await _settings.setInt(SettingsKeys.recycleRetentionDays, days);
    return purgeRecycle();
  }

  /// 按当前保留时长清理过期条目，返回清掉的条数。
  Future<int> purgeRecycle() =>
      _repo.purgeRecycleOlderThan(Duration(days: _retentionDays));

  /// 如果改成 [days] 天，会立刻清掉几条。改短前先问一句用。
  Future<int> countRecycleExpiringWith(int days) =>
      _repo.countRecycleOlderThan(Duration(days: days));

  /// 按标签筛选后的列表。`null` 表示"全部"。
  List<Task> get visible => _tagFilter == null
      ? _tasks
      : _tasks.where((t) => t.tags.any((tag) => tag.name == _tagFilter)).toList();

  void setTagFilter(String? name) {
    if (_tagFilter == name) return;
    _tagFilter = name;
    notifyListeners();
  }

  Future<void> load([DateTime? day]) async {
    if (day != null) {
      _day = DateTime(day.year, day.month, day.day);
    }
    _loading = true;
    notifyListeners();

    if (!_settingsLoaded) {
      _settingsLoaded = true;
      _confirmBeforeDelete = await _settings.getBool(
        SettingsKeys.confirmBeforeDelete,
        fallback: true,
      );
      _recycleBinEnabled = await _settings.getBool(
        SettingsKeys.recycleBinEnabled,
        fallback: false,
      );
      _retentionDays = await _settings.getInt(
        SettingsKeys.recycleRetentionDays,
        fallback: SettingsKeys.defaultRetentionDays,
      );
    }

    _tasks = await _repo.tasksOn(_day);
    _tags = await _repo.allTags();
    _loading = false;
    _ready = true;
    notifyListeners();
  }

  Future<void> toggle(Task task) async {
    await _repo.setDone(task.id, !task.isDone);
    await load();
  }

  Future<void> add(String title, {int? estimatedMinutes, String priority = 'white'}) async {
    final trimmed = title.trim();
    if (trimmed.isEmpty) return;
    await _repo.insert(
      title: trimmed,
      day: _day,
      priority: priority,
      estimatedMinutes: estimatedMinutes,
    );
    await load();
  }

  /// 先摘内存、再删库。
  ///
  /// 顺序不能反：左滑删除时 `Dismissible.onDismissed` 会立刻把 widget 移走，
  /// 如果等数据库回来才 `notifyListeners`，列表重建时会撞上
  /// "dismissed Dismissible is still part of the tree"。
  Future<void> remove(Task task) async {
    final index = _tasks.indexWhere((t) => t.id == task.id);
    if (index < 0) return;

    _tasks = List<Task>.of(_tasks)..removeAt(index);
    notifyListeners();

    try {
      await _repo.delete(task.id, toRecycle: _recycleBinEnabled);
    } catch (_) {
      // 删库失败就把那一条放回原位，界面不能骗人
      final restored = List<Task>.of(_tasks)
        ..insert(index.clamp(0, _tasks.length), task);
      _tasks = restored;
      notifyListeners();
      rethrow;
    }
    await load();
  }
}
