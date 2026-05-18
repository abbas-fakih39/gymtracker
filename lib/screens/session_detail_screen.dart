import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../db/app_database.dart';
import '../providers/database_provider.dart';

// ---------------------------------------------------------------------------
// Data models
// ---------------------------------------------------------------------------

class _ExerciseDetail {
  final String name;
  final String muscleGroup;
  final List<WorkoutSet> sets;

  const _ExerciseDetail({
    required this.name,
    required this.muscleGroup,
    required this.sets,
  });
}

class _DetailData {
  final WorkoutSession session;
  final List<_ExerciseDetail> exercises;

  const _DetailData({required this.session, required this.exercises});
}

// ---------------------------------------------------------------------------
// Provider
// ---------------------------------------------------------------------------

final _detailProvider =
    FutureProvider.autoDispose.family<_DetailData, String>((ref, sessionId) async {
  final db = ref.watch(databaseProvider);
  final session = await db.sessionsDao.getById(sessionId);
  if (session == null) throw Exception('Session not found');

  final sets = await db.setsDao.getForSession(sessionId);

  // Determine exercise order by earliest completedAt, group sets per exercise.
  final sortedSets = [...sets]
    ..sort((a, b) => a.completedAt.compareTo(b.completedAt));
  final exerciseOrder = <String>[];
  final setsByEx = <String, List<WorkoutSet>>{};
  for (final s in sortedSets) {
    if (!exerciseOrder.contains(s.exerciseId)) {
      exerciseOrder.add(s.exerciseId);
    }
    setsByEx.putIfAbsent(s.exerciseId, () => []).add(s);
  }

  final exercises = <_ExerciseDetail>[];
  for (final exId in exerciseOrder) {
    final ex = await db.exercisesDao.getById(exId);
    if (ex == null) continue;
    final exSets = setsByEx[exId]!
      ..sort((a, b) => a.setNumber.compareTo(b.setNumber));
    exercises.add(_ExerciseDetail(
      name: ex.name,
      muscleGroup: ex.muscleGroup,
      sets: exSets,
    ));
  }

  return _DetailData(session: session, exercises: exercises);
});

// ---------------------------------------------------------------------------
// Screen
// ---------------------------------------------------------------------------

class SessionDetailScreen extends ConsumerWidget {
  const SessionDetailScreen({required this.sessionId, super.key});

  final String sessionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailAsync = ref.watch(_detailProvider(sessionId));

    return Scaffold(
      appBar: AppBar(title: const Text('Workout Detail')),
      body: detailAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (data) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _HeaderCard(session: data.session),
            const SizedBox(height: 12),
            for (final ex in data.exercises) ...[
              _ExerciseSection(detail: ex),
              const SizedBox(height: 8),
            ],
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Header card
// ---------------------------------------------------------------------------

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({required this.session});

  final WorkoutSession session;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final duration = session.finishedAt?.difference(session.startedAt);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              session.name,
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              _formatDate(session.startedAt),
              style: TextStyle(color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.schedule, size: 15, color: cs.primary),
                const SizedBox(width: 4),
                Text(
                  duration != null
                      ? '${_fmtTime(session.startedAt)} – ${_fmtTime(session.finishedAt!)}'
                          '  ·  ${_fmtDuration(duration)}'
                      : _fmtTime(session.startedAt),
                  style: const TextStyle(fontSize: 13),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static String _formatDate(DateTime dt) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return '${days[dt.weekday - 1]}, ${dt.day} ${months[dt.month - 1]} ${dt.year}';
  }

  static String _fmtTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  static String _fmtDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    if (h == 0) return '${m}m';
    return m == 0 ? '${h}h' : '${h}h ${m}m';
  }
}

// ---------------------------------------------------------------------------
// Exercise section
// ---------------------------------------------------------------------------

class _ExerciseSection extends StatelessWidget {
  const _ExerciseSection({required this.detail});

  final _ExerciseDetail detail;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              detail.name,
              style: const TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 15),
            ),
            Text(
              detail.muscleGroup,
              style:
                  TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 8),
            for (final s in detail.sets) _SetLine(set: s),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Set line
// ---------------------------------------------------------------------------

class _SetLine extends StatelessWidget {
  const _SetLine({required this.set});

  final WorkoutSet set;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final weight = set.weightKg % 1 == 0
        ? set.weightKg.toInt().toString()
        : set.weightKg.toString();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          SizedBox(
            width: 24,
            child: Text(
              '${set.setNumber}.',
              style: TextStyle(
                  color: cs.onSurfaceVariant, fontSize: 13),
            ),
          ),
          Text(
            '$weight kg  ×  ${set.reps}',
            style: const TextStyle(fontSize: 14),
          ),
          const SizedBox(width: 8),
          if (set.isPR)
            const Padding(
              padding: EdgeInsets.only(right: 4),
              child: Icon(Icons.star_rounded, color: Colors.amber, size: 15),
            ),
          if (set.isWeightPR)
            const Icon(Icons.fitness_center,
                color: Colors.deepOrange, size: 15),
        ],
      ),
    );
  }
}
