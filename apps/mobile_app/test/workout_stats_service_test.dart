import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:gymsync/core/services/workout_stats_service.dart';
import 'package:gymsync/core/models/workout_stats.dart';

void main() {
  setUp(() async {
    // Initialize SharedPreferences for testing
    SharedPreferences.setMockInitialValues({});
  });

  tearDown(() async {
    // Clean up after each test
    final service = WorkoutStatsService();
    await service.clearAllStats();
  });

  group('WorkoutStatsService Tests', () {
    test('Record a single workout', () async {
      final service = WorkoutStatsService();
      
      await service.recordWorkout(
        activityType: 'Running',
        duration: const Duration(minutes: 30),
      );

      final workouts = await service.getAllWorkouts();
      expect(workouts.length, 1);
      expect(workouts.first.activityType, 'Running');
      expect(workouts.first.duration.inMinutes, 30);
    });

    test('Record multiple workouts', () async {
      final service = WorkoutStatsService();
      
      await service.recordWorkout(
        activityType: 'Running',
        duration: const Duration(minutes: 30),
      );
      
      await service.recordWorkout(
        activityType: 'Cycling',
        duration: const Duration(minutes: 45),
      );
      
      await service.recordWorkout(
        activityType: 'Running',
        duration: const Duration(minutes: 20),
      );

      final workouts = await service.getAllWorkouts();
      expect(workouts.length, 3);
    });

    test('Get workouts by year', () async {
      final service = WorkoutStatsService();
      final currentYear = DateTime.now().year;
      final lastYear = currentYear - 1;
      
      await service.recordWorkout(
        activityType: 'Running',
        duration: const Duration(minutes: 30),
        date: DateTime(currentYear, 5, 15),
      );
      
      await service.recordWorkout(
        activityType: 'Cycling',
        duration: const Duration(minutes: 45),
        date: DateTime(lastYear, 8, 20),
      );

      final currentYearWorkouts = await service.getWorkoutsByYear(currentYear);
      expect(currentYearWorkouts.length, 1);
      expect(currentYearWorkouts.first.activityType, 'Running');
    });

    test('Calculate weekly total', () async {
      final service = WorkoutStatsService();
      final now = DateTime.now();
      
      // Add workouts for this week
      await service.recordWorkout(
        activityType: 'Running',
        duration: const Duration(minutes: 30),
        date: now,
      );
      
      await service.recordWorkout(
        activityType: 'Cycling',
        duration: const Duration(minutes: 45),
        date: now.subtract(const Duration(days: 1)),
      );

      final weeklyTotal = await service.getWeeklyTotal();
      expect(weeklyTotal.inMinutes, 75);
    });

    test('Calculate monthly total', () async {
      final service = WorkoutStatsService();
      final now = DateTime.now();
      
      // Add workouts for this month
      await service.recordWorkout(
        activityType: 'Running',
        duration: const Duration(hours: 1),
        date: now,
      );
      
      await service.recordWorkout(
        activityType: 'Cycling',
        duration: const Duration(minutes: 30),
        date: now.subtract(const Duration(days: 5)),
      );

      final monthlyTotal = await service.getMonthlyTotal();
      expect(monthlyTotal.inMinutes, 90);
    });

    test('Generate annual wrapped', () async {
      final service = WorkoutStatsService();
      final year = 2026;
      
      // Add various workouts throughout the year
      await service.recordWorkout(
        activityType: 'Running',
        duration: const Duration(hours: 1),
        date: DateTime(year, 1, 15), // Monday
      );
      
      await service.recordWorkout(
        activityType: 'Running',
        duration: const Duration(minutes: 45),
        date: DateTime(year, 1, 16), // Tuesday
      );
      
      await service.recordWorkout(
        activityType: 'Cycling',
        duration: const Duration(hours: 2),
        date: DateTime(year, 3, 20),
      );
      
      await service.recordWorkout(
        activityType: 'Running',
        duration: const Duration(minutes: 30),
        date: DateTime(year, 3, 21),
      );

      final wrapped = await service.generateAnnualWrapped(year);
      
      expect(wrapped.year, year);
      expect(wrapped.totalWorkouts, 4);
      expect(wrapped.totalDuration.inMinutes, 255); // 60+45+120+30
      expect(wrapped.favoriteActivity, 'Running'); // Most time (135 min vs 120 min)
      expect(wrapped.activityBreakdown.length, 2);
      expect(wrapped.dailyBreakdown.length, 4);
      expect(
        wrapped.dailyBreakdown[AnnualWrapped.dateKey(DateTime(year, 1, 15))]
            ?.inMinutes,
        60,
      );
    });

    test('Aggregate same-day workouts for heatmap', () async {
      final service = WorkoutStatsService();
      final year = 2026;

      await service.recordWorkout(
        activityType: 'Running',
        duration: const Duration(minutes: 20),
        date: DateTime(year, 7, 10, 8),
      );
      await service.recordWorkout(
        activityType: 'Cycling',
        duration: const Duration(minutes: 40),
        date: DateTime(year, 7, 10, 18),
      );
      await service.recordWorkout(
        activityType: 'Walking',
        duration: const Duration(minutes: 30),
        date: DateTime(year, 7, 11, 9),
      );

      final wrapped = await service.generateAnnualWrapped(year);

      expect(wrapped.dailyBreakdown.length, 2);
      expect(
        wrapped.dailyBreakdown[AnnualWrapped.dateKey(DateTime(year, 7, 10))]
            ?.inMinutes,
        60,
      );
      expect(wrapped.activeTrainingDays, 2);
    });

    test('Calculate longest streak', () async {
      final service = WorkoutStatsService();
      final year = 2026;
      
      // Create a 5-day streak
      await service.recordWorkout(
        activityType: 'Running',
        duration: const Duration(minutes: 30),
        date: DateTime(year, 5, 1),
      );
      
      await service.recordWorkout(
        activityType: 'Running',
        duration: const Duration(minutes: 30),
        date: DateTime(year, 5, 2),
      );
      
      await service.recordWorkout(
        activityType: 'Running',
        duration: const Duration(minutes: 30),
        date: DateTime(year, 5, 3),
      );
      
      await service.recordWorkout(
        activityType: 'Running',
        duration: const Duration(minutes: 30),
        date: DateTime(year, 5, 4),
      );
      
      await service.recordWorkout(
        activityType: 'Running',
        duration: const Duration(minutes: 30),
        date: DateTime(year, 5, 5),
      );
      
      // Skip a day
      
      await service.recordWorkout(
        activityType: 'Running',
        duration: const Duration(minutes: 30),
        date: DateTime(year, 5, 7),
      );

      final wrapped = await service.generateAnnualWrapped(year);
      expect(wrapped.longestStreak, 5);
    });

    test('Get daily stats', () async {
      final service = WorkoutStatsService();
      final date = DateTime(2026, 6, 15);
      
      await service.recordWorkout(
        activityType: 'Running',
        duration: const Duration(minutes: 30),
        date: date,
      );
      
      await service.recordWorkout(
        activityType: 'Cycling',
        duration: const Duration(minutes: 45),
        date: date,
      );

      final dailyStats = await service.getDailyStats(date);
      
      expect(dailyStats, isNotNull);
      expect(dailyStats!.workoutCount, 2);
      expect(dailyStats.totalDuration.inMinutes, 75);
      expect(dailyStats.activityBreakdown.length, 2);
    });

    test('Save and retrieve wrapped', () async {
      final service = WorkoutStatsService();
      final year = 2026;
      
      await service.recordWorkout(
        activityType: 'Running',
        duration: const Duration(hours: 1),
        date: DateTime(year, 3, 15),
      );

      // Generate and save wrapped
      final generatedWrapped = await service.generateAnnualWrapped(year);
      
      // Retrieve saved wrapped
      final retrievedWrapped = await service.getAnnualWrapped(year);
      
      expect(retrievedWrapped, isNotNull);
      expect(retrievedWrapped!.year, generatedWrapped.year);
      expect(retrievedWrapped.totalWorkouts, generatedWrapped.totalWorkouts);
    });

    test('Get available wrapped years', () async {
      final service = WorkoutStatsService();
      
      await service.recordWorkout(
        activityType: 'Running',
        duration: const Duration(minutes: 30),
        date: DateTime(2024, 6, 15),
      );
      await service.generateAnnualWrapped(2024);
      
      await service.recordWorkout(
        activityType: 'Running',
        duration: const Duration(minutes: 30),
        date: DateTime(2025, 6, 15),
      );
      await service.generateAnnualWrapped(2025);

      final years = await service.getAvailableWrappedYears();
      
      expect(years.length, 2);
      expect(years, contains(2024));
      expect(years, contains(2025));
      // Should be sorted in descending order
      expect(years.first, greaterThan(years.last));
    });

    test('Clear all stats', () async {
      final service = WorkoutStatsService();
      
      await service.recordWorkout(
        activityType: 'Running',
        duration: const Duration(minutes: 30),
      );

      var workouts = await service.getAllWorkouts();
      expect(workouts.length, 1);

      await service.clearAllStats();

      workouts = await service.getAllWorkouts();
      expect(workouts.length, 0);
    });
  });

  group('WorkoutStats Model Tests', () {
    test('Create WorkoutStats from JSON', () {
      final json = {
        'date': '2026-02-07T14:30:00.000',
        'activityType': 'Running',
        'duration': 1800, // 30 minutes in seconds
        'year': 2026,
        'month': 2,
        'day': 7,
        'weekday': 6,
      };

      final stats = WorkoutStats.fromJson(json);

      expect(stats.activityType, 'Running');
      expect(stats.duration.inMinutes, 30);
      expect(stats.year, 2026);
      expect(stats.weekday, 6); // Saturday
    });

    test('Convert WorkoutStats to JSON', () {
      final stats = WorkoutStats(
        date: DateTime(2026, 2, 7, 14, 30),
        activityType: 'Running',
        duration: const Duration(minutes: 30),
      );

      final json = stats.toJson();

      expect(json['activityType'], 'Running');
      expect(json['duration'], 1800);
      expect(json['year'], 2026);
      expect(json['month'], 2);
    });
  });

  group('AnnualWrapped Model Tests', () {
    test('Get month names in English', () {
      final wrapped = AnnualWrapped(
        year: 2026,
        totalDuration: Duration.zero,
        totalWorkouts: 0,
        activityBreakdown: {},
        monthlyBreakdown: {},
        weekdayBreakdown: {},
        monthlyWorkoutCount: {},
        weekdayWorkoutCount: {},
        favoriteActivity: '',
        bestMonth: 3,
        bestWeekday: 1,
        longestStreak: 0,
        workoutDates: [],
        dailyBreakdown: {},
      );

      expect(wrapped.getMonthName(1), 'January');
      expect(wrapped.getMonthName(3), 'March');
      expect(wrapped.getMonthName(12), 'December');
    });

    test('Get weekday names in English', () {
      final wrapped = AnnualWrapped(
        year: 2026,
        totalDuration: Duration.zero,
        totalWorkouts: 0,
        activityBreakdown: {},
        monthlyBreakdown: {},
        weekdayBreakdown: {},
        monthlyWorkoutCount: {},
        weekdayWorkoutCount: {},
        favoriteActivity: '',
        bestMonth: 1,
        bestWeekday: 3,
        longestStreak: 0,
        workoutDates: [],
        dailyBreakdown: {},
      );

      expect(wrapped.getWeekdayName(1), 'Monday');
      expect(wrapped.getWeekdayName(3), 'Wednesday');
      expect(wrapped.getWeekdayName(7), 'Sunday');
    });

    test('Format total hours', () {
      final wrapped = AnnualWrapped(
        year: 2026,
        totalDuration: const Duration(hours: 50, minutes: 30),
        totalWorkouts: 100,
        activityBreakdown: {},
        monthlyBreakdown: {},
        weekdayBreakdown: {},
        monthlyWorkoutCount: {},
        weekdayWorkoutCount: {},
        favoriteActivity: 'Running',
        bestMonth: 1,
        bestWeekday: 1,
        longestStreak: 10,
        workoutDates: [],
        dailyBreakdown: {},
      );

      expect(wrapped.totalHours, '50.5');
    });
  });
}
