import 'package:flutter/material.dart';
import 'package:hands_app/data/models/shift_data.dart';

class ShiftProgressBar extends StatelessWidget {
  final ShiftData shiftData;
  final bool showText;
  final bool showPercentage;
  final Map<String, dynamic>? completionStats;

  const ShiftProgressBar({
    super.key,
    required this.shiftData,
    this.showText = true,
    this.showPercentage = false,
    this.completionStats,
  });

  @override
  Widget build(BuildContext context) {
    // Parse time strings to check if shift is expired
    bool isExpired = _isShiftExpired();

    double getProgressBarPercentage() {
      if (completionStats == null) return 0.0;

      final totalTasks = completionStats!['totalTasks'] as int? ?? 0;
      final completedTasks = completionStats!['completedTasks'] as int? ?? 0;

      if (totalTasks == 0) return 0.0;
      return completedTasks / totalTasks;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 8),
      child: Column(
        children: [
          if (showText)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  shiftData.shiftName,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                Text(
                  isExpired ? 'Ended' : _getTimeRemaining(),
                ),
              ],
            ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Flexible(
                child: LinearProgressIndicator(
                  minHeight: 24,
                  borderRadius: BorderRadius.circular(4),
                  value: getProgressBarPercentage(),
                ),
              ),
              if (showPercentage) ...[
                const SizedBox(width: 8),
                Text(
                  '${(getProgressBarPercentage() * 100).toInt()}%',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  bool _isShiftExpired() {
    try {
      final now = DateTime.now();
      final endTime = _parseTime(shiftData.endTime);
      if (endTime == null) return false;

      final todayEndTime = DateTime(
        now.year,
        now.month,
        now.day,
        endTime.hour,
        endTime.minute,
      );

      return now.isAfter(todayEndTime);
    } catch (e) {
      return false;
    }
  }

  String _getTimeRemaining() {
    try {
      final now = DateTime.now();
      final endTime = _parseTime(shiftData.endTime);
      if (endTime == null) return 'Unknown';

      final todayEndTime = DateTime(
        now.year,
        now.month,
        now.day,
        endTime.hour,
        endTime.minute,
      );

      final timeRemaining = todayEndTime.difference(now);
      if (timeRemaining.isNegative) return 'Ended';

      final hours = timeRemaining.inHours;
      final minutes = timeRemaining.inMinutes.remainder(60);
      return '${hours}h ${minutes}m';
    } catch (e) {
      return 'Unknown';
    }
  }

  DateTime? _parseTime(String timeString) {
    try {
      // Parse time in HH:mm format
      final parts = timeString.split(':');
      if (parts.length != 2) return null;

      final hour = int.parse(parts[0]);
      final minute = int.parse(parts[1]);

      return DateTime(2000, 1, 1, hour, minute); // Use dummy date
    } catch (e) {
      return null;
    }
  }
}
