规范 5：单元测试（强制）

适用：写/改测试、评估覆盖率、决定某个类该测什么。

覆盖要求
新增 Provider：初始化、核心方法、notifyListeners 触发时机、依赖注入；
新增 Model：默认值、copyWith、序列化/反序列化（含非法输入）；
纯函数与决策逻辑（AppUpdateDecider、VersionUtils 等）必须做到分支级覆盖；
复杂 UI 组件：条件渲染与交互回调。

测试位置
test/ 与 lib/ 不是严格 1:1，按领域松散组织：
  test/adapters  test/core  test/errors  test/models  test/providers
  test/repositories  test/services  test/utils  test/widgets
test/core/ 与 lib/core/ 同构（如 test/core/updater/、test/core/utils/）。

命名
文件：[原文件名]_test.dart（如 app_update_decider_test.dart）
分组：group('[类名/功能名]', () {})
用例：test('[条件] → [预期]')，中文写清条件与预期。

Mock
mockito + @GenerateMocks；
Provider 测试必须 mock 依赖的 Repository 与其他 Provider；
每个 test 前 clearInteractions(mock)；
需要真实 SQL 的仓储测试用 sqflite_common_ffi（dev 依赖，已配好，无需准备 dll）；
断言「调用了几次」用 thenAnswer 内的本地计数器，
不要连续 verify(...).called(n)（计数不可靠）。

运行与判据
提交前 flutter test 全绿；新增功能必须伴随新增测试；覆盖率 ≥ 70%；
测试必须能失败 —— 写完故意破坏一次实现确认它变红；
只断言「没抛异常」的测试没有价值。

环境起不来时
本机 Dart 运行时可能无法创建子进程导致 flutter test 无法启动，
此时走 skill flutter-offline-verification 做等价验证，
并**必须说明覆盖边界**（插件层与 UI 层仅静态分析覆盖）。
