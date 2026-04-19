import 'package:flutter/material.dart';
import '../../../../providers/scratch_provider.dart';
import '../../models/scratch_model.dart';

class ProbabilityInfoWidget extends StatelessWidget {
  final ScratchProvider scratchProvider;

  const ProbabilityInfoWidget({super.key, required this.scratchProvider});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final prizes = scratchProvider.availablePrizePool;
    final probabilities = scratchProvider.getPrizeProbabilities();
    final selectedCost = scratchProvider.selectedCost;
    final maxAllowedValue =
        selectedCost * ScratchProvider.maxPrizeValueMultiplier;

    double actualExpected = 0;
    probabilities.forEach((prize, prob) {
      actualExpected += prize.value * prob;
    });

    final actualReturnRate = (actualExpected / selectedCost * 100)
        .toStringAsFixed(1);

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
          Text(
            '📊 概率说明',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: colorScheme.primary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '• 权重 = 1 / 价值（价值越高，概率越低）',
            style: TextStyle(
              color: colorScheme.onSurface.withValues(alpha: 0.8),
              fontSize: 12,
            ),
          ),
          Text(
            '• 高价值切割：价值 > $maxAllowedValue积分 的奖品不入池',
            style: TextStyle(
              color: colorScheme.onSurface.withValues(alpha: 0.8),
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '当前档位: $selectedCost积分',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '期望收益: ${actualExpected.toStringAsFixed(1)}积分 ($actualReturnRate%)',
                      style: TextStyle(
                        fontSize: 12,
                        color: colorScheme.onSurface.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: colorScheme.tertiaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '上限$maxAllowedValue积分',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onTertiaryContainer,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (prizes.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              '奖品概率分布:',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 6),
            ...prizes.map((prize) {
              final prob = probabilities[prize] ?? 0.0;
              return _buildProbabilityItem(
                prize,
                prob,
                colorScheme,
                selectedCost,
              );
            }),
          ],
        ],
      ),
    );
  }

  Widget _buildProbabilityItem(
    PrizeItem prize,
    double probability,
    ColorScheme colorScheme,
    int selectedCost,
  ) {
    final percentage = (probability * 100).toStringAsFixed(2);
    final isHighValue = prize.value > selectedCost;

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: isHighValue ? colorScheme.tertiary : colorScheme.primary,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Text(
                    prize.name,
                    style: TextStyle(
                      fontSize: 12,
                      color: colorScheme.onSurface,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '$percentage%',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: isHighValue
                        ? colorScheme.tertiary
                        : colorScheme.primary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
