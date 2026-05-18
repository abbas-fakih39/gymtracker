import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../db/app_database.dart';
import '../providers/database_provider.dart';

// ---------------------------------------------------------------------------
// Screen-local data model + provider
// ---------------------------------------------------------------------------

class _SessionSummary {
  final WorkoutSession session;
  final int setCount;
  const _SessionSummary(this.session, this.setCount);
}

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

// ---------------------------------------------------------------------------
// Screen
// ---------------------------------------------------------------------------

class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(_historyProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('History')),
      body: historyAsync.when(
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
                itemBuilder: (_, i) => _SessionCard(summaries[i]),
              ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Session card
// ---------------------------------------------------------------------------

class _SessionCard extends StatelessWidget {
  const _SessionCard(this.summary);

  final _SessionSummary summary;

  @override
  Widget build(BuildContext context) {
    final session = summary.session;
    final cs = Theme.of(context).colorScheme;
    final duration = session.finishedAt!.difference(session.startedAt);

    return Card(
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
                  style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _Chip(icon: Icons.timer_outlined, label: _formatDuration(duration)),
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
    );
  }

  static String _formatDate(DateTime dt) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return '${days[dt.weekday - 1]}, ${dt.day} ${months[dt.month - 1]}';
  }

  static String _formatDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    if (h == 0) return '${m}m';
    return m == 0 ? '${h}h' : '${h}h ${m}m';
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
