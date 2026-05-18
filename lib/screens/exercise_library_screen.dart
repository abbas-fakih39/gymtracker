import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../db/app_database.dart';
import '../providers/database_provider.dart';

const _uuid = Uuid();

const _muscleGroups = ['Chest', 'Back', 'Legs', 'Shoulders', 'Arms', 'Core'];

// ---------------------------------------------------------------------------
// Provider
// ---------------------------------------------------------------------------

final _exercisesProvider = StreamProvider<List<Exercise>>(
  (ref) => ref.watch(databaseProvider).exercisesDao.watchAll(),
);

// ---------------------------------------------------------------------------
// Screen
// ---------------------------------------------------------------------------

class ExerciseLibraryScreen extends ConsumerStatefulWidget {
  const ExerciseLibraryScreen({super.key});

  @override
  ConsumerState<ExerciseLibraryScreen> createState() =>
      _ExerciseLibraryScreenState();
}

class _ExerciseLibraryScreenState
    extends ConsumerState<ExerciseLibraryScreen> {
  String _searchQuery = '';
  String? _selectedGroup; // null = All

  List<Exercise> _apply(List<Exercise> all) {
    var r = _selectedGroup != null
        ? all.where((e) => e.muscleGroup == _selectedGroup).toList()
        : all;
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      r = r.where((e) => e.name.toLowerCase().contains(q)).toList();
    }
    return r;
  }

  Map<String, List<Exercise>> _group(List<Exercise> exs) {
    final map = <String, List<Exercise>>{};
    for (final g in _muscleGroups) {
      final items = exs.where((e) => e.muscleGroup == g).toList();
      if (items.isNotEmpty) map[g] = items;
    }
    for (final e in exs) {
      if (!_muscleGroups.contains(e.muscleGroup)) {
        (map[e.muscleGroup] ??= []).add(e);
      }
    }
    return map;
  }

  @override
  Widget build(BuildContext context) {
    final exercisesAsync = ref.watch(_exercisesProvider);
    final db = ref.read(databaseProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Exercises')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          builder: (_) => const _AddExerciseSheet(),
        ),
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search exercises…',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                contentPadding: EdgeInsets.zero,
              ),
              onChanged: (v) => setState(() => _searchQuery = v.trim()),
            ),
          ),
          // Filter chips
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                _FilterChip(
                  label: 'All',
                  selected: _selectedGroup == null,
                  onTap: () => setState(() => _selectedGroup = null),
                ),
                ...['Chest', 'Back', 'Legs', 'Shoulders', 'Arms', 'Core']
                    .map((g) => _FilterChip(
                          label: g,
                          selected: _selectedGroup == g,
                          onTap: () =>
                              setState(() => _selectedGroup = g),
                        )),
              ],
            ),
          ),
          // Exercise list
          Expanded(
            child: exercisesAsync.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (all) {
                final filtered = _apply(all);
                if (filtered.isEmpty) {
                  return const Center(
                    child: Text('No exercises found'),
                  );
                }
                final grouped = _group(filtered);
                final children = <Widget>[];
                for (final entry in grouped.entries) {
                  children.add(_SectionHeader(title: entry.key));
                  for (final ex in entry.value) {
                    final row = _ExerciseRow(exercise: ex);
                    if (ex.isCustom) {
                      children.add(Dismissible(
                        key: ValueKey(ex.id),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 20),
                          color: Theme.of(context).colorScheme.error,
                          child: const Icon(Icons.delete_outline,
                              color: Colors.white),
                        ),
                        onDismissed: (_) =>
                            db.exercisesDao.deleteExercise(ex.id),
                        child: row,
                      ));
                    } else {
                      children.add(row);
                    }
                  }
                }
                return ListView(
                  padding: const EdgeInsets.only(bottom: 80),
                  children: children,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Filter chip
// ---------------------------------------------------------------------------

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onTap(),
        selectedColor: cs.primaryContainer,
        labelStyle: TextStyle(
          color: selected ? cs.onPrimaryContainer : cs.onSurfaceVariant,
          fontWeight: selected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Section header
// ---------------------------------------------------------------------------

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
          color: cs.primary,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Exercise row
// ---------------------------------------------------------------------------

class _ExerciseRow extends StatelessWidget {
  const _ExerciseRow({required this.exercise});

  final Exercise exercise;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isCompound = exercise.category == 'compound';

    return ListTile(
      title: Text(exercise.name),
      trailing: Wrap(
        spacing: 6,
        alignment: WrapAlignment.end,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          if (exercise.isCustom)
            Chip(
              label: const Text('Custom'),
              padding: EdgeInsets.zero,
              labelStyle: TextStyle(
                fontSize: 10,
                color: cs.onSecondaryContainer,
              ),
              backgroundColor: cs.secondaryContainer,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: VisualDensity.compact,
            ),
          Chip(
            label: Text(isCompound ? 'Compound' : 'Isolation'),
            padding: EdgeInsets.zero,
            labelStyle: TextStyle(
              fontSize: 10,
              color: isCompound ? cs.onPrimaryContainer : cs.onSurfaceVariant,
            ),
            backgroundColor:
                isCompound ? cs.primaryContainer : cs.surfaceContainerHighest,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Add exercise bottom sheet
// ---------------------------------------------------------------------------

class _AddExerciseSheet extends ConsumerStatefulWidget {
  const _AddExerciseSheet();

  @override
  ConsumerState<_AddExerciseSheet> createState() => _AddExerciseSheetState();
}

class _AddExerciseSheetState extends ConsumerState<_AddExerciseSheet> {
  final _nameCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  String _muscleGroup = 'Chest';
  String _category = 'compound';
  bool _saving = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    final db = ref.read(databaseProvider);
    await db.exercisesDao.insertExercise(ExercisesCompanion(
      id: Value(_uuid.v4()),
      name: Value(_nameCtrl.text.trim()),
      muscleGroup: Value(_muscleGroup),
      category: Value(_category),
      isCustom: const Value(true),
    ));
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final bottom = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(24, 16, 24, 24 + bottom),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: cs.onSurfaceVariant.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text('Add Exercise',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 20),
            TextFormField(
              controller: _nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Exercise name',
                border: OutlineInputBorder(),
              ),
              textCapitalization: TextCapitalization.words,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Name is required' : null,
              autofocus: true,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _muscleGroup,
              decoration: const InputDecoration(
                labelText: 'Muscle group',
                border: OutlineInputBorder(),
              ),
              items: _muscleGroups
                  .map((g) => DropdownMenuItem(value: g, child: Text(g)))
                  .toList(),
              onChanged: (v) => setState(() => _muscleGroup = v!),
            ),
            const SizedBox(height: 16),
            Text('Category',
                style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 8),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'compound', label: Text('Compound')),
                ButtonSegment(value: 'isolation', label: Text('Isolation')),
              ],
              selected: {_category},
              onSelectionChanged: (s) =>
                  setState(() => _category = s.first),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Save'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
