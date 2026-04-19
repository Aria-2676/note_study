import 'package:flutter/material.dart';
import '../../../../providers/scratch_provider.dart';
import '../../../../providers/shop_provider.dart';
import '../../models/scratch_model.dart';

class PrizePoolEditorWidget extends StatelessWidget {
  final ScratchProvider scratchProvider;
  final ShopProvider shopProvider;

  const PrizePoolEditorWidget({
    super.key,
    required this.scratchProvider,
    required this.shopProvider,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final availableShopItems = shopProvider.shopItems
        .where(
          (item) => !scratchProvider.customPrizePool.any(
            (p) => p.id == 'goods_${item.id}',
          ),
        )
        .toList();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withValues(alpha: 0.1),
            blurRadius: 10,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '🎁 奖品池管理',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: colorScheme.primary,
                ),
              ),
              if (scratchProvider.customPrizePool.isNotEmpty)
                TextButton(
                  onPressed: () async {
                    await scratchProvider.resetPrizePoolToDefault();
                  },
                  child: Text(
                    '清空自定义',
                    style: TextStyle(color: colorScheme.error),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          _buildDefaultPrizePoolSection(colorScheme),
          const SizedBox(height: 16),
          _buildCustomPrizePoolSection(context, colorScheme),
          const SizedBox(height: 16),
          _buildAddPrizeSection(context, colorScheme, availableShopItems),
        ],
      ),
    );
  }

  Widget _buildDefaultPrizePoolSection(ColorScheme colorScheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.lock,
              size: 16,
              color: colorScheme.onSurface.withValues(alpha: 0.5),
            ),
            const SizedBox(width: 4),
            Text(
              '默认奖品池（不可修改）',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: scratchProvider.defaultPrizePool.map((prize) {
            return Chip(
              label: Text(
                '${prize.name} (${prize.weight.toStringAsFixed(0)})',
                style: const TextStyle(fontSize: 12),
              ),
              backgroundColor: colorScheme.primaryContainer.withValues(
                alpha: 0.3,
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildCustomPrizePoolSection(
    BuildContext context,
    ColorScheme colorScheme,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.edit, size: 16, color: colorScheme.tertiary),
            const SizedBox(width: 4),
            Text(
              '自定义奖品（可修改）',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (scratchProvider.customPrizePool.isEmpty)
          Text(
            '暂无自定义奖品，可从下方添加',
            style: TextStyle(
              color: colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          )
        else
          Column(
            children: scratchProvider.customPrizePool
                .map(
                  (prize) => _buildCustomPrizeItem(context, prize, colorScheme),
                )
                .toList(),
          ),
      ],
    );
  }

  Widget _buildCustomPrizeItem(
    BuildContext context,
    PrizeItem prize,
    ColorScheme colorScheme,
  ) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(
          prize.type == 'integral' ? Icons.star : Icons.card_giftcard,
          color: prize.type == 'integral' ? Colors.amber : colorScheme.tertiary,
        ),
        title: Text(prize.name),
        subtitle: Text(
          '价值: ${prize.value} | 权重: ${prize.weight.toStringAsFixed(1)}',
          style: const TextStyle(fontSize: 12),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: Icon(Icons.tune, color: colorScheme.primary),
              onPressed: () => _showWeightDialog(context, prize, colorScheme),
              tooltip: '调整权重',
            ),
            IconButton(
              icon: Icon(Icons.delete, color: colorScheme.error),
              onPressed: () => _removePrize(context, prize, colorScheme),
              tooltip: '删除',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddPrizeSection(
    BuildContext context,
    ColorScheme colorScheme,
    List availableShopItems,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.add_circle, size: 16, color: Colors.green),
            const SizedBox(width: 4),
            Text(
              '添加奖品',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ElevatedButton.icon(
              onPressed: () => _showAddIntegralDialog(context, colorScheme),
              icon: const Icon(Icons.star, size: 18),
              label: const Text('添加积分奖品'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amber,
                foregroundColor: Colors.black87,
              ),
            ),
            if (availableShopItems.isNotEmpty)
              ElevatedButton.icon(
                onPressed: () => _showAddGoodsDialog(
                  context,
                  colorScheme,
                  availableShopItems,
                ),
                icon: const Icon(Icons.card_giftcard, size: 18),
                label: const Text('添加商品奖品'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: colorScheme.tertiary,
                  foregroundColor: colorScheme.onTertiary,
                ),
              ),
          ],
        ),
      ],
    );
  }

  void _showWeightDialog(
    BuildContext context,
    PrizeItem prize,
    ColorScheme colorScheme,
  ) {
    final controller = TextEditingController(
      text: prize.weight.toStringAsFixed(1),
    );

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('调整 ${prize.name} 权重'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('当前权重: ${prize.weight.toStringAsFixed(1)}'),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: '新权重',
                hintText: '输入权重值（如 10.0）',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '提示：权重越高，抽中概率越大',
              style: TextStyle(
                fontSize: 12,
                color: colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () async {
              final newWeight = double.tryParse(controller.text);
              if (newWeight != null && newWeight > 0) {
                await scratchProvider.updatePrizeWeight(prize.id, newWeight);
                if (ctx.mounted) Navigator.of(ctx).pop();
              }
            },
            child: const Text('确认'),
          ),
        ],
      ),
    );
  }

  void _showAddIntegralDialog(BuildContext context, ColorScheme colorScheme) {
    final valueController = TextEditingController();
    final weightController = TextEditingController(text: '10.0');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('添加积分奖品'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: valueController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: '积分数量',
                hintText: '如 100',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: weightController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: '权重',
                hintText: '如 10.0',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () async {
              final value = int.tryParse(valueController.text);
              final weight = double.tryParse(weightController.text);
              if (value != null && value > 0 && weight != null && weight > 0) {
                final prize = PrizeItem(
                  id: 'custom_int_${DateTime.now().millisecondsSinceEpoch}',
                  name: '$value积分',
                  type: 'integral',
                  value: value,
                  weight: weight,
                  isDefault: false,
                );
                await scratchProvider.addPrizeToPool(prize);
                if (ctx.mounted) Navigator.of(ctx).pop();
              }
            },
            child: const Text('添加'),
          ),
        ],
      ),
    );
  }

  void _showAddGoodsDialog(
    BuildContext context,
    ColorScheme colorScheme,
    List availableShopItems,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('选择商品'),
        content: SizedBox(
          width: double.maxFinite,
          height: 300,
          child: ListView.builder(
            itemCount: availableShopItems.length,
            itemBuilder: (context, index) {
              final item = availableShopItems[index];
              return ListTile(
                leading: Icon(Icons.card_giftcard, color: colorScheme.tertiary),
                title: Text(item.name),
                subtitle: Text('价格: ${item.price}积分'),
                trailing: IconButton(
                  icon: const Icon(Icons.add_circle, color: Colors.green),
                  onPressed: () async {
                    final prize = PrizeItem.fromShopItem(item);
                    await scratchProvider.addPrizeToPool(prize);
                    if (ctx.mounted) Navigator.of(ctx).pop();
                  },
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }

  Future<void> _removePrize(
    BuildContext context,
    PrizeItem prize,
    ColorScheme colorScheme,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认删除'),
        content: Text('确定要删除 ${prize.name} 吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: colorScheme.error,
              foregroundColor: colorScheme.onError,
            ),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await scratchProvider.removePrizeFromPool(prize.id);
    }
  }
}
