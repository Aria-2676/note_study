// v6 扩展位统一入口。
//
// ⚠️ 骨架阶段：v5 现有代码**尚未接线**，这里只有接口与注册表。
// 主包重写时，UI 数据源、任务完成流程、货币展示都从这里取。
//
// 四类扩展位（详见 docs/main-package.md §6）：
//   插槽 SlotRegistry      —— 区域级，插件只供数据，主包渲染
//   钩子 HookBus           —— 行为级，通知不拦截，超时不阻塞
//   货币 CurrencyRegistry  —— 服务级，框架在主包、实现全在插件
//   入口 EntryRegistry     —— 导航级，插件只声明，主包渲染

export 'extension_currency.dart';
export 'extension_entry.dart';
export 'extension_hook.dart';
export 'extension_slot.dart';

import 'extension_currency.dart';
import 'extension_entry.dart';
import 'extension_hook.dart';
import 'extension_slot.dart';

class ExtensionHost {
  ExtensionHost._();

  static SlotRegistry get slots => SlotRegistry.instance;

  static HookBus get hooks => HookBus.instance;

  static CurrencyRegistry get currencies => CurrencyRegistry.instance;

  static EntryRegistry get entries => EntryRegistry.instance;

  /// 卸载插件时的**唯一清理入口**：四处一起摘。
  ///
  /// 单独提供这个方法，是因为"卸载时漏摘一处"是最容易发生的 bug——
  /// 调用方不该自己逐个 unregister。
  static void detachPlugin(String pluginId) {
    slots.unregister(pluginId);
    hooks.unregister(pluginId);
    currencies.unregister(pluginId);
    entries.unregister(pluginId);
  }

  /// 仅测试用：把四个注册表全部清空，避免单例状态跨用例泄漏。
  static void resetForTest() {
    slots.clear();
    hooks.clear();
    currencies.clear();
    entries.clear();
  }
}
