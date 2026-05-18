import 'dart:math' show max;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../db/app_database.dart';
import '../providers/database_provider.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

const _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

String _shortDate(DateTime d) => '${d.day} ${_months[d.month - 1]}';

// ---------------------------------------------------------------------------
// Local data models
// ---------------------------------------------------------------------------

class _SessionStats {
  final String sessionId;
  final DateTime date;
  final double maxWeight;
  final double volume;

  const _SessionStats({
    required this.sessionId,
    required this.date,
    required this.maxWeight,
    required this.volume,
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

class _ExDetailData {
  final Exercise exercise;
  final List<_SessionStats> sessions;
  final List<_PrEntry> prs;
  final double heaviestWeight;
  final int bestRepsAtHeaviest;

  const _ExDetailData({
    required this.exercise,
    required this.sessions,
    required this.prs,
    required this.heaviestWeight,
    required this.bestRepsAtHeaviest,
  });
}

// ---------------------------------------------------------------------------
// Provider
// ---------------------------------------------------------------------------

final _exerciseDetailProvider =
    FutureProvider.autoDispose.family<_ExDetailData, String>(
  (ref, exerciseId) async {
    final db = ref.watch(databaseProvider);

    final exercise = await db.exercisesDao.getById(exerciseId);
    if (exercise == null) throw Exception('Exercise not found');

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

    return _ExDetailData(
      exercise: exercise,
      sessions: sessions,
      prs: prs,
      heaviestWeight: heaviest,
      bestRepsAtHeaviest: bestReps,
    );
  },
);

// ---------------------------------------------------------------------------
// Screen
// ---------------------------------------------------------------------------

class ExerciseDetailScreen extends ConsumerWidget {
  const ExerciseDetailScreen({super.key, required this.exerciseId});

  final String exerciseId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dataAsync = ref.watch(_exerciseDetailProvider(exerciseId));
    return dataAsync.when(
      loading: () => Scaffold(
        appBar: AppBar(),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        appBar: AppBar(),
        body: Center(child: Text('Error: $e')),
      ),
      data: (data) => _ExerciseDetailContent(data: data),
    );
  }
}

// ---------------------------------------------------------------------------
// Main content
// ---------------------------------------------------------------------------

class _ExerciseDetailContent extends ConsumerStatefulWidget {
  const _ExerciseDetailContent({required this.data});

  final _ExDetailData data;

  @override
  ConsumerState<_ExerciseDetailContent> createState() =>
      _ExerciseDetailContentState();
}

class _ExerciseDetailContentState
    extends ConsumerState<_ExerciseDetailContent> {
  late String? _note;

  @override
  void initState() {
    super.initState();
    _note = widget.data.exercise.notes;
  }

  Future<void> _editNote(BuildContext context) async {
    final ctrl = TextEditingController(text: _note ?? '');
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Exercise Note'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          maxLines: 4,
          decoration: const InputDecoration(
            hintText: 'Add a note…',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    ctrl.dispose();
    if (result == null) return;
    final note = result.isEmpty ? null : result;
    final db = ref.read(databaseProvider);
    await db.exercisesDao.updateExerciseNote(widget.data.exercise.id, note);
    if (mounted) setState(() => _note = note);
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.data;
    final ex = data.exercise;
    final cs = Theme.of(context).colorScheme;
    final isCompound = ex.category == 'compound';

    return Scaffold(
      appBar: AppBar(title: Text(ex.name)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Chips row
          Wrap(
            spacing: 8,
            children: [
              Chip(
                label: Text(ex.muscleGroup),
                backgroundColor: cs.primaryContainer,
                labelStyle: TextStyle(color: cs.onPrimaryContainer),
              ),
              Chip(
                label: Text(isCompound ? 'Compound' : 'Isolation'),
                backgroundColor: isCompound
                    ? cs.secondaryContainer
                    : cs.surfaceContainerHighest,
                labelStyle: TextStyle(
                  color: isCompound
                      ? cs.onSecondaryContainer
                      : cs.onSurfaceVariant,
                ),
              ),
              if (ex.isCustom)
                Chip(
                  label: const Text('Custom'),
                  backgroundColor: cs.tertiaryContainer,
                  labelStyle: TextStyle(color: cs.onTertiaryContainer),
                ),
            ],
          ),
          const SizedBox(height: 12),
          // Sticky note card
          Card(
            child: ListTile(
              leading: Icon(Icons.sticky_note_2_outlined,
                  color: cs.primary),
              title: Text(
                _note?.isNotEmpty == true ? _note! : 'No note yet',
                style: TextStyle(
                  color: _note?.isNotEmpty == true
                      ? null
                      : cs.onSurfaceVariant,
                  fontStyle: _note?.isNotEmpty == true
                      ? FontStyle.normal
                      : FontStyle.italic,
                ),
              ),
              trailing: IconButton(
                icon: const Icon(Icons.edit_outlined),
                onPressed: () => _editNote(context),
              ),
            ),
          ),
          const SizedBox(height: 20),
          if (data.sessions.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Center(
                child: Text(
                  'No sets logged yet.\nComplete a workout to see progress.',
                  textAlign: TextAlign.center,
                ),
              ),
            )
          else ...[
            // Summary chips
            _SummaryRow(
              totalSessions: data.sessions.length,
              heaviestWeight: data.heaviestWeight,
              bestRepsAtHeaviest: data.bestRepsAtHeaviest,
            ),
            const SizedBox(height: 20),
            _ChartSection(
              title: 'Max Weight (kg)',
              child: _MaxWeightChart(sessions: data.sessions),
            ),
            const SizedBox(height: 16),
            _ChartSection(
              title: 'Volume per Session (kg)',
              child: _VolumePerSessionChart(sessions: data.sessions),
            ),
            const SizedBox(height: 16),
            _PrList(prs: data.prs),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Summary row
// ---------------------------------------------------------------------------

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.totalSessions,
    required this.heaviestWeight,
    required this.bestRepsAtHeaviest,
  });

  final int totalSessions;
  final double heaviestWeight;
  final int bestRepsAtHeaviest;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    Widget chip(IconData icon, String value, String label) {
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
                    style: TextStyle(
                        fontSize: 11, color: cs.onSurfaceVariant)),
              ],
            ),
          ],
        ),
      );
    }

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        chip(Icons.event_repeat, '$totalSessions', 'sessions'),
        chip(Icons.fitness_center, '$heaviestWeight kg', 'heaviest'),
        chip(Icons.repeat, '$bestRepsAtHeaviest reps', 'at heaviest'),
      ],
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
            leading: const Icon(Icons.star, color: Colors.amber, size: 20),
            title: Text('${pr.weightKg} kg × ${pr.reps} reps'),
            subtitle: Text(_shortDate(pr.date)),
          ),
        ),
      ],
    );
  }
}
