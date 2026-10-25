import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/extension/extension_slot.dart';
import '../models/calendar_strip_style.dart';
import '../models/task.dart';
import '../pages/v6_home_page.dart';
import '../../core/plugin/plugin_store.dart';
import '../pages/plugin_market_page.dart';
import '../pages/plugin_page.dart';
import '../pages/tag_manager_page.dart';
import '../pages/task_editor_page.dart';
import 'destinations.dart';
import '../state/pending_delete_guard.dart';
import '../state/plugin_market_store.dart';
import '../state/task_store.dart';
import 'profile_stub_page.dart';
import 'side_nav.dart';

/// v6 主包外壳：顶栏（日期）+ 半屏侧边栏 + 首页/我的 + 底栏（首页 · 添加 · 我的）。
///
/// 数据来自 [TaskStore]；四个显示位从 `SlotRegistry` 取插件数据，
/// 没有插件时全部落到主包默认实现（顶栏默认格式、无徽章、无标记、无附加行）。
class MainShell extends StatefulWidget {
  const MainShell({
    super.key,
    required this.store,
    this.marketStore,
    this.pluginLauncher,
    this.recyclePageBuilder,
  });

  final TaskStore store;

  /// 为 null 时"插件市场"入口只提示未接入（测试里不需要整套插件基础设施）
  final PluginMarketStore? marketStore;

  /// 打开已装插件时调用，由应用层提供数据源（`MainShell` 不碰数据库）
  final Future<PluginLaunchSpec> Function(InstalledPlugin plugin)? pluginLauncher;

  /// 回收站页面的构造器。同样由应用层提供 —— `MainShell` 没有仓储层。
  final WidgetBuilder? recyclePageBuilder;

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  static const List<String> _weekday = <String>['一', '二', '三', '四', '五', '六', '日'];

  DateTime _selected = DateTime.now();
  int _tab = 0;
  int _resetSignal = 0;
  CalendarStripStyle _calendarStyle = CalendarStripStyle.scroll;

  /// 用户在弹窗里勾了"以后不再提醒"，但**还没落库**。
  ///
  /// 必须等删除动作完成后再写：`confirmDismiss` 期间一旦调用
  /// `setConfirmBeforeDelete`（它会 notifyListeners），整棵树会在 Dismissible
  /// 正等待结果时重建，真机上会把卡片卡在"完全滑出"的位置 —— 动画不继续、
  /// `onDismissed` 不触发，于是任务既没删掉、也没弹回去。
  bool _pendingDisableConfirm = false;

  /// 已确认删除、正在等 Dismissible 播完动画的任务。
  /// 动画没走完时由它兜底，见 [PendingDeleteGuard]。
  late final PendingDeleteGuard _deletes = PendingDeleteGuard(
    onExpired: (task) {
      // 出现这行说明 Dismissible 的动画没有回调 onDismissed（就是历史上那个 bug）
      debugPrint('[delete] onDismissed 未触发，走兜底删除 taskId=${task.id}');
      _applyDelete(task);
    },
  );

  TaskStore get _store => widget.store;

  String get _defaultDateLabel =>
      '${_selected.month}月${_selected.day}日 周${_weekday[_selected.weekday - 1]}';

  /// 顶栏日期：插件可以换成农历、年月日等任意文本；没插件就用默认格式。
  String get _dateLabel {
    final slot = SlotRegistry.instance.resolve(
      SlotId.headerDate,
      context: <String, Object?>{'date': TaskDate.dayKey(_selected)},
    );
    return slot is HeaderDateValue ? slot.text : _defaultDateLabel;
  }

  Map<DateTime, String>? get _calendarMarks {
    final slot = SlotRegistry.instance.resolve(SlotId.calendarMarks);
    return slot is CalendarMarksValue ? slot.marks : null;
  }

  String? _extraLineFor(Task task) {
    final slot = SlotRegistry.instance.resolve(
      SlotId.taskCardExtra,
      context: <String, Object?>{'taskId': task.id},
    );
    return slot is TaskCardExtraValue ? slot.text : null;
  }

  /// 侧边栏要同时反映任务与已装插件的变化
  late final Listenable _listenable = widget.marketStore == null
      ? _store
      : Listenable.merge(<Listenable>[_store, widget.marketStore!]);

  @override
  void initState() {
    super.initState();
    _store.load(_selected);
    widget.marketStore?.refresh();
  }

  /// 打开已装插件。入口路径、权限都从包内 `plugin.json` 读，
  /// 数据源由应用层通过 [pluginLauncher] 注入。
  Future<void> _openPlugin(InstalledPlugin plugin) async {
    final launcher = widget.pluginLauncher;
    final navigator = Navigator.of(context);
    if (launcher == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('插件运行环境未接入'), duration: Duration(seconds: 1)),
      );
      return;
    }

    try {
      final spec = await launcher(plugin);
      if (!mounted) return;
      navigator.push(
        MaterialPageRoute<void>(
          builder: (_) => PluginPage(
            title: spec.title,
            entryPath: spec.entryPath,
            bridge: spec.bridge,
          ),
        ),
      );
    } catch (error, stack) {
      // 先打完整栈：插件打不开时，界面上只能显示一行字，
      // 真正定位问题靠的还是这里（以前这里只 showSnackBar，栈被吞掉了）
      debugPrint('[plugin] 打开失败：$error\n$stack');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('插件打不开：$error'), duration: const Duration(seconds: 4)),
      );
    }
  }

  /// 改保留时长。改短可能立刻清掉一些条目，得告诉用户清了几条 ——
  /// 否则"我刚改了个设置，回收站里少了几条"会显得像 bug。
  Future<void> _setRetentionDays(int days) async {
    // 改短才可能立刻删东西；改长只是延后，不用问。
    if (days < _store.retentionDays) {
      final wouldPurge = await _store.countRecycleExpiringWith(days);
      if (!mounted) return;

      if (wouldPurge > 0) {
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('缩短保留时长', style: TextStyle(fontSize: 16)),
            content: Text(
              '回收站里有 $wouldPurge 条已经超过 $days 天，继续会立刻彻底删除，无法恢复。',
              style: const TextStyle(fontSize: 13.5),
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('取消'),
              ),
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                style: TextButton.styleFrom(
                  foregroundColor: Theme.of(ctx).colorScheme.error,
                ),
                child: const Text('删除'),
              ),
            ],
          ),
        );
        if (!mounted) return;
        if (confirmed != true) {
          // 取消后 store 没变、也不会 notify，分段按钮的选中态会停在"新值"上，
          // 所以手动 rebuild 一次把它拉回来
          setState(() {});
          return;
        }
      }
    }

    final purged = await _store.setRetentionDays(days);
    if (!mounted || purged == 0) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('已按新的保留时长清理 $purged 条'),
          duration: const Duration(seconds: 3),
        ),
      );
  }

  /// 打开全屏编辑页。删除动作仍由壳层执行（确认框、回收站开关都在这里），
  /// 编辑页只负责"点一下删除，然后告诉我删没删掉"。
  Future<void> _openEditor(Task task) async {
    final navigator = Navigator.of(context);
    final outcome = await navigator.push<TaskEditOutcome>(
      MaterialPageRoute<TaskEditOutcome>(
        builder: (_) => TaskEditorPage(
          store: _store,
          task: task,
          onDelete: () => _deleteFromEditor(task),
        ),
      ),
    );
    if (!mounted || outcome == null) return;

    final text = switch (outcome) {
      TaskEditOutcome.saved => '已保存',
      TaskEditOutcome.deleted => _store.recycleBinEnabled
          ? '「${task.title}」已移入回收站'
          : '「${task.title}」已删除',
    };
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text), duration: const Duration(seconds: 2)));
  }

  /// 编辑页里点删除。返回 true 表示真的删掉了（编辑页据此关掉自己）。
  Future<bool> _deleteFromEditor(Task task) async {
    var disableConfirm = false;
    if (_store.confirmBeforeDelete) {
      final answer = await showDialog<bool>(
        context: context,
        builder: (_) => _DeleteConfirmDialog(
          taskTitle: task.title,
          toRecycle: _store.recycleBinEnabled,
        ),
      );
      if (answer == null) return false;
      disableConfirm = answer;
    }

    await _store.remove(task);
    if (disableConfirm) {
      await _store.setConfirmBeforeDelete(false);
    }
    return true;
  }

  /// 所有入口的唯一分发表。
  ///
  /// **不在这里关抽屉** —— 那样从「我的」页点入口会把主路由 pop 掉。
  /// 关抽屉由侧边栏自己做。
  void _openDestination(AppDestination destination) {
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    if (!destination.ready) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('「${destination.label}」还没接入'),
          duration: const Duration(seconds: 1),
        ),
      );
      return;
    }

    switch (destination) {
      case AppDestination.todayTasks:
        setState(() => _tab = 0);
      case AppDestination.tagManager:
        navigator.push(
          MaterialPageRoute<void>(builder: (_) => TagManagerPage(store: _store)),
        );
      case AppDestination.recycleBin:
        final builder = widget.recyclePageBuilder;
        if (builder == null) {
          messenger.showSnackBar(
            const SnackBar(content: Text('回收站未接入'), duration: Duration(seconds: 1)),
          );
          return;
        }
        navigator.push(MaterialPageRoute<void>(builder: builder));
      case AppDestination.pluginMarket:
        final market = widget.marketStore;
        if (market == null) {
          messenger.showSnackBar(
            const SnackBar(content: Text('插件市场未接入'), duration: Duration(seconds: 1)),
          );
          return;
        }
        navigator.push(
          MaterialPageRoute<void>(builder: (_) => PluginMarketPage(store: market)),
        );
      default:
        break;
    }
  }

  /// 沿用 v5 的习惯：双击顶栏日期回到今天（不放实体按钮，避免破坏观感）
  void _jumpToToday() {
    final today = DateTime.now();
    setState(() {
      _selected = today;
      _resetSignal++;
    });
    _store.load(today);
  }

  void _selectDate(DateTime d) {
    setState(() => _selected = d);
    _store.load(d);
  }

  Future<void> _addTask() async {
    final result = await showDialog<_AddTaskResult>(
      context: context,
      builder: (_) => _AddTaskDialog(tags: _store.tags),
    );
    if (result == null || result.title.trim().isEmpty) return;
    await _store.add(result.title, tagIds: result.tagIds);
  }

  /// 左滑到底时先问一句。返回 false 时 `Dismissible` 会把卡片弹回原位。
  Future<bool> _confirmDelete(Task task) async {
    _pendingDisableConfirm = false;

    if (_store.confirmBeforeDelete) {
      // null = 取消；false = 删除但继续提醒；true = 删除且不再提醒
      final dontAskAgain = await showDialog<bool>(
        context: context,
        builder: (_) => _DeleteConfirmDialog(
        taskTitle: task.title,
        toRecycle: _store.recycleBinEnabled,
      ),
      );
      if (dontAskAgain == null) return false;
      _pendingDisableConfirm = dontAskAgain;
    }

    // **单一出口**：只要放行就登记待删除，不管刚才有没有弹窗。
    // 这行以前只在弹窗分支里执行 —— 关掉确认后 `onDismissed` 就认领不到，
    // 任务只从界面消失、库里还在，切个日期它就复活了。
    _deletes.schedule(task);
    return true;
  }

  void _handleDismissed(Task task) {
    _deletes.cancel(task.id); // 只收尾；删不删由 _applyDelete 自己幂等判断
    _applyDelete(task);
  }

  Future<void> _applyDelete(Task task) async {
    // 幂等：兜底定时器与 onDismissed 可能都走到这里，第二次直接退出
    if (!_store.tasks.any((t) => t.id == task.id)) return;

    final disabledConfirm = _pendingDisableConfirm;
    _pendingDisableConfirm = false;

    await _store.remove(task);
    if (disabledConfirm) {
      await _store.setConfirmBeforeDelete(false);
    }
    if (!mounted) return;

    // 只给一条短提示。"怎么开回来"已经在弹窗里讲过了 ——
    // 放到这里做成长驻横幅既不在视觉中心，又依赖 SnackBar 的自动关闭计时，
    // 一旦计时没起来就会一直挂着。
    final messenger = ScaffoldMessenger.of(context)..hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          [
            if (_store.recycleBinEnabled) '「${task.title}」已移入回收站' else '「${task.title}」已删除',
            if (disabledConfirm) '删除确认已关闭',
          ].join(' · '),
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  void dispose() {
    _deletes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _listenable,
      builder: (context, _) {
        return Scaffold(
          appBar: AppBar(
            centerTitle: true,
            leading: Builder(
              builder: (ctx) => IconButton(
                icon: const Icon(Icons.menu),
                tooltip: '侧边栏',
                onPressed: () => Scaffold.of(ctx).openDrawer(),
              ),
            ),
            title: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onDoubleTap: _jumpToToday,
              child: Text(
                _dateLabel,
                key: const Key('v6-header-date'),
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              ),
            ),
            // 右侧是货币徽章插槽：没有生效货币时**什么都不显示**（见 docs/main-package.md §4.5）
            actions: <Widget>[?_badge],
          ),
          drawer: Drawer(
            width: MediaQuery.sizeOf(context).width * 0.58,
            child: SideNav(
              currentTab: _tab,
              onOpenDestination: _openDestination,
              installedPlugins: widget.marketStore?.installed ?? const <InstalledPlugin>[],
              pluginNameOf: (id) => widget.marketStore?.index.findById(id)?.name ?? id,
              onOpenPlugin: _openPlugin,
            ),
          ),
          body: _buildBody(),
          bottomNavigationBar: _BottomBar(
            index: _tab,
            onSelect: (i) => setState(() => _tab = i),
            onAdd: _addTask,
          ),
        );
      },
    );
  }

  Widget? get _badge {
    final slot = SlotRegistry.instance.resolve(SlotId.currencyBadge);
    if (slot is! CurrencyBadgeValue) return null;
    return _CurrencyBadge(value: slot.value);
  }

  Widget _buildBody() {
    // 只在**首次**还没拿到数据时显示全屏加载。
    // 用 `loading` 判断会让切日期也换掉整棵树，日历条随之销毁重建、滚动位置跳回。
    if (!_store.ready) {
      return const Center(child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2)));
    }

    return IndexedStack(
      index: _tab,
      children: <Widget>[
        V6HomePage(
          selected: _selected,
          tasks: _store.visible,
          tags: _store.tags,
          tagFilter: _store.tagFilter,
          onSelectTag: _store.setTagFilter,
          calendarStyle: _calendarStyle,
          resetSignal: _resetSignal,
          marks: _calendarMarks,
          extraLineFor: _extraLineFor,
          onSelectDate: _selectDate,
          onToggle: _store.toggle,
          onBeforeDelete: _confirmDelete,
          onDeleted: _handleDismissed,
          onEdit: _openEditor,
        ),
        ProfileStubPage(
          calendarStyle: _calendarStyle,
          onCalendarStyleChanged: (s) => setState(() => _calendarStyle = s),
          confirmBeforeDelete: _store.confirmBeforeDelete,
          onConfirmBeforeDeleteChanged: _store.setConfirmBeforeDelete,
          recycleBinEnabled: _store.recycleBinEnabled,
          onRecycleBinChanged: _store.setRecycleBinEnabled,
          retentionDays: _store.retentionDays,
          onRetentionDaysChanged: _setRetentionDays,
          onOpenDestination: _openDestination,
        ),
      ],
    );
  }
}

class _CurrencyBadge extends StatelessWidget {
  const _CurrencyBadge({required this.value});

  final int value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: const Color(0xFFFFB300).withValues(alpha: 0.16),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Icon(Icons.bolt, size: 13, color: Color(0xFFF57F17)),
              const SizedBox(width: 2),
              Text(
                '$value',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFFF57F17),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({required this.index, required this.onSelect, required this.onAdd});

  final int index;
  final ValueChanged<int> onSelect;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return SafeArea(
      top: false,
      child: SizedBox(
        height: 58,
        child: Stack(
          clipBehavior: Clip.none,
          children: <Widget>[
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: scheme.surface,
                  border: Border(top: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.6))),
                ),
                child: Row(
                  children: <Widget>[
                    Expanded(child: _item('首页', 0)),
                    const SizedBox(width: 64),
                    Expanded(child: _item('我的', 1)),
                  ],
                ),
              ),
            ),
            Positioned(
              top: -12,
              left: 0,
              right: 0,
              child: Center(
                child: Material(
                  color: scheme.primary,
                  shape: const CircleBorder(),
                  elevation: 2,
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: onAdd,
                    child: SizedBox(
                      width: 46,
                      height: 46,
                      child: Icon(Icons.add, color: scheme.onPrimary, size: 24),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _item(String label, int i) {
    return Builder(builder: (context) {
      final selected = index == i;
      final scheme = Theme.of(context).colorScheme;
      return InkWell(
        onTap: () => onSelect(i),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              color: selected ? scheme.primary : scheme.onSurfaceVariant,
            ),
          ),
        ),
      );
    });
  }
}

/// 删除确认框。
///
/// 返回值：`null` = 取消；`false` = 删除但继续提醒；`true` = 删除且不再提醒。
class _DeleteConfirmDialog extends StatefulWidget {
  const _DeleteConfirmDialog({required this.taskTitle, required this.toRecycle});

  final String taskTitle;

  /// 决定文案：开着回收站说"移入回收站"，关着就是"彻底删除"。
  /// 以前无论哪种都写"移入回收站"，默认关回收站时会骗人。
  final bool toRecycle;

  @override
  State<_DeleteConfirmDialog> createState() => _DeleteConfirmDialogState();
}

class _DeleteConfirmDialogState extends State<_DeleteConfirmDialog> {
  bool _dontAskAgain = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return AlertDialog(
      title: const Text('删除任务', style: TextStyle(fontSize: 16)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            widget.toRecycle
                ? '「${widget.taskTitle}」将移入回收站。'
                : '「${widget.taskTitle}」将被彻底删除，无法恢复。',
            style: const TextStyle(fontSize: 13.5),
          ),
          const SizedBox(height: 12),
          InkWell(
            borderRadius: BorderRadius.circular(6),
            onTap: () => setState(() => _dontAskAgain = !_dontAskAgain),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: Checkbox(
                      value: _dontAskAgain,
                      visualDensity: VisualDensity.compact,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      onChanged: (v) => setState(() => _dontAskAgain = v ?? false),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '以后不再提醒',
                    style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ),
          // 勾上的那一刻就把后果讲清楚：这里在视觉中心，比事后的底部横幅可靠得多
          if (_dontAskAgain) ...<Widget>[
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Icon(Icons.info_outline, size: 13, color: scheme.primary),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    '关闭后可在「我的 › 删除前确认」重新开启',
                    style: TextStyle(fontSize: 11.5, height: 1.35, color: scheme.primary),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(_dontAskAgain),
          style: TextButton.styleFrom(foregroundColor: scheme.error),
          child: const Text('删除'),
        ),
      ],
    );
  }
}

/// 新建任务的结果：标题 + 选中的标签。
class _AddTaskResult {
  const _AddTaskResult(this.title, this.tagIds);

  final String title;
  final List<int> tagIds;
}

class _AddTaskDialog extends StatefulWidget {
  const _AddTaskDialog({required this.tags});

  /// 可选的标签。为空时不显示这一块，保持"只输入标题"的最短路径。
  final List<Tag> tags;

  @override
  State<_AddTaskDialog> createState() => _AddTaskDialogState();
}

class _AddTaskDialogState extends State<_AddTaskDialog> {
  final TextEditingController _controller = TextEditingController();
  final Set<int> _selected = <int>{};

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() => Navigator.of(context).pop(
        _AddTaskResult(_controller.text, _selected.toList()),
      );

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('新建任务', style: TextStyle(fontSize: 16)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          TextField(
            controller: _controller,
            autofocus: true,
            decoration: const InputDecoration(hintText: '要做什么？', isDense: true),
            onSubmitted: (_) => _submit(),
          ),
          // 没有标签时整块不出现：多数情况下"记一件事"不需要额外操作
          if (widget.tags.isNotEmpty) ...<Widget>[
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: <Widget>[
                for (final tag in widget.tags)
                  FilterChip(
                    label: Text(tag.name),
                    labelStyle: TextStyle(
                      fontSize: 11,
                      color: _selected.contains(tag.id) ? tag.displayColor : null,
                    ),
                    selected: _selected.contains(tag.id),
                    showCheckmark: false,
                    visualDensity: VisualDensity.compact,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    selectedColor: tag.displayColor.withValues(alpha: 0.18),
                    onSelected: (value) => setState(() {
                      if (value) {
                        _selected.add(tag.id);
                      } else {
                        _selected.remove(tag.id);
                      }
                    }),
                  ),
              ],
            ),
          ],
        ],
      ),
      actions: <Widget>[
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('取消')),
        TextButton(onPressed: _submit, child: const Text('添加')),
      ],
    );
  }
}
