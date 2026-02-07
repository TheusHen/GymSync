import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';

import '../core/models/workout_stats.dart';
import '../core/services/workout_stats_service.dart';

class WrappedScreen extends StatefulWidget {
  final int year;

  const WrappedScreen({super.key, required this.year});

  @override
  State<WrappedScreen> createState() => _WrappedScreenState();
}

class _WrappedScreenState extends State<WrappedScreen> {
  static const double _heatCellSize = 11;
  static const double _heatCellGap = 3;

  final PageController _pageController = PageController();
  final ConfettiController _confettiController =
      ConfettiController(duration: const Duration(seconds: 3));

  AnnualWrapped? _wrapped;
  bool _isLoading = true;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _loadWrapped();
    _confettiController.play();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _confettiController.dispose();
    super.dispose();
  }

  Future<void> _loadWrapped() async {
    final service = WorkoutStatsService();
    var wrapped = await service.getAnnualWrapped(widget.year);

    // Regenerate to ensure the latest schema includes daily heatmap data.
    if (wrapped == null ||
        (wrapped.totalWorkouts > 0 && wrapped.dailyBreakdown.isEmpty)) {
      wrapped = await service.generateAnnualWrapped(widget.year);
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _wrapped = wrapped;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final pages = _wrapped == null
        ? const <Widget>[]
        : <Widget>[
            _buildIntroPage(),
            _buildTotalStatsPage(),
            _buildHeatmapPage(),
            _buildFavoriteActivityPage(),
            _buildMonthlyBreakdownPage(),
            _buildWeekdayBreakdownPage(),
            _buildStreakPage(),
            _buildFinalPage(),
          ];

    final totalPages = pages.length;

    return Scaffold(
      backgroundColor: const Color(0xFF05070D),
      body: Stack(
        children: [
          _buildBackground(),
          if (_isLoading)
            const Center(
              child: CircularProgressIndicator(color: Colors.white),
            )
          else if (_wrapped == null)
            _buildEmptyState()
          else
            SafeArea(
              child: Column(
                children: [
                  _buildHeader(totalPages),
                  Expanded(
                    child: PageView(
                      controller: _pageController,
                      onPageChanged: (index) {
                        setState(() {
                          _currentPage = index;
                        });
                      },
                      children: pages,
                    ),
                  ),
                  _buildBottomControls(totalPages),
                ],
              ),
            ),
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: _confettiController,
              blastDirectionality: BlastDirectionality.explosive,
              particleDrag: 0.05,
              emissionFrequency: 0.05,
              numberOfParticles: 18,
              gravity: 0.1,
              colors: const [
                Color(0xFF66D9FF),
                Color(0xFF00FF87),
                Color(0xFFFFC857),
                Color(0xFFFF5F5D),
                Color(0xFFA78BFA),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBackground() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF152238),
            Color(0xFF0B0F1A),
            Color(0xFF05070D),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(int totalPages) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: Colors.white.withOpacity(0.12)),
            ),
            child: Text(
              'Wrapped ${widget.year}',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
          ),
          const Spacer(),
          Text(
            '${_currentPage + 1}/$totalPages',
            style: const TextStyle(
              color: Colors.white70,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 6),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomControls(int totalPages) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 18),
      child: Row(
        children: [
          IconButton(
            onPressed:
                _currentPage > 0 ? () => _goToPage(_currentPage - 1) : null,
            icon: const Icon(Icons.arrow_back_ios_new_rounded),
            color: Colors.white,
            disabledColor: Colors.white24,
          ),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                totalPages,
                (index) => AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: _currentPage == index ? 16 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: _currentPage == index
                        ? Colors.white
                        : Colors.white.withOpacity(0.28),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
            ),
          ),
          IconButton(
            onPressed: _currentPage < totalPages - 1
                ? () => _goToPage(_currentPage + 1)
                : null,
            icon: const Icon(Icons.arrow_forward_ios_rounded),
            color: Colors.white,
            disabledColor: Colors.white24,
          ),
        ],
      ),
    );
  }

  void _goToPage(int index) {
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Text(
          'Could not load your Wrapped.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white70,
            fontSize: 18,
          ),
        ),
      ),
    );
  }

  Widget _buildPageShell({
    required Color accentColor,
    required String title,
    required String subtitle,
    required Widget child,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 6, 18, 12),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.07),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white.withOpacity(0.1)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.25),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(22, 24, 22, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: accentColor,
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                  height: 1.1,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                subtitle,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 16,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 24),
              child,
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIntroPage() {
    return _buildPageShell(
      accentColor: const Color(0xFFFFD166),
      title: 'Your year in training',
      subtitle: 'Quick summary of your consistency and volume.',
      child: Column(
        children: [
          const Icon(
            Icons.auto_awesome_rounded,
            size: 86,
            color: Color(0xFFFFD166),
          ),
          const SizedBox(height: 24),
          _buildMetricHighlight(
            label: 'Total workouts',
            value: '${_wrapped!.totalWorkouts}',
            color: const Color(0xFFFFD166),
          ),
          const SizedBox(height: 14),
          _buildMetricHighlight(
            label: 'Time invested',
            value: '${_wrapped!.totalHours}h',
            color: const Color(0xFF66D9FF),
          ),
        ],
      ),
    );
  }

  Widget _buildTotalStatsPage() {
    final averagePerWorkout = _wrapped!.totalWorkouts == 0
        ? Duration.zero
        : Duration(
            seconds:
                _wrapped!.totalDuration.inSeconds ~/ _wrapped!.totalWorkouts,
          );

    return _buildPageShell(
      accentColor: const Color(0xFF4CEB83),
      title: 'Total volume',
      subtitle: 'How much you trained this entire year.',
      child: Column(
        children: [
          _buildMetricHighlight(
            label: 'Hours trained',
            value: '${_wrapped!.totalHours}h',
            color: const Color(0xFF4CEB83),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  icon: Icons.fitness_center_rounded,
                  title: 'Workouts',
                  value: '${_wrapped!.totalWorkouts}',
                  color: const Color(0xFF66D9FF),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildStatCard(
                  icon: Icons.bolt_rounded,
                  title: 'Avg/workout',
                  value: _formatDurationCompact(averagePerWorkout),
                  color: const Color(0xFFFFC857),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeatmapPage() {
    final yearStart = DateTime(widget.year, 1, 1);
    final yearEnd = DateTime(widget.year, 12, 31);
    final gridStart = yearStart.subtract(Duration(days: yearStart.weekday - 1));
    final gridEnd = yearEnd.add(Duration(days: 7 - yearEnd.weekday));
    final totalDays = gridEnd.difference(gridStart).inDays + 1;
    final weekCount = totalDays ~/ 7;
    final maxDailyDuration = _wrapped!.maxDailyDuration;
    final bestDay = _wrapped!.bestTrainingDay;
    final bestDayDuration =
        bestDay == null ? Duration.zero : _wrapped!.getDailyDuration(bestDay);

    return _buildPageShell(
      accentColor: const Color(0xFF32D7C8),
      title: 'Year heatmap',
      subtitle:
          'Each block is a day. Darker color means more training time.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildInsightChip(
                icon: Icons.calendar_month_rounded,
                text: '${_wrapped!.activeTrainingDays} active days',
                color: const Color(0xFF32D7C8),
              ),
              _buildInsightChip(
                icon: Icons.local_fire_department_rounded,
                text: bestDay == null
                    ? 'No peak day'
                    : 'Peak: ${_formatDateShort(bestDay)} (${_formatDurationCompact(bestDayDuration)})',
                color: const Color(0xFFFF7B72),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeatmapMonthLabels(gridStart, weekCount),
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: List.generate(weekCount, (weekIndex) {
                    return Padding(
                      padding: const EdgeInsets.only(right: _heatCellGap),
                      child: Column(
                        children: List.generate(7, (weekdayIndex) {
                          final dayOffset = (weekIndex * 7) + weekdayIndex;
                          final date = gridStart.add(Duration(days: dayOffset));
                          final isInYear = date.year == widget.year;
                          final duration = isInYear
                              ? _wrapped!.getDailyDuration(date)
                              : Duration.zero;
                          final level = _getHeatLevel(duration, maxDailyDuration);

                          return Padding(
                            padding: const EdgeInsets.only(bottom: _heatCellGap),
                            child: Tooltip(
                              message: _buildHeatTooltip(date, isInYear, duration),
                              child: Container(
                                width: _heatCellSize,
                                height: _heatCellSize,
                                decoration: BoxDecoration(
                                  color: _heatColor(level, isInYear),
                                  borderRadius: BorderRadius.circular(3),
                                  border: Border.all(
                                    color: Colors.white
                                        .withOpacity(isInYear ? 0.08 : 0.03),
                                  ),
                                ),
                              ),
                            ),
                          );
                        }),
                      ),
                    );
                  }),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _buildHeatLegend(),
        ],
      ),
    );
  }

  Widget _buildHeatmapMonthLabels(DateTime gridStart, int weekCount) {
    final columnWidth = _heatCellSize + _heatCellGap;
    final totalWidth = weekCount * columnWidth;
    final monthMarkers = <Widget>[];

    for (int month = 1; month <= 12; month++) {
      final monthStart = DateTime(widget.year, month, 1);
      final weekIndex = monthStart.difference(gridStart).inDays ~/ 7;
      monthMarkers.add(
        Positioned(
          left: weekIndex * columnWidth,
          child: Text(
            _monthShort(month),
            style: const TextStyle(
              color: Colors.white54,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      );
    }

    return SizedBox(
      width: totalWidth,
      height: 12,
      child: Stack(children: monthMarkers),
    );
  }

  Widget _buildHeatLegend() {
    return Row(
      children: [
        const Text(
          'less',
          style: TextStyle(color: Colors.white54, fontSize: 11),
        ),
        const SizedBox(width: 8),
        ...List.generate(5, (index) {
          return Container(
            width: _heatCellSize,
            height: _heatCellSize,
            margin: const EdgeInsets.only(right: 4),
            decoration: BoxDecoration(
              color: _heatColor(index, true),
              borderRadius: BorderRadius.circular(3),
              border: Border.all(color: Colors.white.withOpacity(0.08)),
            ),
          );
        }),
        const SizedBox(width: 4),
        const Text(
          'more',
          style: TextStyle(color: Colors.white54, fontSize: 11),
        ),
      ],
    );
  }

  Widget _buildFavoriteActivityPage() {
    if (_wrapped!.favoriteActivity.isEmpty || _wrapped!.activityBreakdown.isEmpty) {
      return _buildPageShell(
        accentColor: const Color(0xFF66D9FF),
        title: 'Activities',
        subtitle: 'No activities recorded this year.',
        child: const SizedBox.shrink(),
      );
    }

    final favoriteDuration =
        _wrapped!.activityBreakdown[_wrapped!.favoriteActivity] ?? Duration.zero;

    return _buildPageShell(
      accentColor: const Color(0xFF66D9FF),
      title: 'Favorite activity',
      subtitle: 'Your main focus this year.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildMetricHighlight(
            label: _wrapped!.favoriteActivity.toUpperCase(),
            value: _formatDurationCompact(favoriteDuration),
            color: const Color(0xFF66D9FF),
          ),
          const SizedBox(height: 16),
          _buildActivityBreakdown(),
        ],
      ),
    );
  }

  Widget _buildActivityBreakdown() {
    final totalSeconds = _wrapped!.totalDuration.inSeconds;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.2),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: _wrapped!.activityBreakdown.entries.map((entry) {
          final ratio = totalSeconds > 0 ? entry.value.inSeconds / totalSeconds : 0.0;
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    entry.key,
                    style: const TextStyle(color: Colors.white, fontSize: 15),
                  ),
                ),
                Text(
                  '${_formatDurationCompact(entry.value)} • ${(ratio * 100).toStringAsFixed(0)}%',
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildMonthlyBreakdownPage() {
    final bestMonthName = _wrapped!.getMonthName(_wrapped!.bestMonth);
    final bestMonthDuration =
        _wrapped!.monthlyBreakdown[_wrapped!.bestMonth] ?? Duration.zero;

    return _buildPageShell(
      accentColor: const Color(0xFFFFB347),
      title: 'Strongest month',
      subtitle: 'When your training performed best.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildMetricHighlight(
            label: bestMonthName.toUpperCase(),
            value: _formatDurationCompact(bestMonthDuration),
            color: const Color(0xFFFFB347),
          ),
          const SizedBox(height: 16),
          _buildMonthlyChart(),
        ],
      ),
    );
  }

  Widget _buildMonthlyChart() {
    final durations = _wrapped!.monthlyBreakdown.values.toList();
    final maxDuration = durations.isEmpty
        ? Duration.zero
        : durations.reduce((a, b) => a > b ? a : b);
    final maxBarWidth =
        (MediaQuery.of(context).size.width - 220).clamp(90.0, 240.0).toDouble();

    return Column(
      children: List.generate(12, (index) {
        final month = index + 1;
        final duration = _wrapped!.monthlyBreakdown[month] ?? Duration.zero;
        final ratio = maxDuration.inSeconds > 0
            ? duration.inSeconds / maxDuration.inSeconds
            : 0.0;
        final barWidth = maxBarWidth * ratio;

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              SizedBox(
                width: 40,
                child: Text(
                  _wrapped!.getMonthName(month).substring(0, 3),
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ),
              SizedBox(
                width: maxBarWidth,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    height: 14,
                    width: barWidth,
                    decoration: BoxDecoration(
                      color: month == _wrapped!.bestMonth
                          ? const Color(0xFFFFB347)
                          : Colors.white.withOpacity(0.45),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                _formatDurationCompact(duration),
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ],
          ),
        );
      }),
    );
  }

  Widget _buildWeekdayBreakdownPage() {
    final bestWeekdayName = _wrapped!.getWeekdayName(_wrapped!.bestWeekday);
    final bestWeekdayDuration =
        _wrapped!.weekdayBreakdown[_wrapped!.bestWeekday] ?? Duration.zero;

    return _buildPageShell(
      accentColor: const Color(0xFFA78BFA),
      title: 'Favorite day',
      subtitle: 'Your best weekly rhythm.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildMetricHighlight(
            label: bestWeekdayName.toUpperCase(),
            value: _formatDurationCompact(bestWeekdayDuration),
            color: const Color(0xFFA78BFA),
          ),
          const SizedBox(height: 16),
          _buildWeekdayChart(),
        ],
      ),
    );
  }

  Widget _buildWeekdayChart() {
    final durations = _wrapped!.weekdayBreakdown.values.toList();
    final maxDuration = durations.isEmpty
        ? Duration.zero
        : durations.reduce((a, b) => a > b ? a : b);
    final maxBarWidth =
        (MediaQuery.of(context).size.width - 240).clamp(80.0, 220.0).toDouble();

    return Column(
      children: List.generate(7, (index) {
        final weekday = index + 1;
        final duration = _wrapped!.weekdayBreakdown[weekday] ?? Duration.zero;
        final ratio = maxDuration.inSeconds > 0
            ? duration.inSeconds / maxDuration.inSeconds
            : 0.0;
        final barWidth = maxBarWidth * ratio;

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              SizedBox(
                width: 60,
                child: Text(
                  _wrapped!.getWeekdayName(weekday),
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ),
              SizedBox(
                width: maxBarWidth,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    height: 14,
                    width: barWidth,
                    decoration: BoxDecoration(
                      color: weekday == _wrapped!.bestWeekday
                          ? const Color(0xFFA78BFA)
                          : Colors.white.withOpacity(0.45),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                _formatDurationCompact(duration),
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ],
          ),
        );
      }),
    );
  }

  Widget _buildStreakPage() {
    return _buildPageShell(
      accentColor: const Color(0xFFFF7B72),
      title: 'Consistency',
      subtitle: 'Your longest streak of training days.',
      child: Column(
        children: [
          const Icon(
            Icons.local_fire_department_rounded,
            size: 84,
            color: Color(0xFFFF7B72),
          ),
          const SizedBox(height: 18),
          _buildMetricHighlight(
            label: 'Longest streak',
            value: _wrapped!.longestStreak == 1
                ? '1 day'
                : '${_wrapped!.longestStreak} days',
            color: const Color(0xFFFF7B72),
          ),
          const SizedBox(height: 14),
          Text(
            _streakMessage(_wrapped!.longestStreak),
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white70, fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildFinalPage() {
    final nextYear = widget.year + 1;
    return _buildPageShell(
      accentColor: const Color(0xFFFFD166),
      title: '${widget.year} complete',
      subtitle: 'You finished another strong year.',
      child: Column(
        children: [
          const Icon(
            Icons.celebration_rounded,
            size: 84,
            color: Color(0xFFFFD166),
          ),
          const SizedBox(height: 20),
          Text(
            'That was ${_wrapped!.totalWorkouts} workouts and ${_wrapped!.totalHours}h dedicated to your well-being.',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 18),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF32D7C8), Color(0xFF3B82F6)],
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(
              'Goal: make $nextYear even better.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricHighlight({
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 34,
              fontWeight: FontWeight.w900,
              height: 1.0,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.2),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 8),
          Text(
            title,
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInsightChip({
    required IconData icon,
    required String text,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(0.45)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  int _getHeatLevel(Duration value, Duration maxValue) {
    if (value <= Duration.zero || maxValue <= Duration.zero) {
      return 0;
    }

    final ratio = value.inSeconds / maxValue.inSeconds;
    if (ratio >= 0.85) {
      return 4;
    }
    if (ratio >= 0.6) {
      return 3;
    }
    if (ratio >= 0.35) {
      return 2;
    }
    return 1;
  }

  Color _heatColor(int level, bool isInYear) {
    if (!isInYear) {
      return Colors.white.withOpacity(0.02);
    }

    switch (level) {
      case 1:
        return const Color(0xFF0D4429);
      case 2:
        return const Color(0xFF1E7A46);
      case 3:
        return const Color(0xFF2FBF62);
      case 4:
        return const Color(0xFF73F28D);
      default:
        return Colors.white.withOpacity(0.07);
    }
  }

  String _buildHeatTooltip(DateTime date, bool isInYear, Duration duration) {
    if (!isInYear) {
      return 'Outside ${widget.year}';
    }
    if (duration <= Duration.zero) {
      return '${_formatDateShort(date)}: no workout';
    }
    return '${_formatDateShort(date)}: ${_formatDurationCompact(duration)}';
  }

  String _monthShort(int month) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return months[month - 1];
  }

  String _formatDateShort(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    return '$month/$day';
  }

  String _formatDurationCompact(Duration duration) {
    if (duration <= Duration.zero) {
      return '0m';
    }

    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;
    if (hours == 0) {
      return '${duration.inMinutes}m';
    }
    if (minutes == 0) {
      return '${hours}h';
    }
    return '${hours}h ${minutes}m';
  }

  String _streakMessage(int streak) {
    if (streak >= 30) {
      return 'Incredible level of discipline. Keep it up.';
    }
    if (streak >= 14) {
      return 'Excellent streak. Your rhythm is very strong.';
    }
    if (streak >= 7) {
      return 'Good consistency. You can level up even more.';
    }
    if (streak >= 1) {
      return 'Good start. Stay consistent and you will evolve fast.';
    }
    return 'Start with small sessions and maintain constancy.';
  }
}
