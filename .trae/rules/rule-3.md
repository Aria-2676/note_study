规范 3：工程结构与依赖方向

适用：新建目录/文件/模块，或判断某段逻辑该放在 core 还是某个 modules 下。

目录结构
lib/core/            跨模块基础设施
  config/            app_config（常量、DB 名与版本）、cdn_bases（CDN 基址唯一来源）
  errors/            app_error / error_handler / result
  models/            base_model、statistic_data
  router/            app_router
  services/          基础服务：database/（按域拆 mixin）、widget_service、
                     statistic_service、file_downloader、zip_extractor
  storage/           storage_manager
  updater/           更新引擎：models / services / providers / widgets / pages
  utils/             通用工具：version_utils、date_utils、num_utils、string_utils…
lib/modules/<业务>/  业务模块，自成一个世界，内部结构：
  models / services / repositories / providers / pages / widgets / adapters / utils
lib/providers/       核心 Provider 的当前实现位置（9 个文件 + mixins/）
                     新模块的 Provider 优先放自己的模块目录下
lib/ui/              全局 UI 组件
lib/main.dart        v5 入口：服务初始化 + MultiProvider + 路由

依赖方向（铁律）
modules/* → core/* 单向依赖；
业务模块之间禁止直接互相引用，交互只能经由 Provider。

core → modules 是**目标态**，当前有已知例外（勿"顺手修正"，改错会编译失败）：
  1. core/router/app_router.dart —— 路由表必须引用各模块的 Page，天然例外；
  2. core/services/database/database_*_mixin.dart（task/pomodoro/points/purchase/
     scratch/shop/tag 七个）—— 按域拆分的 DB mixin 需要各模块的 model 建表/映射；
  3. core/utils/task_sort_utils.dart —— 依赖 Task model 与 TaskSortOption 枚举。
这些例外是**已知技术债**，不要再新加；新增 core 代码仍须遵守单向依赖。

命名
目录与文件：小写 + 下划线（task_provider.dart）；类名：大驼峰（TaskProvider）；
禁中文、禁无意义名（page.dart、utils1.dart、helper.dart）；文件名要能推断内容。

隔离
新增模块只加自己的目录，不修改其他模块代码；
模块交互仅通过 Provider，禁止直接调用其他模块的 Service / Repository。

为什么这么定（易被忽略的取舍）
- core 不得依赖 modules：core 是「所有模块的地基」，一旦反向依赖，
  它就无法被单独测试与复用，且模块增删会波及全项目。
- 「业务模块完全独立」是目标而非现状：模块间确有经由 Provider 的数据流动，
  但那是运行时依赖，不是编译期依赖——代码里不该出现跨模块 import
  （core → modules 的已知例外见上文，不在此列）。
- lib/providers/ 不是废弃目录：rule-1 列的 11 个 Provider 里，除 AppUpdate
  在 core/updater/providers/ 外，其余**全部**实现在这里（含 7 个 import modules
  的文件，见上文已知例外）。它同时是「跨模块 Provider 的落脚点」，
  但**新代码不要往这里加** —— 新 Provider 随模块走。

v6 并行目录（2026-10 起，与 v5 并存、逐步替换）
```
lib/core/extension/  扩展位：插槽 / 钩子 / 货币 / 入口（只依赖 core 内部）
lib/core/data/       v6 数据层：v6_schema、v6_database、v6_plugin_tables
lib/app/             v6 主包：models/ data/（唯一写 tasks 表）state/ shell/ pages/ widgets/
lib/main_v6_preview.dart  预览入口（flutter run -t 它），不影响 main.dart
```
依赖：`app → core`；`core/{data,extension}` 不得依赖 `modules/`、`app/`；`app/` 不得依赖 `modules/`；v6 完成后 v5 的 `modules/`、`providers/` 逐块移除。与本卡配套读「插件边界」。
