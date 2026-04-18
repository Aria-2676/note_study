import 'package:flutter/material.dart';
import '../../../../providers/scratch_provider.dart';
import '../../models/scratch_state.dart';

class CostSelectorWidget extends StatelessWidget {
  final ScratchProvider scratchProvider;
  final void Function(int) onCostChanged;

  const CostSelectorWidget({
    super.key,
    required this.scratchProvider,
    required this.onCostChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isDisabled = !scratchProvider.state.canChangeCost;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(color: Colors.grey.withValues(alpha: 10), blurRadius: 10),
        ],
      ),
      child: Stack(
        children: [
          Column(
            children: [
              const Text(
                '选择彩票档位',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Color(0xFFFF6B6B),
                ),
              ),
              const SizedBox(height: 12),
              ToggleButtons(
                isSelected: ScratchProvider.costOptions
                    .map((c) => c == scratchProvider.selectedCost)
                    .toList(),
                onPressed: isDisabled
                    ? null
                    : (index) =>
                          onCostChanged(ScratchProvider.costOptions[index]),
                borderRadius: BorderRadius.circular(20),
                selectedColor: Colors.white,
                fillColor: const Color(0xFFFF6B6B),
                disabledColor: Colors.grey.shade300,
                children: ScratchProvider.costOptions
                    .map(
                      (cost) => Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('$cost积分'),
                            Text(
                              '${cost ~/ 10}倍概率',
                              style: const TextStyle(fontSize: 10),
                            ),
                          ],
                        ),
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 8),
              Text(
                '当前选择: ${scratchProvider.selectedCost}积分档位',
                style: const TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ],
          ),
          if (isDisabled)
            Positioned.fill(
              child: Container(
                color: Colors.white.withValues(alpha: 180),
                child: const Center(
                  child: Text(
                    '刮奖中不可切换档位',
                    style: TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
