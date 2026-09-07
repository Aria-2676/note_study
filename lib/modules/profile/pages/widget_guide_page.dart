import 'package:flutter/material.dart';
import '../../../core/services/widget_service.dart';

class WidgetGuidePage extends StatefulWidget {
  const WidgetGuidePage({super.key});

  @override
  State<WidgetGuidePage> createState() => _WidgetGuidePageState();
}

class _WidgetGuidePageState extends State<WidgetGuidePage> {
  bool _isWidgetAdded = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _checkWidgetStatus();
  }

  Future<void> _checkWidgetStatus() async {
    final isAdded = await WidgetService.isWidgetAdded();
    setState(() {
      _isWidgetAdded = isAdded;
      _isLoading = false;
    });
  }

  Future<void> _addWidget() async {
    await WidgetService.requestAddWidget();
    await Future.delayed(const Duration(seconds: 2));
    await _checkWidgetStatus();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('添加桌面小组件'), centerTitle: true),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Card(
                    color: _isWidgetAdded ? Colors.green.shade50 : Colors.orange.shade50,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Icon(_isWidgetAdded ? Icons.check_circle : Icons.info, color: _isWidgetAdded ? Colors.green : Colors.orange, size: 32),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(_isWidgetAdded ? '小组件已添加' : '小组件未添加',
                                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _isWidgetAdded ? Colors.green : Colors.orange)),
                                const SizedBox(height: 4),
                                Text(_isWidgetAdded ? '您已成功添加桌面小组件，可以在桌面查看今日任务' : '添加桌面小组件，快速查看今日任务和积分',
                                    style: TextStyle(color: _isWidgetAdded ? Colors.green.shade700 : Colors.orange.shade700)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text('小组件预览', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey.shade300),
                      boxShadow: [BoxShadow(color: Colors.grey.shade200, blurRadius: 8, offset: const Offset(0, 4))],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Text('今日任务', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(color: Colors.amber.shade100, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.amber)),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [Icon(Icons.stars, color: Colors.amber.shade700, size: 14), const SizedBox(width: 4), Text('100', style: TextStyle(color: Colors.amber.shade700, fontWeight: FontWeight.bold, fontSize: 12))],
                              ),
                            ),
                          ],
                        ),
                        const Divider(height: 16),
                        _buildPreviewTask('完成数学作业', false, 20),
                        _buildPreviewTask('背单词50个', true, 10),
                        _buildPreviewTask('运动30分钟', false, 15),
                        const SizedBox(height: 8),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(color: Colors.blue, borderRadius: BorderRadius.circular(8)),
                          child: const Text('打开应用', textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text('添加方式', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  _buildStepCard(step: '1', title: '长按桌面空白处', description: '在手机桌面空白区域长按，进入桌面编辑模式', icon: Icons.touch_app),
                  _buildStepCard(step: '2', title: '选择"小组件"', description: '点击底部或弹出的"小组件"选项', icon: Icons.widgets),
                  _buildStepCard(step: '3', title: '找到任务管家', description: '在小组件列表中找到"任务管家"', icon: Icons.search),
                  _buildStepCard(step: '4', title: '添加到桌面', description: '长按小组件并拖动到桌面合适位置', icon: Icons.add_circle),
                  const SizedBox(height: 24),
                  if (!_isWidgetAdded) ...[
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _addWidget,
                        icon: const Icon(Icons.widgets),
                        label: const Text('一键添加小组件'),
                        style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16), backgroundColor: Colors.indigo, foregroundColor: Colors.white),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text('注：部分手机系统可能不支持一键添加，请按照上述步骤手动添加', style: TextStyle(fontSize: 12, color: Colors.grey), textAlign: TextAlign.center),
                  ] else ...[
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.check),
                        label: const Text('完成'),
                        style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16), backgroundColor: Colors.green, foregroundColor: Colors.white),
                      ),
                    ),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _buildPreviewTask(String title, bool isCompleted, int points) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(isCompleted ? Icons.check_box : Icons.check_box_outline_blank, color: isCompleted ? Colors.green : Colors.grey, size: 20),
          const SizedBox(width: 8),
          Expanded(child: Text(title, style: TextStyle(decoration: isCompleted ? TextDecoration.lineThrough : null, color: isCompleted ? Colors.grey : Colors.black))),
          if (points > 0) Text('+$points', style: TextStyle(color: Colors.amber.shade700, fontSize: 12, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildStepCard({required String step, required String title, required String description, required IconData icon}) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Container(width: 32, height: 32, decoration: BoxDecoration(color: Colors.indigo, borderRadius: BorderRadius.circular(16)), child: Center(child: Text(step, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)))),
        title: Text(title),
        subtitle: Text(description),
        trailing: Icon(icon, color: Colors.indigo),
      ),
    );
  }
}