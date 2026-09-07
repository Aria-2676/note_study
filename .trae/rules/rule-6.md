规范 6：代码量控制规范（强制）
单文件行数限制
单个文件不超过 500 行，超出必须拆分；
单个类/Widget 不超过 300 行，超出必须提取组件；
单个方法不超过 50 行，超出必须拆分子方法。
拆分原则
UI 组件拆分：提取为独立 Widget 文件，放入同目录下；
逻辑拆分：提取为独立方法或 Mixin；
Provider 拆分：按职责拆分为多个 Provider，通过依赖注入关联。
拆分时机
开发中发现文件超过 300 行时，主动评估是否需要拆分；
代码审查时发现超过 500 行的文件，必须拆分后再合并。
命名约定
提取的 Widget 文件：[功能]_widget.dart（如 task_card_widget.dart）
提取的 Mixin：[功能]_mixin.dart（如 date_selector_mixin.dart）
提取的工具类：[功能]_utils.dart（如 task_filter_utils.dart）
拆分示例
拆分前：task_page.dart（2283 行）→ 拆分后：task_page.dart（828 行）+ 多个组件文件
禁止行为
禁止为拆分而拆分（如 50 行文件拆成 10 个文件）；
禁止拆分后产生循环依赖；
禁止拆分后破坏模块独立性；
禁止将拆分的组件放入非规范目录（如新建 widgets/ 目录）。
