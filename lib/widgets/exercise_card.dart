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
                      if (entry.notes != null && entry.notes!.isNotEmpty)
                        _NoteHint(note: entry.notes!),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(
                    Icons.sticky_note_2_outlined,
                    color: (entry.notes != null && entry.notes!.isNotEmpty)
                        ? cs.primary
                        : cs.onSurfaceVariant,
                  ),
                  tooltip: 'Exercise note',
                  visualDensity: VisualDensity.compact,
                  onPressed: () => _showNoteDialog(context, notifier),
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

  Future<void> _showNoteDialog(
      BuildContext context, ActiveWorkoutNotifier notifier) async {
    final ctrl = TextEditingController(text: entry.notes ?? '');
    final result = await showDialog<String?>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Exercise note'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          maxLines: 3,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            hintText: 'e.g. Keep elbows tucked',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, ''),
            child: const Text('Clear'),
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
    notifier.updateExerciseNote(entry.id, result.isEmpty ? null : result);
  }
}

class _NoteHint extends StatelessWidget {
  const _NoteHint({required this.note});

  final String note;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(top: 4),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: cs.secondaryContainer.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.sticky_note_2_outlined,
              size: 11, color: cs.onSecondaryContainer),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              note,
              style: TextStyle(fontSize: 11, color: cs.onSecondaryContainer),
            ),
          ),
        ],
      ),
    );
  }
}
