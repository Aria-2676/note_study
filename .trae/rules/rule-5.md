规范 5：单元测试规范（强制）

测试覆盖要求
新增 Provider 必须编写单元测试，覆盖初始化、核心业务方法、notifyListeners 触发时机、
依赖注入正确性；
新增 Model 必须编写单元测试，验证默认值、copyWith、序列化/反序列化（含非法输入）；
纯函数与决策逻辑（如 AppUpdateDecider、VersionUtils）必须做到分支级覆盖；
Widget 逻辑测试：复杂 UI 组件需编写测试验证显示逻辑与交互回调。

测试文件位置
test/ 与 lib/ 不是严格 1:1，按领域松散组织：
test/providers/ - Provider 测试
test/models/ - Model 测试
test/widgets/ - Widget 测试
test/services/ - 服务层测试
test/errors/ - 错误处理测试
test/utils/ - 工具类测试
test/core/ - 与 lib/core 同构（如 test/core/updater/、test/core/utils/）

测试命名规则
测试文件：[原文件名]_test.dart（如 app_update_decider_test.dart）；
测试组：group('[类名/功能名]', () {})；
测试用例：test('[条件] → [预期]')，用中文写清条件与预期。

Mock 使用规范
使用 mockito 生成 Mock 类，通过 @GenerateMocks 注解；
Provider 测试需 Mock 依赖的 Repository 和其他 Provider；
每个测试前重置 Mock 状态（setUp 中调用 clearInteractions）；
使用 when().thenReturn() / when().thenAnswer() 模拟返回值；
断言「调用了几次」时用 thenAnswer 内的本地计数器，不要连续 verify(...).called(n)。

测试运行要求
提交代码前运行 flutter test 确保所有测试通过；
新增功能必须伴随新增测试，禁止提交无测试的新功能；
测试覆盖率不低于 70%；
测试必须能失败 —— 写完故意破坏一次实现确认它变红，只断言「没抛异常」的测试没有价值。
