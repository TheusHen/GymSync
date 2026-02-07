import 'package:flutter/material.dart';
import '../core/services/workout_stats_service.dart';

/// Widget to display workout statistics summary
class WorkoutStatsCard extends StatelessWidget {
  const WorkoutStatsCard({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, Duration>>(
      future: _getStats(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Card(
            child: Padding(
              padding: EdgeInsets.all(20.0),
              child: Center(child: CircularProgressIndicator()),
            ),
          );
        }

        final stats = snapshot.data!;
        return Card(
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Your Statistics',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 20),
                _buildStatRow(
                  'This Week',
                  _formatDuration(stats['week']!),
                  Icons.calendar_view_week,
                  Colors.blue,
                ),
                const SizedBox(height: 15),
                _buildStatRow(
                  'This Month',
                  _formatDuration(stats['month']!),
                  Icons.calendar_month,
                  Colors.green,
                ),
                const SizedBox(height: 15),
                _buildStatRow(
                  'This Year',
                  _formatDuration(stats['year']!),
                  Icons.calendar_today,
                  Colors.orange,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<Map<String, Duration>> _getStats() async {
    final service = WorkoutStatsService();
    return {
      'week': await service.getWeeklyTotal(),
      'month': await service.getMonthlyTotal(),
      'year': await service.getYearlyTotal(),
    };
  }

  Widget _buildStatRow(String label, String value, IconData icon, Color color) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        const SizedBox(width: 15),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _formatDuration(Duration duration) {
    if (duration.inHours > 0) {
      final hours = duration.inHours;
      final minutes = duration.inMinutes % 60;
      return '${hours}h ${minutes}min';
    } else {
      return '${duration.inMinutes}min';
    }
  }
}

/// Widget to show a quick access button to Wrapped
class WrappedAccessButton extends StatelessWidget {
  final int year;
  final VoidCallback onTap;

  const WrappedAccessButton({
    super.key,
    required this.year,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.purple.shade700, Colors.blue.shade700],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(
              color: Colors.purple.withOpacity(0.3),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Row(
          children: [
            const Icon(
              Icons.auto_awesome,
              color: Colors.white,
              size: 40,
            ),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Wrapped $year',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 5),
                  const Text(
                    'View your yearly statistics',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios,
              color: Colors.white,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}

/// Widget to show available wrapped years list
class WrappedYearsList extends StatelessWidget {
  final Function(int) onYearSelected;

  const WrappedYearsList({
    super.key,
    required this.onYearSelected,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<int>>(
      future: WorkoutStatsService().getAvailableWrappedYears(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final years = snapshot.data!;
        
        if (years.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(20.0),
              child: Text(
                'No Wrapped available yet.\nWorkouts will be tracked automatically!',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey, fontSize: 16),
              ),
            ),
          );
        }

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: years.length,
          itemBuilder: (context, index) {
            final year = years[index];
            return Card(
              margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.purple.shade100,
                  child: Icon(
                    Icons.auto_awesome,
                    color: Colors.purple.shade700,
                  ),
                ),
                title: Text(
                  'Wrapped $year',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
                subtitle: const Text('Tap to view your statistics'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () => onYearSelected(year),
              ),
            );
          },
        );
      },
    );
  }
}

/// Circular progress indicator for workout time
class WorkoutTimeProgress extends StatelessWidget {
  final Duration current;
  final Duration goal;
  final String label;

  const WorkoutTimeProgress({
    super.key,
    required this.current,
    required this.goal,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final percentage = goal.inSeconds > 0
        ? (current.inSeconds / goal.inSeconds).clamp(0.0, 1.0)
        : 0.0;

    return Column(
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              width: 100,
              height: 100,
              child: CircularProgressIndicator(
                value: percentage,
                strokeWidth: 8,
                backgroundColor: Colors.grey.shade300,
                valueColor: AlwaysStoppedAnimation<Color>(
                  percentage >= 1.0 ? Colors.green : Colors.blue,
                ),
              ),
            ),
            Column(
              children: [
                Text(
                  '${(percentage * 100).toInt()}%',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  _formatDuration(current),
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        Text(
          'Meta: ${_formatDuration(goal)}',
          style: const TextStyle(
            fontSize: 12,
            color: Colors.grey,
          ),
        ),
      ],
    );
  }

  String _formatDuration(Duration duration) {
    if (duration.inHours > 0) {
      return '${duration.inHours}h';
    } else {
      return '${duration.inMinutes}min';
    }
  }
}
