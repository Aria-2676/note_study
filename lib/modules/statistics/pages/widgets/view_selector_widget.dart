import 'package:flutter/material.dart';

enum StatisticsView { day, threeDays, week, month, year }

class ViewSelectorWidget extends StatelessWidget {
  final StatisticsView currentView;
  final void Function(StatisticsView) onViewChanged;

  const ViewSelectorWidget({
    super.key,
    required this.currentView,
    required this.onViewChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Row(
          children: [
            _buildViewButton('单日', StatisticsView.day),
            const SizedBox(width: 4),
            _buildViewButton('三日', StatisticsView.threeDays),
            const SizedBox(width: 4),
            _buildViewButton('周', StatisticsView.week),
            const SizedBox(width: 4),
            _buildViewButton('月', StatisticsView.month),
            const SizedBox(width: 4),
            _buildViewButton('年', StatisticsView.year),
          ],
        ),
      ),
    );
  }

  Widget _buildViewButton(String label, StatisticsView view) {
    final isSelected = currentView == view;
    return Expanded(
      child: GestureDetector(
        onTap: () => onViewChanged(view),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isSelected ? Colors.blue : Colors.grey[100],
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.white : Colors.black,
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }
}
