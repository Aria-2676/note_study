规范 2：统计系统（强制）
架构约束
统一用 StatisticService.report () 上报，禁止各模块独立写统计接口；
统计适配器：[模块] StatisticAdapter，仅封装统计，不写业务逻辑。
命名规则
页面访问：page_view_模块_页面；
点击行为：click_模块_动作；
业务计数：count_模块_指标。
数据规则
时间为事件发生 UTC 时间；
计数用 int，行为用 Map，系统用 String；
上报异常必须捕获并上报 system_statistic_fail。
上报时机
页面：initState 上报访问；
点击：onPressed 异步上报；
数据变更：持久化后立即上报。