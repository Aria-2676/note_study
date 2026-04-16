规范 1：Provider 状态管理（强制）
注册规则
无依赖 Provider（AppState/Settings/Points/Tag）用 ChangeNotifierProvider；
依赖型（Task/Shop 依赖 Points）用 ChangeNotifierProxyProvider；
注册顺序：AppState → Settings → Points → Tag → Shop → Task；
ProxyProvider create 用 context.read<PointsProvider>()，update 仅更新依赖并判空。
使用规则
只读数据：Provider.of<T>(context, listen: false)；
监听刷新：Provider.of<T>(context) / Consumer；
职责隔离：Points 管积分、Task 管任务、Shop 管商城，禁止跨域处理。
禁止行为
禁止页面直接修改 Provider 私有变量；
禁止非业务逻辑调用 notifyListeners ()。