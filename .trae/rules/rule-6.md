规范 6：代码量控制

适用：文件接近 300 行、类接近 300 行、方法接近 50 行，或需要拆分时。

硬性上限
单文件 500 行；单类 300 行；单方法 50 行。超出必须拆分。

现状（2026-10 核查，别被「文件都合规」误导）：
  文件层：无任何文件超过 500 行（最大 menu_panel_widget.dart = 500 整，贴线）；
  类层：**有 7 处已知超标**，均为待偿还的拆分债，改动时应顺手拆：
    _MenuPanelWidgetState    ≈470  _GameHostPageState       ≈424
    TaskBatchDialogsMixin    ≈426  _ShopPageState           ≈404
    _TaskPageState           ≈400  _TagManagementPageState  ≈395
    TaskRepositoryImpl       ≈384
  即「无超限文件」不等于「无拆分债」——大 State 类躲在合规文件里。

命名约定
提取的 Widget：[功能]_widget.dart（task_card_widget.dart），放同目录；
提取的 Mixin：[功能]_mixin.dart（date_selector_mixin.dart）；
提取的工具类：[功能]_utils.dart（task_sort_utils.dart）。

拆分原则
UI：提取为独立 Widget，数据与回调走构造函数；
逻辑：提取为方法或 Mixin；
Provider：按职责拆分，依赖注入关联；
拆分必须保持公开 API 不变，让消费方零改动。

时机
文件接近 300 行时主动评估；审查时发现超过 500 行必须拆分后再合并；
拆完跑一次静态分析确认无新增问题。

禁止
为拆分而拆分（50 行文件拆成 10 个）；
按行数机械对半切 —— 应按职责 / 生命周期拆分；
拆分后产生循环依赖；
拆分后破坏模块独立性（如把模块内部实现塞进 core）；
把拆分的组件放进非规范目录。

手册
完整操作步骤（含 mixin / part 的语言硬约束、三种拆分方式选型）见
skill dart-large-file-splitting。
