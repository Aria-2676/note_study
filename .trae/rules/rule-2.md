规范 2：统计系统（强制）

架构约束
统一用 StatisticService.report() 上报，禁止各模块独立写统计接口；
统计适配器：[模块]StatisticAdapter，仅封装统计，不写业务逻辑；
适配器只读取 Provider 数据（listen: false），不得触发 UI 重建。

命名规则
页面访问：page_view_[模块]_[页面]；
点击行为：click_[模块]_[动作]；
业务计数：count_[模块]_[指标]；
系统异常：system_[类型]。

数据规则
time 必须为事件发生时间，StatisticData 内部统一转 UTC（默认 DateTime.now().toUtc()）；
计数用 int，行为用 Map，系统用 String；
上报异常必须捕获并上报 system_statistic_fail，禁止向外抛（否则拖垮调用方业务）。

上报时机
页面：initState 上报访问（禁止在 build 中上报，会重复）；
点击：onPressed 异步上报，不得阻塞点击响应；
数据变更：持久化完成之后立即上报（否则会「记了但没存」）。

存储限制与节流（重要）
统计仅本地存于 SharedPreferences，上限 2000 条，超出丢弃最早数据；
当前无任何网络上传通道，因此高频写入必须自行节流；
示例：小游戏局内得分节流为同一局 ≥5 秒一次，但回合结束的最终分数不受节流限制、必须入账。

新增埋点 key 时，同步登记到 docs/重构后项目开发规范.md 的统计项登记表。
