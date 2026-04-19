import 'package:flutter/material.dart';
import '../../../../providers/scratch_provider.dart';

class ScratchActionButtonsWidget extends StatelessWidget {
  final ScratchProvider scratchProvider;
  final VoidCallback onTogglePrizePool;
  final VoidCallback onToggleRecords;

  const ScratchActionButtonsWidget({
    super.key,
    required this.scratchProvider,
    required this.onTogglePrizePool,
    required this.onToggleRecords,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        ElevatedButton(
          onPressed: onTogglePrizePool,
          style: ElevatedButton.styleFrom(
            backgroundColor: colorScheme.primary,
            foregroundColor: colorScheme.onPrimary,
          ),
          child: const Text('自定义抽奖池'),
        ),
        const SizedBox(width: 10),
        ElevatedButton(
          onPressed: onToggleRecords,
          style: ElevatedButton.styleFrom(
            backgroundColor: colorScheme.surfaceContainerHighest,
            foregroundColor: colorScheme.onSurface,
          ),
          child: const Text('抽奖记录'),
        ),
      ],
    );
  }
}
