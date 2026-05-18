import 'dart:math' show max;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../db/app_database.dart';
import '../providers/database_provider.dart';
import '../widgets/exercise_picker_sheet.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

const _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

String _shortDate(DateTime d) => '${d.day} ${_months[d.month - 1]}';

DateTime _weekStart(DateTime d) =>
    DateTime(d.year, d.month, d.day - (d.weekday - 1));

// ---------------------------------------------------------------------------
// Metric toggle enum
// ---------------------------------------------------------------------------

enum _ChartMetric { maxWeight, volume, totalReps }

// ---------------------------------------------------------------------------
// Local data models
// ---------------------------------------------------------------------------

class _SessionStats {
  final String sessionId;
  final DateTime date;
  final double maxWeight;
  final double volume;
  final int totalReps;

  const _SessionStats({
    required this.sessionId,
    required this.date,
    required this.maxWeight,
    required this.volume,
    required this.totalReps,
  });
}

class _PrEntry {
  final DateTime date;
  final double weightKg;
  final int reps;

  const _PrEntry({
    required this.date,
    required this.weightKg,
    required this.reps,
  });
}

class _ExerciseStats {
  final List<_SessionStats> sessions;
  final List<_PrEntry> prs;
  final int totalSessions;
  final double totalVolume;
  final double heaviestWeight;
  final int bestRepsAtHeaviest;

  const _ExerciseStats({
    required this.sessions,
    required this.prs,
    required this.totalSessions,
    required this.totalVolume,
    required this.heaviestWeight,
    required this.bestRepsAtHeaviest,
  });
}

class _WeeklyVolume {
  final DateTime weekStart;
  final double totalVolumeKg;

  const _WeeklyVolume({
    required this.weekStart,
    required this.totalVolumeKg,
  });
}

// ---------------------------------------------------------------------------
// Providers
// ---------------------------------------------------------------------------

final _exerciseStatsProvider =
    FutureProvider.autoDispose.family<_ExerciseStats, String>(
  (ref, exerciseId) async {
    final db = ref.watch(databaseProvider);
    final sets = await db.setsDao.getForExercise(exerciseId);

    final Map<String, List<WorkoutSet>> bySession = {};
    for (final s in sets) {
      (bySession[s.sessionId] ??= []).add(s);
    }

    final sessions = bySession.entries.map((e) {
      final ss = e.value;
      final date = ss
          .map((s) => s.completedAt)
          .reduce((a, b) => a.isBefore(b) ? a : b);
      final maxW = ss.map((s) => s.weightKg).reduce(max);
      return _SessionStats(
        sessionId: e.key,
        date: date,
        maxWeight: maxW,
        volume: ss.fold(0.0, (sum, s) => sum + s.weightKg * s.reps),
        totalReps: ss.fold(0, (sum, s) => sum + s.reps),
      );
    }).toList()
      ..sort((a, b) => a.date.compareTo(b.date));

    final prs = sets
        .where((s) => s.isPR)
        .map((s) =>
            _PrEntry(date: s.completedAt, weightKg: s.weightKg, reps: s.reps))
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));

    final heaviest =
        sets.isEmpty ? 0.0 : sets.map((s) => s.weightKg).reduce(max);
    final bestReps = sets.isEmpty
        ? 0
        : sets
            .where((s) => s.weightKg == heaviest)
            .map((s) => s.reps)
            .reduce(max);

    return _ExerciseStats(
      sessions: sessions,
      prs: prs,
      totalSessions: sessions.length,
      totalVolume: sets.fold(0.0, (sum, s) => sum + s.weightKg * s.reps),
      heaviestWeight: heaviest,
      bestRepsAtHeaviest: bestReps,
    );
  },
);

final _weeklyVolumeProvider =
    StreamProvider.autoDispose<List<_WeeklyVolume>>((ref) async* {
  final db = ref.watch(databaseProvider);
  await for (final sessions in db.sessionsDao.watchHistory()) {
    final Map<DateTime, double> map = {};
    for (final session in sessions) {
      final sets = await db.setsDao.getForSession(session.id);
      final ws = _weekStart(session.startedAt);
      map[ws] =
          (map[ws] ?? 0) + sets.fold(0.0, (sum, s) => sum + s.weightKg * s.reps);
    }
    final sorted = map.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    yield sorted.reversed
        .take(12)
        .toList()
        .reversed
        .map((e) => _WeeklyVolume(weekStart: e.key, totalVolumeKg: e.value))
        .toList();
  }
});

// ---------------------------------------------------------------------------
// Screen
// ---------------------------------------------------------------------------

class StatsScreen extends ConsumerStatefulWidget {
  const StatsScreen({super.key});

  @override
  ConsumerState<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends ConsumerState<StatsScreen> {
  Exercise? _selectedExercise;
  _ChartMetric _selectedMetric = _ChartMetric.maxWeight;

  void _openPicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => ExercisePickerSheet(
        onSelected: (ex) => setState(() => _selectedExercise = ex),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Stats')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _ExercisePickerButton(
            exercise: _selectedExercise,
            onTap: _openPicker,
          ),
          if (_selectedExercise != null) ...[
            const SizedBox(height: 12),
            SegmentedButton<_ChartMetric>(
              segments: const [
                ButtonSegment(
                  value: _ChartMetric.maxWeight,
                  label: Text('Max Weight'),
                ),
                ButtonSegment(
                  value: _ChartMetric.volume,
                  label: Text('Volume'),
                ),
                ButtonSegment(
                  value: _ChartMetric.totalReps,
                  label: Text('Total Reps'),
                ),
              ],
              selected: {_selectedMetric},
              onSelectionChanged: (s) =>
                  setState(() => _selectedMetric = s.first),
            ),
          ],
          const SizedBox(height: 16),
          if (_selectedExercise == null)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Center(
                child: Text(
                  'Select an exercise above\nto view its stats',
                  textAlign: TextAlign.center,
                ),
              ),
            )
          else ...[
            _ExerciseStatsView(
              exercise: _selectedExercise!,
              metric: _selectedMetric,
            ),
            const SizedBox(height: 24),
          ],
          _WeeklyVolumeSection(),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Exercise picker button
// ---------------------------------------------------------------------------

class _ExercisePickerButton extends StatelessWidget {
  const _ExercisePickerButton({required this.exercise, required this.onTap});

  final Exercise? exercise;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: onTap,
        icon: const Icon(Icons.fitness_center),
        label: Text(
          exercise?.name ?? 'Select exercise…',
          style: TextStyle(
            color: exercise == null ? cs.onSurfaceVariant : null,
          ),
        ),
        style: OutlinedButton.styleFrom(
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Exercise stats section
// ---------------------------------------------------------------------------

class _ExerciseStatsView extends ConsumerWidget {
  const _ExerciseStatsView({
    required this.exercise,
    required this.metric,
  });

  final Exercise exercise;
  final _ChartMetric metric;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(_exerciseStatsProvider(exercise.id));
    return statsAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 32),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Text('Error: $e'),
      data: (stats) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SummaryRow(stats: stats),
          const SizedBox(height: 20),
          _chartForMetric(stats),
          const SizedBox(height: 16),
          _PrList(prs: stats.prs),
        ],
      ),
    );
  }

  Widget _chartForMetric(_ExerciseStats stats) {
    if (stats.sessions.isEmpty) {
      return const SizedBox(
        height: 80,
        child: Center(child: Text('No data yet')),
      );
    }
    switch (metric) {
      case _ChartMetric.maxWeight:
        return _ChartSection(
          title: 'Max Weight (kg)',
          child: _MaxWeightChart(sessions: stats.sessions),
        );
      case _ChartMetric.volume:
        return _ChartSection(
          title: 'Volume per Session (kg)',
          child: _VolumePerSessionChart(sessions: stats.sessions),
        );
      case _ChartMetric.totalReps:
        return _ChartSection(
          title: 'Total Reps per Session',
          child: _TotalRepsChart(sessions: stats.sessions),
        );
    }
  }
}

// ---------------------------------------------------------------------------
// Summary row
// ---------------------------------------------------------------------------

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.stats});

  final _ExerciseStats stats;

  String _vol(double v) => v >= 1000
      ? '${(v / 1000).toStringAsFixed(1)} t'
      : '${v.toStringAsFixed(0)} kg';

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        _StatChip(
            icon: Icons.event_repeat,
            value: '${stats.totalSessions}',
            label: 'sessions'),
        _StatChip(
            icon: Icons.monitor_weight_outlined,
            value: _vol(stats.totalVolume),
            label: 'total volume'),
        _StatChip(
            icon: Icons.fitness_center,
            value: '${stats.heaviestWeight} kg',
            label: 'heaviest'),
        _StatChip(
            icon: Icons.repeat,
            value: '${stats.bestRepsAtHeaviest} reps',
            label: 'at heaviest'),
      ],
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({
    required this.icon,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
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
// Chart section wrapper
// ---------------------------------------------------------------------------

class _ChartSection extends StatelessWidget {
  const _ChartSection({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context)
              .textTheme
              .titleSmall
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        child,
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Max weight line chart
// ---------------------------------------------------------------------------

class _MaxWeightChart extends StatelessWidget {
  const _MaxWeightChart({required this.sessions});

  final List<_SessionStats> sessions;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final axisStyle = TextStyle(fontSize: 10, color: cs.onSurfaceVariant);
    final n = sessions.length;
    final step = (n / 5).ceil().clamp(1, n);

    Widget xLabel(double v) {
      final idx = v.toInt();
      if (idx < 0 || idx >= n) return const SizedBox.shrink();
      if (idx % step != 0 && idx != n - 1) return const SizedBox.shrink();
      return Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Text(_shortDate(sessions[idx].date), style: axisStyle),
      );
    }

    return SizedBox(
      height: 200,
      child: LineChart(
        LineChartData(
          minX: 0,
          maxX: (n - 1).toDouble(),
          lineBarsData: [
            LineChartBarData(
              spots: sessions
                  .asMap()
                  .entries
                  .map((e) => FlSpot(e.key.toDouble(), e.value.maxWeight))
                  .toList(),
              isCurved: n > 2,
              color: cs.primary,
              barWidth: 2,
              dotData: FlDotData(show: true),
              belowBarData: BarAreaData(
                show: true,
                color: cs.primary.withValues(alpha: 0.08),
              ),
            ),
          ],
          titlesData: FlTitlesData(
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                interval: 1,
                reservedSize: 28,
                getTitlesWidget: (v, _) => xLabel(v),
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 44,
                getTitlesWidget: (v, meta) {
                  if (v == meta.min) return const SizedBox.shrink();
                  return Text('${v.toInt()}', style: axisStyle);
                },
              ),
            ),
            rightTitles:
                AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles:
                AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          gridData: FlGridData(show: true, drawVerticalLine: false),
          borderData: FlBorderData(show: false),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Volume per session bar chart
// ---------------------------------------------------------------------------

class _VolumePerSessionChart extends StatelessWidget {
  const _VolumePerSessionChart({required this.sessions});

  final List<_SessionStats> sessions;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final axisStyle = TextStyle(fontSize: 10, color: cs.onSurfaceVariant);
    final n = sessions.length;
    final step = (n / 5).ceil().clamp(1, n);
    final barWidth = (240.0 / n).clamp(4.0, 24.0);

    Widget xLabel(double v) {
      final idx = v.toInt();
      if (idx < 0 || idx >= n) return const SizedBox.shrink();
      if (idx % step != 0 && idx != n - 1) return const SizedBox.shrink();
      return Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Text(_shortDate(sessions[idx].date), style: axisStyle),
      );
    }

    return SizedBox(
      height: 200,
      child: BarChart(
        BarChartData(
          barGroups: sessions
              .asMap()
              .entries
              .map(
                (e) => BarChartGroupData(
                  x: e.key,
                  barRods: [
                    BarChartRodData(
                      toY: e.value.volume,
                      color: cs.primary,
                      width: barWidth,
                      borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(4)),
                    ),
                  ],
                ),
              )
              .toList(),
          titlesData: FlTitlesData(
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                interval: 1,
                reservedSize: 28,
                getTitlesWidget: (v, _) => xLabel(v),
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 44,
                getTitlesWidget: (v, meta) {
                  if (v == 0 || v == meta.max) {
                    return const SizedBox.shrink();
                  }
                  return Text('${v.toInt()}', style: axisStyle);
                },
              ),
            ),
            rightTitles:
                AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles:
                AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          gridData: FlGridData(show: true, drawVerticalLine: false),
          borderData: FlBorderData(show: false),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Total reps per session bar chart
// ---------------------------------------------------------------------------

class _TotalRepsChart extends StatelessWidget {
  const _TotalRepsChart({required this.sessions});

  final List<_SessionStats> sessions;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final axisStyle = TextStyle(fontSize: 10, color: cs.onSurfaceVariant);
    final n = sessions.length;
    final step = (n / 5).ceil().clamp(1, n);
    final barWidth = (240.0 / n).clamp(4.0, 24.0);

    Widget xLabel(double v) {
      final idx = v.toInt();
      if (idx < 0 || idx >= n) return const SizedBox.shrink();
      if (idx % step != 0 && idx != n - 1) return const SizedBox.shrink();
      return Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Text(_shortDate(sessions[idx].date), style: axisStyle),
      );
    }

    return SizedBox(
      height: 200,
      child: BarChart(
        BarChartData(
          barGroups: sessions
              .asMap()
              .entries
              .map(
                (e) => BarChartGroupData(
                  x: e.key,
                  barRods: [
                    BarChartRodData(
                      toY: e.value.totalReps.toDouble(),
                      color: cs.tertiary,
                      width: barWidth,
                      borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(4)),
                    ),
                  ],
                ),
              )
              .toList(),
          titlesData: FlTitlesData(
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                interval: 1,
                reservedSize: 28,
                getTitlesWidget: (v, _) => xLabel(v),
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 44,
                getTitlesWidget: (v, meta) {
                  if (v == 0 || v == meta.max) {
                    return const SizedBox.shrink();
                  }
                  return Text('${v.toInt()}', style: axisStyle);
                },
              ),
            ),
            rightTitles:
                AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles:
                AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          gridData: FlGridData(show: true, drawVerticalLine: false),
          borderData: FlBorderData(show: false),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// PR list
// ---------------------------------------------------------------------------

class _PrList extends StatelessWidget {
  const _PrList({required this.prs});

  final List<_PrEntry> prs;

  @override
  Widget build(BuildContext context) {
    if (prs.isEmpty) return const SizedBox.shrink();
    final reversed = prs.reversed.toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Personal Records',
          style: Theme.of(context)
              .textTheme
              .titleSmall
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        ...reversed.map(
          (pr) => ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading:
                const Icon(Icons.star, color: Colors.amber, size: 20),
            title: Text('${pr.weightKg} kg × ${pr.reps} reps'),
            subtitle: Text(_shortDate(pr.date)),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Weekly volume section
// ---------------------------------------------------------------------------

class _WeeklyVolumeSection extends ConsumerWidget {
  const _WeeklyVolumeSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final weeksAsync = ref.watch(_weeklyVolumeProvider);
    return weeksAsync.when(
      loading: () => const SizedBox(
        height: 80,
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Text('Error: $e'),
      data: (weeks) => _ChartSection(
        title: 'Weekly Volume (all exercises)',
        child: weeks.isEmpty
            ? const SizedBox(
                height: 80,
                child: Center(child: Text('No data yet')),
              )
            : _WeeklyVolumeChart(weeks: weeks),
      ),
    );
  }
}

class _WeeklyVolumeChart extends StatelessWidget {
  const _WeeklyVolumeChart({required this.weeks});

  final List<_WeeklyVolume> weeks;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final axisStyle = TextStyle(fontSize: 10, color: cs.onSurfaceVariant);
    final n = weeks.length;
    final step = (n / 5).ceil().clamp(1, n);
    final barWidth = (240.0 / n).clamp(4.0, 32.0);

    Widget xLabel(double v) {
      final idx = v.toInt();
      if (idx < 0 || idx >= n) return const SizedBox.shrink();
      if (idx % step != 0 && idx != n - 1) return const SizedBox.shrink();
      return Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Text(_shortDate(weeks[idx].weekStart), style: axisStyle),
      );
    }

    return SizedBox(
      height: 200,
      child: BarChart(
        BarChartData(
          barGroups: weeks
              .asMap()
              .entries
              .map(
                (e) => BarChartGroupData(
                  x: e.key,
                  barRods: [
                    BarChartRodData(
                      toY: e.value.totalVolumeKg,
                      color: cs.secondary,
                      width: barWidth,
                      borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(4)),
                    ),
                  ],
                ),
              )
              .toList(),
          titlesData: FlTitlesData(
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                interval: 1,
                reservedSize: 28,
                getTitlesWidget: (v, _) => xLabel(v),
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 44,
                getTitlesWidget: (v, meta) {
                  if (v == 0 || v == meta.max) {
                    return const SizedBox.shrink();
                  }
                  return Text('${v.toInt()}', style: axisStyle);
                },
              ),
            ),
            rightTitles:
                AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles:
                AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          gridData: FlGridData(show: true, drawVerticalLine: false),
          borderData: FlBorderData(show: false),
        ),
      ),
    );
  }
}
