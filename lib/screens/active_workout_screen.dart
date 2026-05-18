import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/active_workout_provider.dart';
import '../widgets/exercise_card.dart';
import '../widgets/exercise_picker_sheet.dart';

class ActiveWorkoutScreen extends ConsumerWidget {
  const ActiveWorkoutScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final workoutAsync = ref.watch(activeWorkoutProvider);
    final notifier = ref.read(activeWorkoutProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: workoutAsync.valueOrNull == null
            ? const Text('Workout')
            : _EditableTitle(
                name: workoutAsync.value!.workoutName,
                onSave: notifier.updateWorkoutName,
              ),
        actions: [
          if (workoutAsync.valueOrNull != null)
            _ElapsedTimer(startedAt: workoutAsync.value!.startedAt),
        ],
      ),
      body: workoutAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (state) => state == null
            ? _StartWorkoutView(onStart: (name) => notifier.startWorkout(name))
            : _WorkoutBody(state: state, notifier: notifier),
      ),
      bottomNavigationBar: workoutAsync.valueOrNull != null
          ? _FinishBar(
              isSaving: workoutAsync.value!.isSaving,
              onFinish: notifier.finishWorkout,
            )
          : null,
    );
  }
}

// ---------------------------------------------------------------------------
// Start workout view
// ---------------------------------------------------------------------------

class _StartWorkoutView extends StatelessWidget {
  const _StartWorkoutView({required this.onStart});

  final void Function(String name) onStart;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.fitness_center,
              size: 64, color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: 20),
          const Text('No active workout',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500)),
          const SizedBox(height: 24),
          FilledButton.icon(
            icon: const Icon(Icons.play_arrow),
            label: const Text('Start Workout'),
            onPressed: () => _showNameDialog(context),
          ),
        ],
      ),
    );
  }

  Future<void> _showNameDialog(BuildContext context) async {
    final ctrl = TextEditingController(
        text: _defaultName());
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Workout name'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration:
              const InputDecoration(hintText: 'e.g. Push Day A'),
          onSubmitted: (v) => Navigator.of(ctx).pop(v.trim()),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.of(ctx).pop(ctrl.text.trim()),
              child: const Text('Start')),
        ],
      ),
    );
    if (name != null && name.isNotEmpty) onStart(name);
  }

  String _defaultName() {
    final now = DateTime.now();
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return '${days[now.weekday - 1]} Workout';
  }
}

// ---------------------------------------------------------------------------
// Active workout body
// ---------------------------------------------------------------------------

class _WorkoutBody extends StatelessWidget {
  const _WorkoutBody({required this.state, required this.notifier});

  final ActiveWorkoutState state;
  final ActiveWorkoutNotifier notifier;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.only(top: 8, bottom: 100),
      children: [
        for (final entry in state.exercises)
          ExerciseCard(key: ValueKey(entry.id), entry: entry),
        const SizedBox(height: 8),
        Center(
          child: TextButton.icon(
            icon: const Icon(Icons.add),
            label: const Text('Add Exercise'),
            onPressed: () => _showPicker(context),
          ),
        ),
      ],
    );
  }

  void _showPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => ExercisePickerSheet(
        onSelected: (ex) =>
            notifier.addExercise(ex.id, ex.name, ex.muscleGroup, notes: ex.notes),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Editable title
// ---------------------------------------------------------------------------

class _EditableTitle extends StatelessWidget {
  const _EditableTitle({required this.name, required this.onSave});

  final String name;
  final void Function(String) onSave;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _showEdit(context),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(name,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 4),
          const Icon(Icons.edit, size: 14),
        ],
      ),
    );
  }

  Future<void> _showEdit(BuildContext context) async {
    final ctrl = TextEditingController(text: name);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rename workout'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          onSubmitted: (v) => Navigator.of(ctx).pop(v.trim()),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.of(ctx).pop(ctrl.text.trim()),
              child: const Text('Save')),
        ],
      ),
    );
    if (result != null && result.isNotEmpty) onSave(result);
  }
}

// ---------------------------------------------------------------------------
// Elapsed timer
// ---------------------------------------------------------------------------

class _ElapsedTimer extends StatefulWidget {
  const _ElapsedTimer({required this.startedAt});

  final DateTime startedAt;

  @override
  State<_ElapsedTimer> createState() => _ElapsedTimerState();
}

class _ElapsedTimerState extends State<_ElapsedTimer> {
  late Timer _timer;
  late Duration _elapsed;

  @override
  void initState() {
    super.initState();
    _elapsed = DateTime.now().difference(widget.startedAt);
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() => _elapsed = DateTime.now().difference(widget.startedAt));
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final h = _elapsed.inHours;
    final m = _elapsed.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = _elapsed.inSeconds.remainder(60).toString().padLeft(2, '0');
    final label = h > 0 ? '$h:$m:$s' : '$m:$s';
    return Padding(
      padding: const EdgeInsets.only(right: 16),
      child: Text(label,
          style: const TextStyle(fontFeatures: [FontFeature.tabularFigures()])),
    );
  }
}

// ---------------------------------------------------------------------------
// Finish bar
// ---------------------------------------------------------------------------

class _FinishBar extends StatelessWidget {
  const _FinishBar({required this.isSaving, required this.onFinish});

  final bool isSaving;
  final VoidCallback onFinish;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: FilledButton(
          onPressed: isSaving ? null : onFinish,
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(48),
            backgroundColor: Colors.green[700],
          ),
          child: isSaving
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                )
              : const Text('Finish Workout',
                  style: TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }
}
