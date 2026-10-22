// v6 扩展位骨架的契约测试。
//
// 这里测的不是"能不能跑"，而是 rule-8 写死的几条**降级承诺**：
//   - 插槽：无提供者 / 类型不符 / 提供者抛异常 → 一律返回 null，绝不抛给 UI
//   - 钩子：无人订阅不报错；某个监听器抛异常或卡住，不得影响其他监听器与主流程
//   - 货币：卸载当前生效货币后，active 必须置空（不自动回落）
//   - 卸载：detachPlugin 必须把四处一起摘干净

import 'package:flutter_test/flutter_test.dart';
import 'package:v5_app/core/extension/extension_host.dart';

class _FakeSlotProvider implements SlotProvider {
  _FakeSlotProvider({
    required this.pluginId,
    required this.slots,
    required this.onProvide,
  });

  @override
  final String pluginId;

  @override
  final Set<SlotId> slots;

  final SlotValue? Function(SlotId slot) onProvide;

  @override
  SlotValue? provide(SlotId slot, Map<String, Object?> context) => onProvide(slot);
}

class _FakeListener implements HookListener {
  _FakeListener({
    required this.pluginId,
    required this.hooks,
    required this.onEventCallback,
  });

  @override
  final String pluginId;

  @override
  final Set<HookId> hooks;

  final Future<void> Function(HookEvent event) onEventCallback;

  @override
  Future<void> onEvent(HookEvent event) => onEventCallback(event);
}

class _FakeCurrency implements CurrencyDefinition {
  _FakeCurrency(this.id, {this.priority = 0});

  @override
  final String id;

  @override
  final int priority;

  int _balance = 100;

  @override
  String get displayName => id;

  @override
  Future<int> balance() async => _balance;

  @override
  Future<void> earn(int amount, {required String reason, String source = 'manual'}) async {
    _balance += amount;
  }

  @override
  Future<bool> spend(int amount, {required String reason, String source = 'manual'}) async {
    if (_balance < amount) return false;
    _balance -= amount;
    return true;
  }

  @override
  Future<List<CurrencyRecord>> records({int limit = 50}) async => const <CurrencyRecord>[];
}

void main() {
  setUp(ExtensionHost.resetForTest);
  tearDown(ExtensionHost.resetForTest);

  group('插槽 SlotRegistry', () {
    test('没有提供者时返回 null（主包走默认实现）', () {
      expect(ExtensionHost.slots.resolve(SlotId.headerDate), isNull);
    });

    test('值类型与插槽不符时视为无效，返回 null', () {
      ExtensionHost.slots.register(_FakeSlotProvider(
        pluginId: 'wrong-type',
        slots: {SlotId.currencyBadge},
        onProvide: (_) => const HeaderDateValue('10月22日 周四'),
      ));

      expect(ExtensionHost.slots.resolve(SlotId.currencyBadge), isNull);
    });

    test('提供者抛异常时被跳过，不影响后续提供者', () {
      ExtensionHost.slots.register(_FakeSlotProvider(
        pluginId: 'broken',
        slots: {SlotId.headerDate},
        onProvide: (_) => throw StateError('plugin crashed'),
      ));
      ExtensionHost.slots.register(_FakeSlotProvider(
        pluginId: 'healthy',
        slots: {SlotId.headerDate},
        onProvide: (_) => const HeaderDateValue('10月23日 周五'),
      ));

      final resolved = ExtensionHost.slots.resolve(SlotId.headerDate);
      expect(resolved, isA<HeaderDateValue>());
      expect((resolved! as HeaderDateValue).text, '10月23日 周五');
    });

    test('返回 null 表示不参与，继续问下一个提供者', () {
      ExtensionHost.slots.register(_FakeSlotProvider(
        pluginId: 'abstain',
        slots: {SlotId.headerDate},
        onProvide: (_) => null,
      ));

      expect(ExtensionHost.slots.resolve(SlotId.headerDate), isNull);
    });
  });

  group('钩子 HookBus', () {
    test('无人订阅时派发不报错，且能正常返回', () async {
      await expectLater(ExtensionHost.hooks.emit(HookId.taskCompleted), completes);
    });

    test('某个监听器抛异常，不影响其他监听器，也不抛给调用方', () async {
      var healthyCalled = 0;
      ExtensionHost.hooks.register(_FakeListener(
        pluginId: 'broken',
        hooks: {HookId.taskCompleted},
        onEventCallback: (_) async => throw StateError('boom'),
      ));
      ExtensionHost.hooks.register(_FakeListener(
        pluginId: 'healthy',
        hooks: {HookId.taskCompleted},
        onEventCallback: (_) async => healthyCalled++,
      ));

      await expectLater(ExtensionHost.hooks.emit(HookId.taskCompleted), completes);
      expect(healthyCalled, 1);
    });

    test('监听器卡住时，派发在超时后返回，不被拖死', () async {
      ExtensionHost.hooks.register(_FakeListener(
        pluginId: 'slow',
        hooks: {HookId.taskCompleted},
        onEventCallback: (_) => Future<void>.delayed(const Duration(milliseconds: 300)),
      ));

      final started = DateTime.now();
      await ExtensionHost.hooks.emit(
        HookId.taskCompleted,
        timeout: const Duration(milliseconds: 50),
      );
      final elapsed = DateTime.now().difference(started);

      expect(elapsed, lessThan(const Duration(milliseconds: 200)));
    });
  });

  group('货币 CurrencyRegistry', () {
    test('切换未安装的货币被拒绝，状态不变', () {
      expect(ExtensionHost.currencies.setActive('nope'), isFalse);
      expect(ExtensionHost.currencies.activeId, isNull);
    });

    test('卸载当前生效货币后 active 置空，不自动回落到另一套', () {
      ExtensionHost.currencies.register(_FakeCurrency('energy', priority: 1));
      ExtensionHost.currencies.register(_FakeCurrency('points', priority: 2));
      ExtensionHost.currencies.setActive('points');

      ExtensionHost.currencies.unregister('points');

      expect(ExtensionHost.currencies.activeId, isNull);
      expect(ExtensionHost.currencies.active, isNull);
      expect(ExtensionHost.currencies.isInstalled('energy'), isTrue);
    });

    test('installed 按 priority 降序', () {
      ExtensionHost.currencies.register(_FakeCurrency('energy', priority: 1));
      ExtensionHost.currencies.register(_FakeCurrency('points', priority: 2));

      expect(
        ExtensionHost.currencies.installed.map((c) => c.id).toList(),
        ['points', 'energy'],
      );
    });
  });

  group('入口 EntryRegistry', () {
    test('按 order 升序，同 order 按 label 稳定排序', () {
      ExtensionHost.entries.registerAll(const [
        PluginEntry(pluginId: 'b', where: EntryWhere.sidebar, label: '统计', order: 20),
        PluginEntry(pluginId: 'a', where: EntryWhere.sidebar, label: '番茄钟', order: 10),
        PluginEntry(pluginId: 'c', where: EntryWhere.profile, label: '积分明细', order: 5),
      ]);

      final sidebar = ExtensionHost.entries.entriesFor(EntryWhere.sidebar);
      expect(sidebar.map((e) => e.pluginId).toList(), ['a', 'b']);
      expect(ExtensionHost.entries.entriesFor(EntryWhere.profile), hasLength(1));
    });
  });

  group('ExtensionHost.detachPlugin', () {
    test('一次摘干净四类注册', () async {
      const pid = 'pomodoro';
      ExtensionHost.slots.register(_FakeSlotProvider(
        pluginId: pid,
        slots: {SlotId.headerDate},
        onProvide: (_) => const HeaderDateValue('x'),
      ));
      ExtensionHost.hooks.register(_FakeListener(
        pluginId: pid,
        hooks: {HookId.taskCompleted},
        onEventCallback: (_) async {},
      ));
      ExtensionHost.currencies.register(_FakeCurrency(pid));
      ExtensionHost.currencies.setActive(pid);
      ExtensionHost.entries.registerAll(const [
        PluginEntry(pluginId: pid, where: EntryWhere.sidebar, label: '番茄钟'),
      ]);

      ExtensionHost.detachPlugin(pid);

      expect(ExtensionHost.slots.resolve(SlotId.headerDate), isNull);
      expect(ExtensionHost.hooks.listenerCount(HookId.taskCompleted), 0);
      expect(ExtensionHost.currencies.isInstalled(pid), isFalse);
      expect(ExtensionHost.currencies.activeId, isNull);
      expect(ExtensionHost.entries.entriesFor(EntryWhere.sidebar), isEmpty);
    });
  });
}
