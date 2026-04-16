import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/settings_provider.dart';

class TaskCreateSettingsPage extends StatelessWidget {
  const TaskCreateSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final settingsProvider = context.watch<SettingsProvider>();
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('任务创建设置'), centerTitle: true),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '创建模式',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '选择任务创建时显示的编辑项',
                    style: TextStyle(
                      fontSize: 14,
                      color: colorScheme.onSurface.withValues(alpha: 0.7),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildModeOption(
                    context,
                    title: '极简模式',
                    subtitle: '只显示任务名称输入框',
                    mode: TaskCreateMode.minimal,
                    currentMode: settingsProvider.taskCreateMode,
                    onTap: () => settingsProvider.setTaskCreateMode(
                      TaskCreateMode.minimal,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildModeOption(
                    context,
                    title: '完整模式',
                    subtitle: '显示所有编辑项',
                    mode: TaskCreateMode.full,
                    currentMode: settingsProvider.taskCreateMode,
                    onTap: () =>
                        settingsProvider.setTaskCreateMode(TaskCreateMode.full),
                  ),
                  const SizedBox(height: 8),
                  _buildModeOption(
                    context,
                    title: '自定义模式',
                    subtitle: '自定义显示的编辑项',
                    mode: TaskCreateMode.custom,
                    currentMode: settingsProvider.taskCreateMode,
                    onTap: () => settingsProvider.setTaskCreateMode(
                      TaskCreateMode.custom,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (settingsProvider.taskCreateMode == TaskCreateMode.custom) ...[
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '自定义编辑项',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: colorScheme.onSurface,
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            final defaultFields = <String>{};
                            for (final field in TaskCreateFields.all) {
                              if (field.defaultEnabled) {
                                defaultFields.add(field.key);
                              }
                            }
                            settingsProvider.setEnabledCreateFields(
                              defaultFields,
                            );
                          },
                          child: const Text('恢复默认'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '勾选要在创建任务时显示的编辑项',
                      style: TextStyle(
                        fontSize: 14,
                        color: colorScheme.onSurface.withValues(alpha: 0.7),
                      ),
                    ),
                    const SizedBox(height: 16),
                    ...TaskCreateFields.all.map(
                      (field) => _buildFieldToggle(
                        context,
                        field: field,
                        isEnabled: settingsProvider.isFieldEnabled(field.key),
                        onToggle: () =>
                            settingsProvider.toggleCreateField(field.key),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: colorScheme.primary,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '说明',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: colorScheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '• 极简模式：快速创建任务，适合日常使用\n'
                    '• 完整模式：显示所有选项，适合需要详细设置的任务\n'
                    '• 自定义模式：根据个人习惯选择常用编辑项\n\n'
                    '注意：未显示的编辑项将使用默认值',
                    style: TextStyle(
                      fontSize: 13,
                      color: colorScheme.onSurface.withValues(alpha: 0.7),
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModeOption(
    BuildContext context, {
    required String title,
    required String subtitle,
    required TaskCreateMode mode,
    required TaskCreateMode currentMode,
    required VoidCallback onTap,
  }) {
    final isSelected = mode == currentMode;
    final colorScheme = Theme.of(context).colorScheme;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected
              ? colorScheme.primaryContainer.withValues(alpha: 0.3)
              : null,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? colorScheme.primary
                : colorScheme.outline.withValues(alpha: 0.2),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? colorScheme.primary : colorScheme.outline,
                  width: 2,
                ),
                color: isSelected ? colorScheme.primary : null,
              ),
              child: isSelected
                  ? Icon(Icons.check, size: 16, color: colorScheme.onPrimary)
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: isSelected
                          ? colorScheme.primary
                          : colorScheme.onSurface,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 13,
                      color: colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFieldToggle(
    BuildContext context, {
    required TaskCreateField field,
    required bool isEnabled,
    required VoidCallback onToggle,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    return ListTile(
      leading: Icon(field.icon, color: colorScheme.primary),
      title: Text(field.label),
      trailing: Switch(value: isEnabled, onChanged: (_) => onToggle()),
      onTap: onToggle,
      contentPadding: EdgeInsets.zero,
    );
  }
}
