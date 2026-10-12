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
lib/providers/       历史遗留的跨模块 Provider（仅 app_state 等少数几个）
                     新模块的 Provider 优先放自己的模块目录下
lib/ui/              全局 UI 组件
lib/main.dart        入口：服务初始化 + MultiProvider + 路由

依赖方向（铁律）
modules/* → core/* 单向依赖；
core 内出现任何 modules 的 import 都算违规，无法举例也无法豁免；
业务模块之间禁止直接互相引用，交互只能经由 Provider。

命名
目录与文件：小写 + 下划线（task_provider.dart、app_update_decider.dart）；
类名：大驼峰（TaskProvider、AppUpdateDecider）；
禁止中文、禁止无意义名（page.dart、utils1.dart、helper.dart）；
文件名要能推断内容。

隔离
新增模块只加自己的目录，不修改其他模块代码；
模块交互仅通过 Provider，禁止直接调用其他模块的 Service / Repository。

为什么这么定（易被忽略的取舍）
- core 不得依赖 modules：core 是「所有模块的地基」，一旦反向依赖，
  它就无法被单独测试与复用，且模块增删会波及全项目。
- 「业务模块完全独立」是目标而非现状：模块间确有经由 Provider 的数据流动，
  但那是运行时依赖，不是编译期依赖——代码里不该出现跨模块 import。
- lib/providers/ 是历史包袱：早期所有 Provider 集中于此，后改为随模块走。
  新代码不要往 lib/providers/ 加东西。
