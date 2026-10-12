规范 1：Provider 状态管理（强制）

注册规则
无依赖 Provider 用 ChangeNotifierProvider；
依赖型（Task / Shop / Game 依赖 Points）用 ChangeNotifierProxyProvider；
注册顺序：无依赖在前、依赖型在后（被依赖者必须先创建），实际顺序为：
  AppState → Settings → Points → Tag → Pomodoro → Scratch → Statistics
  → Shop → Game → Task → AppUpdate（AppUpdate 虽无依赖，但排在最后）。
ProxyProvider 的 create 用 context.read<PointsProvider>()，update 仅更新依赖并判空。

使用规则
只读数据：Provider.of<T>(context, listen: false)；
监听刷新：Provider.of<T>(context) / Consumer<T>；
职责隔离：Points 管积分、Task 管任务、Shop 管商城、Game 管游戏，禁止跨域处理；
非 Widget 层（Adapter / Service / Repository）禁止 listen: true。

禁止行为
禁止页面直接修改 Provider 私有变量；
禁止在 ProxyProvider 的 update 中写业务逻辑；
禁止非业务状态变化时调用 notifyListeners()；
高频回调（下载/进度类）必须先按整数百分比去重再通知，避免 UI 重建风暴。

新增 Provider 前先自问：能否并入既有 Provider？职责确实独立才新建。
