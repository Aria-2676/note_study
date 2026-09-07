规范 5：单元测试规范（强制）
测试覆盖要求
新增 Provider 必须编写单元测试，覆盖核心业务方法；
新增 Model 必须编写单元测试，验证数据转换和默认值；
Widget 逻辑测试：复杂 UI 组件需编写测试验证显示逻辑。
测试文件位置
test/providers/ - Provider 测试
test/models/ - Model 测试
test/widgets/ - Widget 测试
test/services/ - 服务层测试
test/errors/ - 错误处理测试
test/utils/ - 工具类测试
测试命名规则
测试文件：[原文件名]_test.dart（如 task_provider_test.dart）
测试组：group('[类名/功能名]', () {})
测试用例：test('should [预期行为]', () {})
Mock 使用规范
使用 mockito 生成 Mock 类，通过 @GenerateMocks 注解；
Provider 测试需 Mock 依赖的 Repository 和其他 Provider；
每个测试前重置 Mock 状态（setUp 中调用 clearInteractions）；
使用 when().thenReturn() / when().thenAnswer() 模拟返回值。
测试运行要求
提交代码前运行 flutter test 确保所有测试通过；
新增功能必须伴随新增测试，禁止提交无测试的新功能；
测试覆盖率不低于 70%。
