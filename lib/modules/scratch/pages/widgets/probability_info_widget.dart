import 'package:flutter/material.dart';
import '../../../../providers/scratch_provider.dart';
import '../../models/scratch_model.dart';

class ProbabilityInfoWidget extends StatelessWidget {
  final ScratchProvider scratchProvider;

  const ProbabilityInfoWidget({super.key, required this.scratchProvider});

  @override
  Widget build(BuildContext context) {
    final prizes = scratchProvider.completePrizePool;
    final probabilities = _calculateDisplayProbabilities(
      prizes,
      scratchProvider.selectedCost,
    );

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(color: Colors.grey.withValues(alpha: 10), blurRadius: 10),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '📊 概率说明',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: Color(0xFFFF6B6B),
            ),
          ),
          const SizedBox(height: 8),
          const Text('• 概率基于奖品积分价值计算（负相关）'),
          const Text('• 价值越高的奖品，抽取概率越低'),
          const SizedBox(height: 8),
          Text(
            '• 当前档位: ${scratchProvider.selectedCost}积分（${scratchProvider.selectedCost ~/ 10}倍概率加成）',
          ),
          const SizedBox(height: 12),
          const Text(
            '当前抽奖池奖品概率分布:',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: List.generate(prizes.length > 8 ? 8 : prizes.length, (
              index,
            ) {
              final prize = prizes[index];
              final prob = probabilities[index];
              return Chip(
                label: Text(
                  '${prize.name}: ${(prob * 100).toStringAsFixed(1)}%',
                  style: const TextStyle(fontSize: 10),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  List<double> _calculateDisplayProbabilities(
    List<PrizeItem> prizes,
    int cost,
  ) {
    final weights = <double>[];
    final bonusMultiplier = cost / 10.0;

    for (final prize in prizes) {
      final adjustedValue = prize.value / bonusMultiplier;
      weights.add(1.0 / (adjustedValue * 0.1 + 1));
    }

    final totalWeight = weights.fold(0.0, (sum, w) => sum + w);
    return weights.map((w) => w / totalWeight).toList();
  }
}
