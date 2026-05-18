import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/active_workout_provider.dart';
import 'set_row.dart';

class ExerciseCard extends ConsumerWidget {
  const ExerciseCard({required this.entry, super.key});

  final ExerciseEntry entry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(activeWorkoutProvider.notifier);
    final cs = Theme.of(context).colorScheme;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entry.name,
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        entry.muscleGroup,
                        style: TextStyle(
                            fontSize: 12, color: cs.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.add),
                  tooltip: 'Add set',
                  onPressed: () => notifier.addSet(entry.id),
                ),
                IconButton(
                  icon: Icon(Icons.close, color: cs.error),
                  tooltip: 'Remove exercise',
                  onPressed: () => notifier.removeExercise(entry.id),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
          ),
          // Column headers
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                const SizedBox(width: 28),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('Weight',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 11, color: cs.onSurfaceVariant)),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('Reps',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 11, color: cs.onSurfaceVariant)),
                ),
                const SizedBox(width: 44),
              ],
            ),
          ),
          const SizedBox(height: 4),
          for (var i = 0; i < entry.sets.length; i++)
            SetRow(
              key: ValueKey('${entry.id}_${entry.sets[i].setNumber}'),
              exerciseId: entry.id,
              setIndex: i,
              entry: entry.sets[i],
            ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
