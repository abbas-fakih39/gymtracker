import 'dart:math' show max;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../db/app_database.dart';
import '../providers/database_provider.dart';
import 'session_detail_screen.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

const _monthNames = [
  'January', 'February', 'March', 'April', 'May', 'June',
  'July', 'August', 'September', 'October', 'November', 'December',
];

const _monthShort = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

String _formatDate(DateTime dt) {
  const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  return '${days[dt.weekday - 1]}, ${dt.day} ${_monthShort[dt.month - 1]}';
}

String _formatDuration(Duration d) {
  final h = d.inHours;
  final m = d.inMinutes.remainder(60);
  if (h == 0) return '${m}m';
  return m == 0 ? '${h}h' : '${h}h ${m}m';
}

// ---------------------------------------------------------------------------
// Data models
// ---------------------------------------------------------------------------

class _SessionSummary {
  final WorkoutSession session;
  final int setCount;
  const _SessionSummary(this.session, this.setCount);
}

class _MonthData {
  final Map<int, List<WorkoutSession>> byDay;
  final int totalSessions;
  final Duration totalTime;
  final Map<String, int> templateBreakdown;
  final List<String> improvedExercises;

  const _MonthData({
    required this.byDay,
    required this.totalSessions,
    required this.totalTime,
    required this.templateBreakdown,
    required this.improvedExercises,
  });
}

// ---------------------------------------------------------------------------
// Providers
// ---------------------------------------------------------------------------

final _historyProvider = StreamProvider<List<_SessionSummary>>((ref) async* {
  final db = ref.watch(databaseProvider);
  await for (final sessions in db.sessionsDao.watchHistory()) {
    final summaries = <_SessionSummary>[];
    for (final s in sessions) {
      final sets = await db.setsDao.getForSession(s.id);
      summaries.add(_SessionSummary(s, sets.length));
    }
    yield summaries;
  }
});

final _calendarDataProvider =
    FutureProvider.autoDispose.family<_MonthData, String>(
  (ref, monthKey) async {
    final parts = monthKey.split('-');
    final year = int.parse(parts[0]);
    final month = int.parse(parts[1]);
    final db = ref.watch(databaseProvider);

    final monthStart = DateTime(year, month);
    final monthEnd = DateTime(year, month + 1);

    final allSessions = await db.sessionsDao.watchHistory().first;
    final thisSessions = allSessions
        .where((s) =>
            !s.startedAt.isBefore(monthStart) &&
            s.startedAt.isBefore(monthEnd))
        .toList();

    final byDay = <int, List<WorkoutSession>>{};
    for (final s in thisSessions) {
      (byDay[s.startedAt.day] ??= []).add(s);
    }

    var totalSeconds = 0;
    for (final s in thisSessions) {
      if (s.finishedAt != null) {
        totalSeconds += s.finishedAt!.difference(s.startedAt).inSeconds;
      }
    }

    final breakdown = <String, int>{};
    for (final s in thisSessions) {
      breakdown[s.name] = (breakdown[s.name] ?? 0) + 1;
    }

    // Improved exercises: this month's max weight vs prior best
    final thisMonthBest = <String, double>{};
    for (final s in thisSessions) {
      final sets = await db.setsDao.getForSession(s.id);
      for (final set in sets) {
        final cur = thisMonthBest[set.exerciseId] ?? 0.0;
        if (set.weightKg > cur) thisMonthBest[set.exerciseId] = set.weightKg;
      }
    }

    final improvedNames = <String>[];
    for (final entry in thisMonthBest.entries) {
      final allSets = await db.setsDao.getForExercise(entry.key);
      final priorSets =
          allSets.where((s) => s.completedAt.isBefore(monthStart)).toList();
      if (priorSets.isEmpty) continue;
      final priorMax = priorSets.map((s) => s.weightKg).reduce(max);
      if (entry.value > priorMax) {
        final exercise = await db.exercisesDao.getById(entry.key);
        if (exercise != null) improvedNames.add(exercise.name);
      }
    }
    improvedNames.sort();

    return _MonthData(
      byDay: byDay,
      totalSessions: thisSessions.length,
      totalTime: Duration(seconds: totalSeconds),
      templateBreakdown: breakdown,
      improvedExercises: improvedNames,
    );
  },
);

// ---------------------------------------------------------------------------
// Screen
// ---------------------------------------------------------------------------

class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  bool _showCalendar = false;
  late DateTime _focusedMonth;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _focusedMonth = DateTime(now.year, now.month);
  }

  String get _monthKey => '${_focusedMonth.year}-${_focusedMonth.month}';

  void _prevMonth() => setState(
      () => _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month - 1));

  void _nextMonth() => setState(
      () => _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month + 1));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('History'),
        actions: [
          IconButton(
            tooltip: _showCalendar ? 'List view' : 'Calendar view',
            icon: Icon(
                _showCalendar ? Icons.list_alt_outlined : Icons.calendar_month),
            onPressed: () => setState(() => _showCalendar = !_showCalendar),
          ),
        ],
      ),
      body: _showCalendar ? _buildCalendarView() : _buildListView(),
    );
  }

  Widget _buildListView() {
    final historyAsync = ref.watch(_historyProvider);
    return historyAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (summaries) => summaries.isEmpty
          ? const Center(
              child: Text(
                'No workouts logged yet.\nFinish a workout to see it here.',
                textAlign: TextAlign.center,
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: summaries.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (_, i) => _SessionCard(
                summaries[i],
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => SessionDetailScreen(
                        sessionId: summaries[i].session.id),
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildCalendarView() {
    return Column(
      children: [
        _MonthNavBar(
          month: _focusedMonth,
          onPrev: _prevMonth,
          onNext: _nextMonth,
        ),
        Expanded(
          child: Consumer(
            builder: (ctx, ref, _) {
              final dataAsync = ref.watch(_calendarDataProvider(_monthKey));
              return dataAsync.when(
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('Error: $e')),
                data: (data) => ListView(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
                  children: [
                    _CalendarGrid(
                      month: _focusedMonth,
                      data: data,
                      onDayTap: (sessions) => _openDay(ctx, sessions),
                    ),
                    const SizedBox(height: 16),
                    _MonthlyStats(data: data),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  void _openDay(BuildContext context, List<WorkoutSession> sessions) {
    if (sessions.length == 1) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => SessionDetailScreen(sessionId: sessions.first.id),
        ),
      );
    } else {
      showModalBottomSheet(
        context: context,
        builder: (_) => _DaySessionSheet(sessions: sessions),
      );
    }
  }
}

// ---------------------------------------------------------------------------
// Month navigation bar
// ---------------------------------------------------------------------------

class _MonthNavBar extends StatelessWidget {
  const _MonthNavBar({
    required this.month,
    required this.onPrev,
    required this.onNext,
  });

  final DateTime month;
  final VoidCallback onPrev;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: onPrev,
          ),
          Expanded(
            child: Text(
              '${_monthNames[month.month - 1]} ${month.year}',
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: onNext,
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Calendar grid
// ---------------------------------------------------------------------------

class _CalendarGrid extends StatelessWidget {
  const _CalendarGrid({
    required this.month,
    required this.data,
    required this.onDayTap,
  });

  final DateTime month;
  final _MonthData data;
  final void Function(List<WorkoutSession>) onDayTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    // Monday-based: weekday 1=Mon…7=Sun → leading blanks = weekday - 1
    final firstWeekday = DateTime(month.year, month.month, 1).weekday;
    final leadingBlanks = firstWeekday - 1;

    const dayLabels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

    return Column(
      children: [
        // Day-of-week header
        Row(
          children: dayLabels
              .map(
                (d) => Expanded(
                  child: Center(
                    child: Text(
                      d,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 4),
        // Day grid
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            mainAxisSpacing: 4,
            crossAxisSpacing: 4,
            childAspectRatio: 1,
          ),
          itemCount: leadingBlanks + daysInMonth,
          itemBuilder: (_, i) {
            if (i < leadingBlanks) return const SizedBox.shrink();
            final day = i - leadingBlanks + 1;
            final sessions = data.byDay[day];
            final hasWorkout = sessions != null && sessions.isNotEmpty;

            final isToday = DateTime.now().year == month.year &&
                DateTime.now().month == month.month &&
                DateTime.now().day == day;

            return GestureDetector(
              onTap: hasWorkout ? () => onDayTap(sessions) : null,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: hasWorkout
                      ? cs.primary
                      : isToday
                          ? cs.primaryContainer.withValues(alpha: 0.4)
                          : Colors.transparent,
                  border: isToday && !hasWorkout
                      ? Border.all(color: cs.primary, width: 1)
                      : null,
                ),
                child: Center(
                  child: Text(
                    '$day',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: hasWorkout || isToday
                          ? FontWeight.bold
                          : FontWeight.normal,
                      color: hasWorkout
                          ? cs.onPrimary
                          : isToday
                              ? cs.primary
                              : cs.onSurface,
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Day session picker (multiple sessions on same day)
// ---------------------------------------------------------------------------

class _DaySessionSheet extends StatelessWidget {
  const _DaySessionSheet({required this.sessions});

  final List<WorkoutSession> sessions;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Text(
            _formatDate(sessions.first.startedAt),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          ...sessions.map(
            (s) => ListTile(
              title: Text(s.name),
              subtitle: Text(_formatDuration(
                (s.finishedAt ?? s.startedAt).difference(s.startedAt),
              )),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => SessionDetailScreen(sessionId: s.id),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Monthly stats
// ---------------------------------------------------------------------------

class _MonthlyStats extends StatelessWidget {
  const _MonthlyStats({required this.data});

  final _MonthData data;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    if (data.totalSessions == 0) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: Text(
            'No workouts this month',
            style: TextStyle(color: cs.onSurfaceVariant),
          ),
        ),
      );
    }

    // Sort template breakdown by count desc
    final breakdown = data.templateBreakdown.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Monthly Summary',
          style: Theme.of(context)
              .textTheme
              .titleSmall
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        // Summary chips
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _StatChip(
              icon: Icons.event_repeat,
              value: '${data.totalSessions}',
              label: data.totalSessions == 1 ? 'session' : 'sessions',
              cs: cs,
            ),
            _StatChip(
              icon: Icons.timer_outlined,
              value: _formatDuration(data.totalTime),
              label: 'total time',
              cs: cs,
            ),
          ],
        ),
        const SizedBox(height: 16),
        // Template breakdown
        Text(
          'Workouts',
          style: Theme.of(context)
              .textTheme
              .labelLarge
              ?.copyWith(color: cs.onSurfaceVariant),
        ),
        const SizedBox(height: 4),
        ...breakdown.map(
          (e) => ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.fitness_center, size: 18, color: cs.primary),
            title: Text(e.key),
            trailing: Text(
              '×${e.value}',
              style: TextStyle(
                  fontWeight: FontWeight.bold, color: cs.primary),
            ),
          ),
        ),
        // Improved exercises
        if (data.improvedExercises.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(
            'Exercises Improved',
            style: Theme.of(context)
                .textTheme
                .labelLarge
                ?.copyWith(color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: 4),
          ...data.improvedExercises.map(
            (name) => ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading:
                  const Icon(Icons.trending_up, size: 18, color: Colors.amber),
              title: Text(name),
            ),
          ),
        ],
      ],
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({
    required this.icon,
    required this.value,
    required this.label,
    required this.cs,
  });

  final IconData icon;
  final String value;
  final String label;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: cs.primary),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 13)),
              Text(label,
                  style:
                      TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
            ],
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Session card (list view)
// ---------------------------------------------------------------------------

class _SessionCard extends StatelessWidget {
  const _SessionCard(this.summary, {this.onTap});

  final _SessionSummary summary;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final session = summary.session;
    final cs = Theme.of(context).colorScheme;
    final duration = session.finishedAt!.difference(session.startedAt);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      session.name,
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ),
                  Text(
                    _formatDate(session.startedAt),
                    style: TextStyle(
                        fontSize: 13, color: cs.onSurfaceVariant),
                  ),
                  const SizedBox(width: 4),
                  Icon(Icons.chevron_right,
                      size: 18, color: cs.onSurfaceVariant),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  _Chip(
                    icon: Icons.timer_outlined,
                    label: _formatDuration(duration),
                  ),
                  const SizedBox(width: 12),
                  _Chip(
                    icon: Icons.check_circle_outline,
                    label: '${summary.setCount} '
                        '${summary.setCount == 1 ? 'set' : 'sets'}',
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: cs.primary),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 13)),
      ],
    );
  }
}
