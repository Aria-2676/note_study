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
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        ElevatedButton(
          onPressed: onTogglePrizePool,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFFF6B6B),
            foregroundColor: Colors.white,
          ),
          child: const Text('自定义抽奖池'),
        ),
        const SizedBox(width: 10),
        ElevatedButton(
          onPressed: onToggleRecords,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.grey.shade200,
            foregroundColor: Colors.black,
          ),
          child: const Text('抽奖记录'),
        ),
      ],
    );
  }
}
