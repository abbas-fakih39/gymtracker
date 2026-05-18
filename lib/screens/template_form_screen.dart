import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../db/app_database.dart';
import '../providers/database_provider.dart';
import '../widgets/exercise_picker_sheet.dart';

const _uuid = Uuid();
const _dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

// ---------------------------------------------------------------------------
// Local form data model
// ---------------------------------------------------------------------------

class _FormExercise {
  final String exerciseId;
  final String name;
  final String muscleGroup;
  int defaultSets;

  _FormExercise({
    required this.exerciseId,
    required this.name,
    required this.muscleGroup,
    this.defaultSets = 3,
  });
}

// ---------------------------------------------------------------------------
// Screen
// ---------------------------------------------------------------------------

class TemplateFormScreen extends ConsumerStatefulWidget {
  const TemplateFormScreen({this.template, super.key});

  /// null = create mode, non-null = edit mode
  final WorkoutTemplate? template;

  @override
  ConsumerState<TemplateFormScreen> createState() => _TemplateFormScreenState();
}

class _TemplateFormScreenState extends ConsumerState<TemplateFormScreen> {
  late final TextEditingController _nameCtrl;
  late Set<int> _selectedDays;
  late List<_FormExercise> _exercises;
  bool _loading = false;
  bool _saving = false;

  bool get _isEdit => widget.template != null;

  @override
  void initState() {
    super.initState();
    final t = widget.template;
    _nameCtrl = TextEditingController(text: t?.name ?? '');
    _selectedDays = Set.of(t?.dayOfWeek ?? []);
    _exercises = [];
    if (_isEdit) _loadExistingExercises();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadExistingExercises() async {
    setState(() => _loading = true);
    final db = ref.read(databaseProvider);
    final rows =
        await db.templatesDao.getExercisesForTemplate(widget.template!.id);
    final loaded = <_FormExercise>[];
    for (final row in rows) {
      final ex = await db.exercisesDao.getById(row.exerciseId);
      if (ex == null) continue;
      loaded.add(_FormExercise(
        exerciseId: ex.id,
        name: ex.name,
        muscleGroup: ex.muscleGroup,
        defaultSets: row.defaultSets,
      ));
    }
    if (mounted) setState(() { _exercises = loaded; _loading = false; });
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Please enter a name.')));
      return;
    }
    setState(() => _saving = true);
    final db = ref.read(databaseProvider);

    try {
      final String templateId;
      final now = DateTime.now();

      if (_isEdit) {
        templateId = widget.template!.id;
        await db.templatesDao.updateTemplate(WorkoutTemplatesCompanion(
          id: Value(templateId),
          name: Value(name),
          dayOfWeek: Value(_selectedDays.toList()..sort()),
          createdAt: Value(widget.template!.createdAt),
        ));
      } else {
        templateId = _uuid.v4();
        await db.templatesDao.insertTemplate(WorkoutTemplatesCompanion(
          id: Value(templateId),
          name: Value(name),
          dayOfWeek: Value(_selectedDays.toList()..sort()),
          createdAt: Value(now),
        ));
      }

      await db.templatesDao.setTemplateExercises(
        templateId,
        [
          for (var i = 0; i < _exercises.length; i++)
            TemplateExercisesCompanion(
              id: Value(_uuid.v4()),
              templateId: Value(templateId),
              exerciseId: Value(_exercises[i].exerciseId),
              position: Value(i),
              defaultSets: Value(_exercises[i].defaultSets),
            ),
        ],
      );

      if (mounted) Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showPicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => ExercisePickerSheet(
        onSelected: (ex) {
          if (_exercises.any((e) => e.exerciseId == ex.id)) return;
          setState(() => _exercises.add(_FormExercise(
                exerciseId: ex.id,
                name: ex.name,
                muscleGroup: ex.muscleGroup,
              )));
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? 'Edit Template' : 'New Template'),
        actions: [
          if (_saving)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2)),
            )
          else
            IconButton(
              icon: const Icon(Icons.check),
              tooltip: 'Save',
              onPressed: _save,
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Name
                  TextField(
                    controller: _nameCtrl,
                    textCapitalization: TextCapitalization.words,
                    decoration: InputDecoration(
                      labelText: 'Workout name',
                      hintText: 'e.g. Push Day A',
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Days of week
                  Text('Days of week',
                      style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      for (var d = 0; d < 7; d++)
                        FilterChip(
                          label: Text(_dayNames[d]),
                          selected: _selectedDays.contains(d),
                          onSelected: (v) => setState(() =>
                              v ? _selectedDays.add(d) : _selectedDays.remove(d)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Exercises header
                  Row(
                    children: [
                      Text('Exercises',
                          style: Theme.of(context).textTheme.titleSmall),
                      const Spacer(),
                      TextButton.icon(
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('Add'),
                        onPressed: _showPicker,
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),

                  // Reorderable exercise list
                  if (_exercises.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Center(
                        child: Text('No exercises added yet.',
                            style: TextStyle(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant)),
                      ),
                    )
                  else
                    ReorderableListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      onReorder: (oldIndex, newIndex) {
                        setState(() {
                          if (newIndex > oldIndex) newIndex--;
                          _exercises.insert(
                              newIndex, _exercises.removeAt(oldIndex));
                        });
                      },
                      itemCount: _exercises.length,
                      itemBuilder: (_, i) => _ExerciseRow(
                        key: ValueKey(_exercises[i].exerciseId),
                        entry: _exercises[i],
                        onRemove: () =>
                            setState(() => _exercises.removeAt(i)),
                        onSetsChanged: (v) =>
                            setState(() => _exercises[i].defaultSets = v),
                      ),
                    ),

                  const SizedBox(height: 80),
                ],
              ),
            ),
    );
  }
}

// ---------------------------------------------------------------------------
// Exercise row for the reorderable list
// ---------------------------------------------------------------------------

class _ExerciseRow extends StatelessWidget {
  const _ExerciseRow({
    required this.entry,
    required this.onRemove,
    required this.onSetsChanged,
    super.key,
  });

  final _FormExercise entry;
  final VoidCallback onRemove;
  final ValueChanged<int> onSetsChanged;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        contentPadding: const EdgeInsets.only(left: 0, right: 8),
        leading: ReorderableDragStartListener(
          index: 0,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Icon(Icons.drag_handle, color: cs.onSurfaceVariant),
          ),
        ),
        title: Text(entry.name,
            style: const TextStyle(fontWeight: FontWeight.w500)),
        subtitle: Text(entry.muscleGroup,
            style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.remove, size: 18),
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              onPressed: entry.defaultSets > 1
                  ? () => onSetsChanged(entry.defaultSets - 1)
                  : null,
            ),
            SizedBox(
              width: 52,
              child: Text(
                '${entry.defaultSets} sets',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.add, size: 18),
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              onPressed: () => onSetsChanged(entry.defaultSets + 1),
            ),
            IconButton(
              icon: Icon(Icons.close, color: cs.error, size: 18),
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              onPressed: onRemove,
            ),
          ],
        ),
      ),
    );
  }
}
