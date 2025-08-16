import 'package:flutter/material.dart';
import '../core/theme.dart';

class CircularTimer extends StatelessWidget {
  final bool running;
  final Duration duration;
  final String activity;

  const CircularTimer({
    super.key,
    required this.running,
    required this.duration,
    required this.activity,
  });

  @override
  Widget build(BuildContext context) {
    final percent = (duration.inSeconds % 60) / 60.0;
    final theme = Theme.of(context);
    
    // Determine color based on activity and running state
    Color progressColor;
    if (!running) {
      progressColor = AppColors.accent; // Orange when paused
    } else if (activity == "Gym") {
      progressColor = AppColors.primary; // Blue for gym workouts
    } else if (activity == "Walking") {
      progressColor = AppColors.success; // Green for walking
    } else {
      progressColor = theme.colorScheme.secondary; // Default to secondary color
    }
    
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              width: 180,
              height: 180,
              child: CircularProgressIndicator(
                value: percent,
                strokeWidth: 10,
                backgroundColor: theme.brightness == Brightness.light 
                    ? Colors.grey[200] 
                    : Colors.grey[800],
                color: progressColor,
              ),
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${duration.inMinutes}:${(duration.inSeconds % 60).toString().padLeft(2, '0')}',
                  style: TextStyle(
                    fontSize: 36, 
                    fontWeight: FontWeight.bold,
                    color: theme.brightness == Brightness.light 
                        ? AppColors.primary[800]
                        : AppColors.primary[300],
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: progressColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    activity,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: progressColor,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }
}
