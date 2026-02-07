import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/workout_stats.dart';

/// Service to manage workout statistics and generate annual wrapped
class WorkoutStatsService {
  static final WorkoutStatsService _instance = WorkoutStatsService._internal();
  factory WorkoutStatsService() => _instance;
  WorkoutStatsService._internal();

  static const String _statsKey = 'workout_stats';
  static const String _wrappedKey = 'annual_wrapped';

  /// Record a completed workout
  Future<void> recordWorkout({
    required String activityType,
    required Duration duration,
    DateTime? date,
  }) async {
    final workoutDate = date ?? DateTime.now();
    final stats = WorkoutStats(
      date: workoutDate,
      activityType: activityType,
      duration: duration,
    );

    final prefs = await SharedPreferences.getInstance();
    final existingStats = await getAllWorkouts();
    existingStats.add(stats);

    // Save to SharedPreferences
    final statsJson = existingStats.map((s) => s.toJson()).toList();
    await prefs.setString(_statsKey, jsonEncode(statsJson));

    // Auto-generate wrapped at end of year
    if (workoutDate.month == 12 && workoutDate.day >= 25) {
      await generateAnnualWrapped(workoutDate.year);
    }
  }

  /// Get all recorded workouts
  Future<List<WorkoutStats>> getAllWorkouts() async {
    final prefs = await SharedPreferences.getInstance();
    final statsString = prefs.getString(_statsKey);

    if (statsString == null || statsString.isEmpty) {
      return [];
    }

    try {
      final List<dynamic> statsJson = jsonDecode(statsString);
      return statsJson.map((json) => WorkoutStats.fromJson(json)).toList();
    } catch (e) {
      return [];
    }
  }

  /// Get workouts for a specific year
  Future<List<WorkoutStats>> getWorkoutsByYear(int year) async {
    final allWorkouts = await getAllWorkouts();
    return allWorkouts.where((w) => w.year == year).toList();
  }

  /// Get workouts for a specific month
  Future<List<WorkoutStats>> getWorkoutsByMonth(int year, int month) async {
    final allWorkouts = await getAllWorkouts();
    return allWorkouts
        .where((w) => w.year == year && w.month == month)
        .toList();
  }

  /// Get daily statistics for a specific date
  Future<DailyWorkoutStats?> getDailyStats(DateTime date) async {
    final allWorkouts = await getAllWorkouts();
    final dayWorkouts = allWorkouts.where((w) =>
        w.year == date.year &&
        w.month == date.month &&
        w.day == date.day).toList();

    if (dayWorkouts.isEmpty) {
      return null;
    }

    Duration totalDuration = Duration.zero;
    Map<String, Duration> activityBreakdown = {};

    for (var workout in dayWorkouts) {
      totalDuration += workout.duration;
      activityBreakdown[workout.activityType] =
          (activityBreakdown[workout.activityType] ?? Duration.zero) +
              workout.duration;
    }

    return DailyWorkoutStats(
      date: date,
      totalDuration: totalDuration,
      activityBreakdown: activityBreakdown,
      workoutCount: dayWorkouts.length,
    );
  }

  /// Get total hours trained this week
  Future<Duration> getWeeklyTotal() async {
    final now = DateTime.now();
    final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
    final allWorkouts = await getAllWorkouts();

    Duration total = Duration.zero;
    for (var workout in allWorkouts) {
      if (workout.date.isAfter(startOfWeek.subtract(const Duration(days: 1))) &&
          workout.date.isBefore(now.add(const Duration(days: 1)))) {
        total += workout.duration;
      }
    }
    return total;
  }

  /// Get total hours trained this month
  Future<Duration> getMonthlyTotal() async {
    final now = DateTime.now();
    final allWorkouts = await getAllWorkouts();

    Duration total = Duration.zero;
    for (var workout in allWorkouts) {
      if (workout.year == now.year && workout.month == now.month) {
        total += workout.duration;
      }
    }
    return total;
  }

  /// Get total hours trained this year
  Future<Duration> getYearlyTotal() async {
    final now = DateTime.now();
    final allWorkouts = await getAllWorkouts();

    Duration total = Duration.zero;
    for (var workout in allWorkouts) {
      if (workout.year == now.year) {
        total += workout.duration;
      }
    }
    return total;
  }

  /// Calculate longest streak of consecutive workout days
  int _calculateLongestStreak(List<DateTime> workoutDates) {
    if (workoutDates.isEmpty) return 0;

    // Sort dates and remove duplicates
    final uniqueDates = workoutDates.map((d) {
      return DateTime(d.year, d.month, d.day);
    }).toSet().toList()
      ..sort();

    int longestStreak = 1;
    int currentStreak = 1;

    for (int i = 1; i < uniqueDates.length; i++) {
      final diff = uniqueDates[i].difference(uniqueDates[i - 1]).inDays;
      if (diff == 1) {
        currentStreak++;
        if (currentStreak > longestStreak) {
          longestStreak = currentStreak;
        }
      } else {
        currentStreak = 1;
      }
    }

    return longestStreak;
  }

  /// Generate annual wrapped statistics
  Future<AnnualWrapped> generateAnnualWrapped(int year) async {
    final yearWorkouts = await getWorkoutsByYear(year);
    Map<int, Duration> monthlyBreakdown = {};
    Map<int, Duration> weekdayBreakdown = {};
    Map<int, int> monthlyWorkoutCount = {};
    Map<int, int> weekdayWorkoutCount = {};

    // Initialize maps so wrapped pages can render even when there are no workouts.
    for (int i = 1; i <= 12; i++) {
      monthlyBreakdown[i] = Duration.zero;
      monthlyWorkoutCount[i] = 0;
    }
    for (int i = 1; i <= 7; i++) {
      weekdayBreakdown[i] = Duration.zero;
      weekdayWorkoutCount[i] = 0;
    }

    if (yearWorkouts.isEmpty) {
      // Return empty wrapped
      return AnnualWrapped(
        year: year,
        totalDuration: Duration.zero,
        totalWorkouts: 0,
        activityBreakdown: {},
        monthlyBreakdown: monthlyBreakdown,
        weekdayBreakdown: weekdayBreakdown,
        monthlyWorkoutCount: monthlyWorkoutCount,
        weekdayWorkoutCount: weekdayWorkoutCount,
        favoriteActivity: '',
        bestMonth: 1,
        bestWeekday: 1,
        longestStreak: 0,
        workoutDates: [],
        dailyBreakdown: {},
      );
    }

    Duration totalDuration = Duration.zero;
    Map<String, Duration> activityBreakdown = {};
    Map<String, Duration> dailyBreakdown = {};
    List<DateTime> workoutDates = [];

    // Process all workouts
    for (var workout in yearWorkouts) {
      totalDuration += workout.duration;
      workoutDates.add(workout.date);

      final dayKey = AnnualWrapped.dateKey(workout.date);
      dailyBreakdown[dayKey] = (dailyBreakdown[dayKey] ?? Duration.zero) + workout.duration;

      // Activity breakdown
      activityBreakdown[workout.activityType] =
          (activityBreakdown[workout.activityType] ?? Duration.zero) +
              workout.duration;

      // Monthly breakdown
      monthlyBreakdown[workout.month] =
          monthlyBreakdown[workout.month]! + workout.duration;
      monthlyWorkoutCount[workout.month] =
          monthlyWorkoutCount[workout.month]! + 1;

      // Weekday breakdown
      weekdayBreakdown[workout.weekday] =
          weekdayBreakdown[workout.weekday]! + workout.duration;
      weekdayWorkoutCount[workout.weekday] =
          weekdayWorkoutCount[workout.weekday]! + 1;
    }

    // Find favorite activity (most duration)
    String favoriteActivity = '';
    Duration maxActivityDuration = Duration.zero;
    activityBreakdown.forEach((activity, duration) {
      if (duration > maxActivityDuration) {
        maxActivityDuration = duration;
        favoriteActivity = activity;
      }
    });

    // Find best month (most duration)
    int bestMonth = 1;
    Duration maxMonthDuration = Duration.zero;
    monthlyBreakdown.forEach((month, duration) {
      if (duration > maxMonthDuration) {
        maxMonthDuration = duration;
        bestMonth = month;
      }
    });

    // Find best weekday (most duration)
    int bestWeekday = 1;
    Duration maxWeekdayDuration = Duration.zero;
    weekdayBreakdown.forEach((weekday, duration) {
      if (duration > maxWeekdayDuration) {
        maxWeekdayDuration = duration;
        bestWeekday = weekday;
      }
    });

    // Calculate longest streak
    int longestStreak = _calculateLongestStreak(workoutDates);

    final wrapped = AnnualWrapped(
      year: year,
      totalDuration: totalDuration,
      totalWorkouts: yearWorkouts.length,
      activityBreakdown: activityBreakdown,
      monthlyBreakdown: monthlyBreakdown,
      weekdayBreakdown: weekdayBreakdown,
      monthlyWorkoutCount: monthlyWorkoutCount,
      weekdayWorkoutCount: weekdayWorkoutCount,
      favoriteActivity: favoriteActivity,
      bestMonth: bestMonth,
      bestWeekday: bestWeekday,
      longestStreak: longestStreak,
      workoutDates: workoutDates,
      dailyBreakdown: dailyBreakdown,
    );

    // Save wrapped to SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    final wrappedKey = '${_wrappedKey}_$year';
    await prefs.setString(wrappedKey, jsonEncode(wrapped.toJson()));

    return wrapped;
  }

  /// Get saved annual wrapped for a specific year
  Future<AnnualWrapped?> getAnnualWrapped(int year) async {
    final prefs = await SharedPreferences.getInstance();
    final wrappedKey = '${_wrappedKey}_$year';
    final wrappedString = prefs.getString(wrappedKey);

    if (wrappedString == null || wrappedString.isEmpty) {
      return null;
    }

    try {
      final wrappedJson = jsonDecode(wrappedString);
      return AnnualWrapped.fromJson(wrappedJson);
    } catch (e) {
      return null;
    }
  }

  /// Get all available wrapped years
  Future<List<int>> getAvailableWrappedYears() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys();
    final wrappedYears = <int>[];

    for (var key in keys) {
      if (key.startsWith(_wrappedKey)) {
        final yearStr = key.replaceFirst('${_wrappedKey}_', '');
        final year = int.tryParse(yearStr);
        if (year != null) {
          wrappedYears.add(year);
        }
      }
    }

    wrappedYears.sort((a, b) => b.compareTo(a)); // Most recent first
    return wrappedYears;
  }

  /// Clear all statistics (for testing purposes)
  Future<void> clearAllStats() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_statsKey);

    // Remove all wrapped data
    final years = await getAvailableWrappedYears();
    for (var year in years) {
      await prefs.remove('${_wrappedKey}_$year');
    }
  }
}
