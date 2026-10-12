规范 7：提交、版本与兼容性

提交信息
标题：V5.<minor>.<patch>: 简短描述（概括用户可见变化，不写「修改代码」）；
正文：中文，写清 改了什么 / 为什么 / 怎么验证的；
一次提交只做一件事（功能与其版本号对齐可以是两次提交）。

中文提交信息（极易踩坑）
必须写成 UTF-8 文件后用 git commit -F <文件>；
禁止 git commit -m "中文..."（命令行参数会被非 UTF-8 控制台编码破坏）；
提交后用 git cat-file commit HEAD 做字节级回读确认
（它不含 %，不会被安全过滤器拦截）。

暂存范围
用限定路径（git add lib test），不要 git add -A；
工具产物（.flutter_tool_state、日志、scratch 文件）不得入库；
临时文件一律放 $TEMP，不要放仓库目录。

版本对齐
提交后把 pubspec.yaml 的 version 与提交号对齐（形如 5.5.12+0）。

兼容性
core/ 对外接口（StatisticService.report、VersionUtils.compare、CdnBases.resolve 等）
保持向后兼容；内部实现可替换；
重构 core 能力时，原模块的公开 API 与异常类型必须保持不变（走委托 + 异常转换）。

临时需求
代码内标 // TEMP: <清理时间>-<责任人>，到期必须清理。

规范自身的维护
规则只存在于 .trae/rules/rule-*.md 这一份，不在别处复述（避免多副本失同步）；
设计取舍与历史原因记在 docs/decisions.md；
规则与代码冲突时以代码为准，并同步改规则。
