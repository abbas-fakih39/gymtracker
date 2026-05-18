import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/active_workout_provider.dart';

class SetRow extends ConsumerStatefulWidget {
  const SetRow({
    required this.exerciseId,
    required this.setIndex,
    required this.entry,
    super.key,
  });

  final String exerciseId;
  final int setIndex;
  final SetEntry entry;

  @override
  ConsumerState<SetRow> createState() => _SetRowState();
}

class _SetRowState extends ConsumerState<SetRow> {
  late final TextEditingController _weightCtrl;
  late final TextEditingController _repsCtrl;

  @override
  void initState() {
    super.initState();
    _weightCtrl = TextEditingController(text: widget.entry.weightText);
    _repsCtrl = TextEditingController(text: widget.entry.repsText);
  }

  @override
  void dispose() {
    _weightCtrl.dispose();
    _repsCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final notifier = ref.read(activeWorkoutProvider.notifier);
    final entry = widget.entry;
    final completed = entry.isCompleted;
    final cs = Theme.of(context).colorScheme;

    final showGhost =
        entry.lastSetLabel != null && !completed;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Row(
            children: [
              SizedBox(
                width: 28,
                child: Text(
                  '${entry.setNumber}',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: cs.onSurfaceVariant),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _NumberField(
                  controller: _weightCtrl,
                  hint: 'kg',
                  enabled: !completed,
                  onChanged: (v) => notifier.updateWeight(
                      widget.exerciseId, widget.setIndex, v),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _NumberField(
                  controller: _repsCtrl,
                  hint: 'reps',
                  enabled: !completed,
                  onChanged: (v) => notifier.updateReps(
                      widget.exerciseId, widget.setIndex, v),
                ),
              ),
              const SizedBox(width: 4),
              if (entry.isPR || entry.isWeightPR)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (entry.isPR)
                      const Padding(
                        padding: EdgeInsets.only(right: 2),
                        child: Icon(Icons.star_rounded,
                            color: Colors.amber, size: 16),
                      ),
                    if (entry.isWeightPR)
                      const Padding(
                        padding: EdgeInsets.only(right: 2),
                        child: Icon(Icons.fitness_center,
                            color: Colors.deepOrange, size: 16),
                      ),
                  ],
                ),
              IconButton(
                onPressed: () => notifier.toggleCompleteSet(
                    widget.exerciseId, widget.setIndex),
                icon: Icon(
                  completed
                      ? Icons.check_circle
                      : Icons.radio_button_unchecked,
                  color: completed ? Colors.green : cs.onSurfaceVariant,
                ),
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
              ),
            ],
          ),
        ),
        if (showGhost)
          Padding(
            padding: const EdgeInsets.only(left: 48, bottom: 2),
            child: Text(
              'Last: ${entry.lastSetLabel}',
              style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
            ),
          ),
      ],
    );
  }
}

class _NumberField extends StatelessWidget {
  const _NumberField({
    required this.controller,
    required this.hint,
    required this.enabled,
    required this.onChanged,
  });

  final TextEditingController controller;
  final String hint;
  final bool enabled;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      enabled: enabled,
      onChanged: onChanged,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      textAlign: TextAlign.center,
      style: const TextStyle(fontSize: 14),
      decoration: InputDecoration(
        hintText: hint,
        isDense: true,
        contentPadding:
            const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}
