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
    final colorScheme = Theme.of(context).colorScheme;
    final isDisabled = !scratchProvider.state.canChangeCost;

    final probabilities = scratchProvider.getPrizeProbabilities();
    double actualExpected = 0;
    probabilities.forEach((prize, prob) {
      actualExpected += prize.value * prob;
    });

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
      child: Stack(
        children: [
          Column(
            children: [
              Text(
                '选择彩票档位',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: colorScheme.primary,
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
                selectedColor: colorScheme.onPrimary,
                fillColor: colorScheme.primary,
                disabledColor: colorScheme.surfaceContainerHighest,
                children: ScratchProvider.costOptions
                    .map(
                      (cost) {
                        final maxAllowed = cost * ScratchProvider.maxPrizeValueMultiplier;
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('$cost积分'),
                              Text(
                                '上限$maxAllowed',
                                style: const TextStyle(fontSize: 9),
                              ),
                            ],
                          ),
                        );
                      },
                    )
                    .toList(),
              ),
              const SizedBox(height: 8),
              Text(
                '期望收益: ${actualExpected.toStringAsFixed(1)}积分',
                style: TextStyle(
                  color: colorScheme.onSurface.withValues(alpha: 0.6),
                  fontSize: 12,
                ),
              ),
            ],
          ),
          if (isDisabled)
            Positioned.fill(
              child: Container(
                color: colorScheme.surface.withValues(alpha: 0.8),
                child: Center(
                  child: Text(
                    '刮奖中不可切换档位',
                    style: TextStyle(
                      color: colorScheme.onSurface.withValues(alpha: 0.6),
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
