import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../db/app_database.dart';
import '../providers/active_workout_provider.dart';
import '../providers/database_provider.dart';

// ---------------------------------------------------------------------------
// Local data models
// ---------------------------------------------------------------------------

class _WeeklyStats {
  final int sessionCount;
  final double totalVolumeKg;

  const _WeeklyStats({required this.sessionCount, required this.totalVolumeKg});
}

class _SessionSummary {
  final WorkoutSession session;
  final int setCount;

  const _SessionSummary({required this.session, required this.setCount});
}

class _HomeData {
  final WorkoutSession? activeSession;
  final List<WorkoutTemplate> todayTemplates;
  final Map<String, int> templateExerciseCounts;
  final _WeeklyStats weeklyStats;
  final List<_SessionSummary> recentSessions;

  const _HomeData({
    required this.activeSession,
    required this.todayTemplates,
    required this.templateExerciseCounts,
    required this.weeklyStats,
    required this.recentSessions,
  });
}

// ---------------------------------------------------------------------------
// Provider
// ---------------------------------------------------------------------------

final _homeDataProvider = StreamProvider<_HomeData>((ref) {
  final db = ref.watch(databaseProvider);
  return db.sessionsDao.watchAll().asyncMap((allSessions) async {
    final now = DateTime.now();

    final activeSession =
        allSessions.where((s) => s.finishedAt == null).firstOrNull;

    // 0=Mon … 6=Sun, matching template_card.dart's _dayNames convention
    final todayIdx = now.weekday - 1;
    final templates = await db.templatesDao.getAll();
    final todayTemplates =
        templates.where((t) => t.dayOfWeek.contains(todayIdx)).toList();

    final exerciseCounts = <String, int>{};
    for (final t in todayTemplates) {
      final exs = await db.templatesDao.getExercisesForTemplate(t.id);
      exerciseCounts[t.id] = exs.length;
    }

    final weekStart =
        DateTime(now.year, now.month, now.day - (now.weekday - 1));
    final weekSessions = allSessions
        .where((s) => s.finishedAt != null && s.startedAt.isAfter(weekStart))
        .toList();
    double totalVolume = 0;
    for (final s in weekSessions) {
      final sets = await db.setsDao.getForSession(s.id);
      for (final set in sets) {
        totalVolume += set.weightKg * set.reps;
      }
    }

    final completed = allSessions.where((s) => s.finishedAt != null).toList()
      ..sort((a, b) => b.startedAt.compareTo(a.startedAt));
    final recentSummaries = <_SessionSummary>[];
    for (final s in completed.take(3)) {
      final sets = await db.setsDao.getForSession(s.id);
      recentSummaries.add(_SessionSummary(session: s, setCount: sets.length));
    }

    return _HomeData(
      activeSession: activeSession,
      todayTemplates: todayTemplates,
      templateExerciseCounts: exerciseCounts,
      weeklyStats: _WeeklyStats(
        sessionCount: weekSessions.length,
        totalVolumeKg: totalVolume,
      ),
      recentSessions: recentSummaries,
    );
  });
});

// ---------------------------------------------------------------------------
// Screen
// ---------------------------------------------------------------------------

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final homeAsync = ref.watch(_homeDataProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Home')),
      body: homeAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (data) => _HomeBody(data: data),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Body
// ---------------------------------------------------------------------------

class _HomeBody extends ConsumerWidget {
  const _HomeBody({required this.data});

  final _HomeData data;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(activeWorkoutProvider.notifier);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (data.activeSession != null)
          _ActiveWorkoutBanner(session: data.activeSession!),
        _TodaySection(
          templates: data.todayTemplates,
          exerciseCounts: data.templateExerciseCounts,
          hasActiveSession: data.activeSession != null,
          notifier: notifier,
        ),
        const SizedBox(height: 16),
        _WeeklyStatsRow(stats: data.weeklyStats),
        if (data.recentSessions.isNotEmpty) ...[
          const SizedBox(height: 24),
          _RecentSection(sessions: data.recentSessions),
        ],
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Active workout banner
// ---------------------------------------------------------------------------

class _ActiveWorkoutBanner extends StatelessWidget {
  const _ActiveWorkoutBanner({required this.session});

  final WorkoutSession session;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final elapsed = DateTime.now().difference(session.startedAt);
    final minutes = elapsed.inMinutes;
    final seconds = elapsed.inSeconds % 60;
    final elapsedLabel =
        minutes > 0 ? '${minutes}m ${seconds}s' : '${seconds}s';

    return GestureDetector(
      onTap: () => context.go('/workout'),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: cs.primaryContainer,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(Icons.fitness_center, color: cs.onPrimaryContainer),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Active Workout',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: cs.onPrimaryContainer,
                    ),
                  ),
                  Text(
                    '${session.name} • $elapsedLabel',
                    style: TextStyle(
                      fontSize: 13,
                      color: cs.onPrimaryContainer.withValues(alpha: 0.8),
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: cs.onPrimaryContainer),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Today section
// ---------------------------------------------------------------------------

class _TodaySection extends StatelessWidget {
  const _TodaySection({
    required this.templates,
    required this.exerciseCounts,
    required this.hasActiveSession,
    required this.notifier,
  });

  final List<WorkoutTemplate> templates;
  final Map<String, int> exerciseCounts;
  final bool hasActiveSession;
  final ActiveWorkoutNotifier notifier;

  static const _dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  static const _monthNames = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  String _todayLabel() {
    final now = DateTime.now();
    return '${_dayNames[now.weekday - 1]}, ${now.day} ${_monthNames[now.month - 1]}';
  }

  Future<void> _onStart(BuildContext context, String templateId) async {
    if (hasActiveSession) {
      final go = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Active Workout'),
          content: const Text(
              'You already have an active workout. Go to it instead?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Go to Workout'),
            ),
          ],
        ),
      );
      if (go == true && context.mounted) context.go('/workout');
      return;
    }
    await notifier.startFromTemplate(templateId);
    if (context.mounted) context.go('/workout');
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Today • ${_todayLabel()}',
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        if (templates.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(
              'Rest day — no workouts scheduled',
              style: TextStyle(color: cs.onSurfaceVariant),
            ),
          )
        else
          ...templates.map((t) => _TodayTemplateCard(
                template: t,
                exerciseCount: exerciseCounts[t.id] ?? 0,
                onStart: () => _onStart(context, t.id),
              )),
      ],
    );
  }
}

class _TodayTemplateCard extends StatelessWidget {
  const _TodayTemplateCard({
    required this.template,
    required this.exerciseCount,
    required this.onStart,
  });

  final WorkoutTemplate template;
  final int exerciseCount;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    template.name,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$exerciseCount ${exerciseCount == 1 ? 'exercise' : 'exercises'}',
                    style:
                        TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            FilledButton(onPressed: onStart, child: const Text('Start')),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Weekly stats
// ---------------------------------------------------------------------------

class _WeeklyStatsRow extends StatelessWidget {
  const _WeeklyStatsRow({required this.stats});

  final _WeeklyStats stats;

  String _volumeLabel() {
    if (stats.totalVolumeKg >= 1000) {
      return '${(stats.totalVolumeKg / 1000).toStringAsFixed(1)} t';
    }
    return '${stats.totalVolumeKg.toStringAsFixed(0)} kg';
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _StatChip(
            icon: Icons.calendar_today_outlined,
            value: '${stats.sessionCount}',
            label: 'sessions this week',
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatChip(
            icon: Icons.monitor_weight_outlined,
            value: _volumeLabel(),
            label: 'volume this week',
          ),
        ),
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
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: cs.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 16),
                ),
                Text(
                  label,
                  style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Recent sessions
// ---------------------------------------------------------------------------

class _RecentSection extends StatelessWidget {
  const _RecentSection({required this.sessions});

  final List<_SessionSummary> sessions;

  static const _monthNames = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  String _formatDate(DateTime dt) =>
      '${dt.day} ${_monthNames[dt.month - 1]}';

  String _formatDuration(WorkoutSession s) {
    if (s.finishedAt == null) return '';
    final d = s.finishedAt!.difference(s.startedAt);
    final h = d.inHours;
    final m = d.inMinutes % 60;
    if (h > 0) return '${h}h ${m}m';
    return '${m}m';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Recent',
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        ...sessions.map((summary) {
          final s = summary.session;
          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              title: Text(s.name,
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Wrap(
                  spacing: 10,
                  children: [
                    _Chip(Icons.calendar_today_outlined,
                        _formatDate(s.startedAt)),
                    _Chip(Icons.timer_outlined, _formatDuration(s)),
                    _Chip(Icons.fitness_center_outlined,
                        '${summary.setCount} sets'),
                  ],
                ),
              ),
            ),
          );
        }),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip(this.icon, this.label);

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: cs.onSurfaceVariant),
        const SizedBox(width: 3),
        Text(label,
            style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
      ],
    );
  }
}
