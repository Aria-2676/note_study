import 'package:flutter/material.dart';

/// 创建备份弹窗。
///
/// 通过 `Navigator.pop` 返回用户输入的备份名：
/// 取消返回 `null`，确认返回去掉首尾空格后的文本（空串表示不命名）。
class CreateBackupDialog extends StatefulWidget {
  const CreateBackupDialog({super.key});

  @override
  State<CreateBackupDialog> createState() => _CreateBackupDialogState();
}

class _CreateBackupDialogState extends State<CreateBackupDialog> {
  final TextEditingController _nameController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.upload, color: Colors.green),
          SizedBox(width: 8),
          Text('创建备份'),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('为备份命名（可选）：'),
          const SizedBox(height: 12),
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              hintText: '例如：每日备份',
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 8,
              ),
            ),
            maxLength: 20,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(null),
          child: const Text('取消'),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.of(context).pop(_nameController.text.trim());
          },
          style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
          child: const Text('创建备份'),
        ),
      ],
    );
  }
}
