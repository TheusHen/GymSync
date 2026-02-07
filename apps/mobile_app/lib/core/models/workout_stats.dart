/// Model to store workout statistics
class WorkoutStats {
  final DateTime date;
  final String activityType;
  final Duration duration;
  final int year;
  final int month;
  final int day;
  final int weekday; // 1 = Monday, 7 = Sunday

  WorkoutStats({
    required this.date,
    required this.activityType,
    required this.duration,
  })  : year = date.year,
        month = date.month,
        day = date.day,
        weekday = date.weekday;

  Map<String, dynamic> toJson() {
    return {
      'date': date.toIso8601String(),
      'activityType': activityType,
      'duration': duration.inSeconds,
      'year': year,
      'month': month,
      'day': day,
      'weekday': weekday,
    };
  }

  factory WorkoutStats.fromJson(Map<String, dynamic> json) {
    return WorkoutStats(
      date: DateTime.parse(json['date']),
      activityType: json['activityType'],
      duration: Duration(seconds: json['duration']),
    );
  }
}

/// Model to store daily aggregated workout statistics
class DailyWorkoutStats {
  final DateTime date;
  final Duration totalDuration;
  final Map<String, Duration> activityBreakdown;
  final int workoutCount;

  DailyWorkoutStats({
    required this.date,
    required this.totalDuration,
    required this.activityBreakdown,
    required this.workoutCount,
  });

  Map<String, dynamic> toJson() {
    return {
      'date': date.toIso8601String(),
      'totalDuration': totalDuration.inSeconds,
      'activityBreakdown': activityBreakdown.map(
        (key, value) => MapEntry(key, value.inSeconds),
      ),
      'workoutCount': workoutCount,
    };
  }

  factory DailyWorkoutStats.fromJson(Map<String, dynamic> json) {
    Map<String, Duration> breakdown = {};
    if (json['activityBreakdown'] != null) {
      (json['activityBreakdown'] as Map<String, dynamic>).forEach((key, value) {
        breakdown[key] = Duration(seconds: value);
      });
    }

    return DailyWorkoutStats(
      date: DateTime.parse(json['date']),
      totalDuration: Duration(seconds: json['totalDuration']),
      activityBreakdown: breakdown,
      workoutCount: json['workoutCount'],
    );
  }
}

/// Model to store annual wrapped statistics
class AnnualWrapped {
  final int year;
  final Duration totalDuration;
  final int totalWorkouts;
  final Map<String, Duration> activityBreakdown;
  final Map<int, Duration> monthlyBreakdown; // month (1-12) -> duration
  final Map<int, Duration> weekdayBreakdown; // weekday (1-7) -> duration
  final Map<int, int> monthlyWorkoutCount; // month -> count
  final Map<int, int> weekdayWorkoutCount; // weekday -> count
  final String favoriteActivity;
  final int bestMonth;
  final int bestWeekday;
  final int longestStreak;
  final List<DateTime> workoutDates;
  final Map<String, Duration> dailyBreakdown; // yyyy-MM-dd -> duration

  AnnualWrapped({
    required this.year,
    required this.totalDuration,
    required this.totalWorkouts,
    required this.activityBreakdown,
    required this.monthlyBreakdown,
    required this.weekdayBreakdown,
    required this.monthlyWorkoutCount,
    required this.weekdayWorkoutCount,
    required this.favoriteActivity,
    required this.bestMonth,
    required this.bestWeekday,
    required this.longestStreak,
    required this.workoutDates,
    required this.dailyBreakdown,
  });

  Map<String, dynamic> toJson() {
    return {
      'year': year,
      'totalDuration': totalDuration.inSeconds,
      'totalWorkouts': totalWorkouts,
      'activityBreakdown': activityBreakdown.map(
        (key, value) => MapEntry(key, value.inSeconds),
      ),
      'monthlyBreakdown': monthlyBreakdown.map(
        (key, value) => MapEntry(key.toString(), value.inSeconds),
      ),
      'weekdayBreakdown': weekdayBreakdown.map(
        (key, value) => MapEntry(key.toString(), value.inSeconds),
      ),
      'monthlyWorkoutCount': monthlyWorkoutCount.map(
        (key, value) => MapEntry(key.toString(), value),
      ),
      'weekdayWorkoutCount': weekdayWorkoutCount.map(
        (key, value) => MapEntry(key.toString(), value),
      ),
      'favoriteActivity': favoriteActivity,
      'bestMonth': bestMonth,
      'bestWeekday': bestWeekday,
      'longestStreak': longestStreak,
      'workoutDates': workoutDates.map((d) => d.toIso8601String()).toList(),
      'dailyBreakdown': dailyBreakdown.map(
        (key, value) => MapEntry(key, value.inSeconds),
      ),
    };
  }

  factory AnnualWrapped.fromJson(Map<String, dynamic> json) {
    Map<String, Duration> activityBreakdown = {};
    if (json['activityBreakdown'] != null) {
      (json['activityBreakdown'] as Map<String, dynamic>).forEach((key, value) {
        activityBreakdown[key] = Duration(seconds: value);
      });
    }

    Map<int, Duration> monthlyBreakdown = {};
    if (json['monthlyBreakdown'] != null) {
      (json['monthlyBreakdown'] as Map<String, dynamic>).forEach((key, value) {
        monthlyBreakdown[int.parse(key)] = Duration(seconds: value);
      });
    }

    Map<int, Duration> weekdayBreakdown = {};
    if (json['weekdayBreakdown'] != null) {
      (json['weekdayBreakdown'] as Map<String, dynamic>).forEach((key, value) {
        weekdayBreakdown[int.parse(key)] = Duration(seconds: value);
      });
    }

    Map<int, int> monthlyWorkoutCount = {};
    if (json['monthlyWorkoutCount'] != null) {
      (json['monthlyWorkoutCount'] as Map<String, dynamic>).forEach((key, value) {
        monthlyWorkoutCount[int.parse(key)] = value;
      });
    }

    Map<int, int> weekdayWorkoutCount = {};
    if (json['weekdayWorkoutCount'] != null) {
      (json['weekdayWorkoutCount'] as Map<String, dynamic>).forEach((key, value) {
        weekdayWorkoutCount[int.parse(key)] = value;
      });
    }

    Map<String, Duration> dailyBreakdown = {};
    if (json['dailyBreakdown'] != null) {
      (json['dailyBreakdown'] as Map<String, dynamic>).forEach((key, value) {
        dailyBreakdown[key] = Duration(seconds: value);
      });
    }

    return AnnualWrapped(
      year: json['year'],
      totalDuration: Duration(seconds: json['totalDuration']),
      totalWorkouts: json['totalWorkouts'],
      activityBreakdown: activityBreakdown,
      monthlyBreakdown: monthlyBreakdown,
      weekdayBreakdown: weekdayBreakdown,
      monthlyWorkoutCount: monthlyWorkoutCount,
      weekdayWorkoutCount: weekdayWorkoutCount,
      favoriteActivity: json['favoriteActivity'],
      bestMonth: json['bestMonth'],
      bestWeekday: json['bestWeekday'],
      longestStreak: json['longestStreak'],
      workoutDates: (json['workoutDates'] as List)
          .map((d) => DateTime.parse(d))
          .toList(),
      dailyBreakdown: dailyBreakdown,
    );
  }

  String get totalHours => (totalDuration.inMinutes / 60).toStringAsFixed(1);

  static String dateKey(DateTime date) {
    final normalized = DateTime(date.year, date.month, date.day);
    return normalized.toIso8601String().split('T').first;
  }

  Duration getDailyDuration(DateTime date) {
    return dailyBreakdown[dateKey(date)] ?? Duration.zero;
  }

  Duration get maxDailyDuration {
    if (dailyBreakdown.isEmpty) {
      return Duration.zero;
    }
    return dailyBreakdown.values.reduce((a, b) => a > b ? a : b);
  }

  int get activeTrainingDays {
    return dailyBreakdown.values.where((duration) => duration > Duration.zero).length;
  }

  DateTime? get bestTrainingDay {
    if (dailyBreakdown.isEmpty) {
      return null;
    }

    String? bestDayKey;
    Duration bestDuration = Duration.zero;
    dailyBreakdown.forEach((dayKey, duration) {
      if (duration > bestDuration) {
        bestDuration = duration;
        bestDayKey = dayKey;
      }
    });

    return bestDayKey == null ? null : DateTime.tryParse(bestDayKey!);
  }

  String getMonthName(int month) {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return months[month - 1];
  }

  String getWeekdayName(int weekday) {
    const weekdays = [
      'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'
    ];
    return weekdays[weekday - 1];
  }
}
