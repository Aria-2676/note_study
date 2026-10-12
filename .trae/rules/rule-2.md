规范 2：统计系统（强制）

适用：新增埋点、修改统计适配器、动统计存储与节流。

架构
统一用 StatisticService.report() 上报，禁止各模块自写统计接口；
适配器：[模块]StatisticAdapter，仅封装统计，不写业务逻辑；
适配器只读取 Provider 数据（listen: false），不得触发 UI 重建；
现有适配器：tasks / shop / points / tag / pomodoro / scratch / profile / games
（基类 core/services/base_statistic_adapter.dart）。

命名
页面访问：page_view_[模块]_[页面]
点击行为：click_[模块]_[动作]
业务计数：count_[模块]_[指标]
系统异常：system_[类型]

数据
time 为事件发生时间，StatisticData 内部统一转 UTC
（默认 DateTime.now().toUtc()，不必手动传）；
计数用 int，行为用 Map，系统信息用 String；
上报异常必须捕获并上报 system_statistic_fail，禁止向外抛（否则拖垮调用方业务）。

时机
页面：initState 上报（禁止在 build 中上报，会重复）；
点击：onPressed 异步上报，不阻塞点击响应；
数据变更：持久化完成之后立即上报（否则会「记了但没存」）。

存储与节流（重要）
统计仅本地存 SharedPreferences，上限 2000 条，超出丢弃最早数据；
当前无任何网络上传通道，因此高频写入必须自行节流；
示例：小游戏局内得分节流为同一局 ≥5 秒一次，
但回合结束的最终分数不受节流限制、必须入账。

维护
新增埋点 key 时在本卡登记，避免重复与遗漏。
