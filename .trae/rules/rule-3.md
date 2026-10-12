规范 3：工程结构与命名

固定目录
lib/core/：跨模块基础设施，禁止 import 任何 modules/*；
  config（app_config / cdn_bases）、errors、models、router、services、
  storage、updater（更新引擎）、utils；
lib/modules/<业务>/：业务模块，自成一个世界；
  models、services、repositories、providers、pages、widgets、adapters、utils；
lib/providers/：历史遗留的跨模块 Provider 位置（当前仅 app_state 等少数几个）；
  新模块的 Provider 优先放在自己的模块目录下（如 modules/games/providers/）。
lib/ui/：全局 UI 组件。

依赖方向铁律
modules/* → core/* 单向依赖；core 内出现任何 modules 的 import 都算违规；
业务模块之间禁止直接互相引用，交互只能经由 Provider。

命名规则
所有文件：小写 + 下划线（task_provider.dart、app_update_decider.dart），遵循 Dart 官方风格；
类名：大驼峰（TaskProvider、AppUpdateDecider）；
禁止中文、无意义名（page.dart、utils1.dart、helper.dart）；
文件名要能推断内容。

隔离规则
新增模块只加自己的目录，不修改其他模块代码；
模块交互仅通过 Provider，禁止直接调用其他模块的 Service / Repository。
