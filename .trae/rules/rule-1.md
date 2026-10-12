规范 1：Provider 状态管理（强制）

注册
无依赖 Provider 用 ChangeNotifierProvider；
依赖型（Task / Shop / Game 依赖 Points）用 ChangeNotifierProxyProvider；
全部在 main.dart 的 MultiProvider 中集中注册，禁止页面内零散注册；
注册顺序：被依赖者必须先于依赖者创建。实际顺序为
  AppState → Settings → Points → Tag → Pomodoro → Scratch → Statistics
  → Shop → Game → Task → AppUpdate
  （AppUpdate 无依赖但排在最后，位置无特殊含义）；
ProxyProvider 的 create 用 context.read<PointsProvider>()，
update 仅更新依赖引用并判空，禁止在其中写业务逻辑。

使用
只读数据：Provider.of<T>(context, listen: false)；
监听刷新：Provider.of<T>(context) / Consumer<T>；
非 Widget 层（Adapter / Service / Repository）禁止 listen: true；
UI 层禁止直接实例化 Provider 或修改其私有状态。

职责边界（现有 11 个）
AppState    全局应用状态（无依赖）
Settings    设置：主题 / 语言 / 开关（无依赖）
Points      积分增减与查询（无依赖）
Tag         标签管理（无依赖）
Pomodoro    番茄钟计时与记录（无依赖）
Scratch     刮刮乐玩法状态（无依赖）
Statistics  统计查询视图（无依赖；写入走 StatisticService）
AppUpdate   更新检查与决策状态（无依赖；下载安装委托 launcher）
Shop        商品与兑换（依赖 Points）
Game        小游戏目录 / 安装 / 计分（依赖 Points）
Task        任务增删改查与完成（依赖 Points）

禁止
跨域处理（Points 管积分、Task 管任务、Shop 管商城、Game 管游戏）；
非业务状态变化时调用 notifyListeners()；
高频回调直接通知 —— 必须先去重（如进度按整数百分比），否则 UI 重建风暴。

新增 Provider 前先自问：能否并入既有 Provider？职责确实独立才新建，并在本卡登记。
