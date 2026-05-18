import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../db/app_database.dart';
import 'database_provider.dart';

const _uuid = Uuid();

// ---------------------------------------------------------------------------
// Immutable state value types
// ---------------------------------------------------------------------------

class SetEntry {
  final String? dbId;
  final int setNumber;
  final String weightText;
  final String repsText;
  final bool isCompleted;
  final bool isPR;
  final bool isWeightPR;
  final String? lastSetLabel;

  const SetEntry({
    this.dbId,
    required this.setNumber,
    this.weightText = '',
    this.repsText = '',
    this.isCompleted = false,
    this.isPR = false,
    this.isWeightPR = false,
    this.lastSetLabel,
  });

  SetEntry copyWith({
    String? dbId,
    int? setNumber,
    String? weightText,
    String? repsText,
    bool? isCompleted,
    bool? isPR,
    bool? isWeightPR,
    String? lastSetLabel,
    bool clearDbId = false,
    bool clearLastSetLabel = false,
  }) =>
      SetEntry(
        dbId: clearDbId ? null : (dbId ?? this.dbId),
        setNumber: setNumber ?? this.setNumber,
        weightText: weightText ?? this.weightText,
        repsText: repsText ?? this.repsText,
        isCompleted: isCompleted ?? this.isCompleted,
        isPR: isPR ?? this.isPR,
        isWeightPR: isWeightPR ?? this.isWeightPR,
        lastSetLabel:
            clearLastSetLabel ? null : (lastSetLabel ?? this.lastSetLabel),
      );
}

class ExerciseEntry {
  final String id;
  final String name;
  final String muscleGroup;
  final List<SetEntry> sets;
  final String? notes;

  const ExerciseEntry({
    required this.id,
    required this.name,
    required this.muscleGroup,
    required this.sets,
    this.notes,
  });

  ExerciseEntry copyWith({
    List<SetEntry>? sets,
    String? notes,
    bool clearNotes = false,
  }) =>
      ExerciseEntry(
        id: id,
        name: name,
        muscleGroup: muscleGroup,
        sets: sets ?? this.sets,
        notes: clearNotes ? null : (notes ?? this.notes),
      );
}

class ActiveWorkoutState {
  final String sessionId;
  final String workoutName;
  final DateTime startedAt;
  final List<ExerciseEntry> exercises;
  final bool isSaving;

  const ActiveWorkoutState({
    required this.sessionId,
    required this.workoutName,
    required this.startedAt,
    required this.exercises,
    this.isSaving = false,
  });

  ActiveWorkoutState copyWith({
    String? workoutName,
    List<ExerciseEntry>? exercises,
    bool? isSaving,
  }) =>
      ActiveWorkoutState(
        sessionId: sessionId,
        workoutName: workoutName ?? this.workoutName,
        startedAt: startedAt,
        exercises: exercises ?? this.exercises,
        isSaving: isSaving ?? this.isSaving,
      );
}

// ---------------------------------------------------------------------------
// Notifier
// ---------------------------------------------------------------------------

class ActiveWorkoutNotifier
    extends StateNotifier<AsyncValue<ActiveWorkoutState?>> {
  ActiveWorkoutNotifier(this._db) : super(const AsyncValue.loading()) {
    _init();
  }

  final AppDatabase _db;

  Future<void> _init() async {
    try {
      final session = await _db.sessionsDao.watchActive().first;
      if (session == null) {
        state = const AsyncValue.data(null);
        return;
      }
      final sets = await _db.setsDao.getForSession(session.id);
      final setsByExercise = <String, List<WorkoutSet>>{};
      for (final s in sets) {
        setsByExercise.putIfAbsent(s.exerciseId, () => []).add(s);
      }

      final entries = <ExerciseEntry>[];

      if (session.templateId != null) {
        // Restore template exercise order and fill in any completed sets.
        final templateExercises = await _db.templatesDao
            .getExercisesForTemplate(session.templateId!);
        final templateExerciseIds = <String>{};
        final prevMap =
            await _buildLastSetsMap(session.templateId!, session.id);

        for (final te in templateExercises) {
          final exercise = await _db.exercisesDao.getById(te.exerciseId);
          if (exercise == null) continue;
          templateExerciseIds.add(te.exerciseId);

          final completed = (setsByExercise[te.exerciseId] ?? [])
            ..sort((a, b) => a.setNumber.compareTo(b.setNumber));
          final completedEntries = completed
              .map((s) => SetEntry(
                    dbId: s.id,
                    setNumber: s.setNumber,
                    weightText: s.weightKg.toString(),
                    repsText: s.reps.toString(),
                    isCompleted: true,
                    isPR: s.isPR,
                    isWeightPR: s.isWeightPR,
                  ))
              .toList();

          // Keep at least defaultSets rows; always leave one empty slot.
          final targetSets = te.defaultSets > 0 ? te.defaultSets : 1;
          final emptyCount =
              completed.length < targetSets ? targetSets - completed.length : 1;
          final emptyStart = (completedEntries.lastOrNull?.setNumber ?? 0) + 1;
          final prevForEx = prevMap[exercise.id] ?? {};
          final emptyEntries = List.generate(emptyCount, (i) {
            final setNum = emptyStart + i;
            final prev = prevForEx[setNum];
            return SetEntry(
              setNumber: setNum,
              lastSetLabel: prev == null
                  ? null
                  : _fmtWeight(prev.weightKg, prev.reps),
            );
          });

          entries.add(ExerciseEntry(
            id: exercise.id,
            name: exercise.name,
            muscleGroup: exercise.muscleGroup,
            notes: exercise.notes,
            sets: [...completedEntries, ...emptyEntries],
          ));
        }

        // Exercises manually added during the workout (not part of the template).
        for (final exId in setsByExercise.keys) {
          if (templateExerciseIds.contains(exId)) continue;
          final exercise = await _db.exercisesDao.getById(exId);
          if (exercise == null) continue;
          final exerciseSets = setsByExercise[exId]!
            ..sort((a, b) => a.setNumber.compareTo(b.setNumber));
          entries.add(ExerciseEntry(
            id: exId,
            name: exercise.name,
            muscleGroup: exercise.muscleGroup,
            notes: exercise.notes,
            sets: [
              ...exerciseSets.map((s) => SetEntry(
                    dbId: s.id,
                    setNumber: s.setNumber,
                    weightText: s.weightKg.toString(),
                    repsText: s.reps.toString(),
                    isCompleted: true,
                    isPR: s.isPR,
                    isWeightPR: s.isWeightPR,
                  )),
              SetEntry(setNumber: exerciseSets.length + 1),
            ],
          ));
        }
      } else {
        // Non-template workout: reconstruct from completed sets only.
        for (final exId in setsByExercise.keys) {
          final exercise = await _db.exercisesDao.getById(exId);
          if (exercise == null) continue;
          final exerciseSets = setsByExercise[exId]!
            ..sort((a, b) => a.setNumber.compareTo(b.setNumber));
          entries.add(ExerciseEntry(
            id: exId,
            name: exercise.name,
            muscleGroup: exercise.muscleGroup,
            notes: exercise.notes,
            sets: exerciseSets
                .map((s) => SetEntry(
                      dbId: s.id,
                      setNumber: s.setNumber,
                      weightText: s.weightKg.toString(),
                      repsText: s.reps.toString(),
                      isCompleted: true,
                      isPR: s.isPR,
                      isWeightPR: s.isWeightPR,
                    ))
                .toList(),
          ));
        }
      }

      state = AsyncValue.data(ActiveWorkoutState(
        sessionId: session.id,
        workoutName: session.name,
        startedAt: session.startedAt,
        exercises: entries,
      ));
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> startWorkout(String name) async {
    final id = _uuid.v4();
    final now = DateTime.now();
    await _db.sessionsDao.insertSession(WorkoutSessionsCompanion(
      id: Value(id),
      name: Value(name),
      startedAt: Value(now),
    ));
    state = AsyncValue.data(ActiveWorkoutState(
      sessionId: id,
      workoutName: name,
      startedAt: now,
      exercises: const [],
    ));
  }

  Future<void> updateWorkoutName(String name) async {
    final current = state.valueOrNull;
    if (current == null) return;
    await _db.sessionsDao.updateSession(WorkoutSessionsCompanion(
      id: Value(current.sessionId),
      name: Value(name),
      startedAt: Value(current.startedAt),
    ));
    state = AsyncValue.data(current.copyWith(workoutName: name));
  }

  void addExercise(String id, String name, String muscleGroup,
      {String? notes}) {
    final current = state.valueOrNull;
    if (current == null) return;
    if (current.exercises.any((e) => e.id == id)) return;
    final entry = ExerciseEntry(
      id: id,
      name: name,
      muscleGroup: muscleGroup,
      sets: [const SetEntry(setNumber: 1)],
      notes: notes,
    );
    state = AsyncValue.data(
        current.copyWith(exercises: [...current.exercises, entry]));
  }

  Future<void> removeExercise(String exerciseId) async {
    final current = state.valueOrNull;
    if (current == null) return;
    final entry = current.exercises.firstWhere((e) => e.id == exerciseId);
    for (final s in entry.sets.where((s) => s.dbId != null)) {
      await _db.setsDao.deleteSet(s.dbId!);
    }
    state = AsyncValue.data(current.copyWith(
        exercises: current.exercises.where((e) => e.id != exerciseId).toList()));
  }

  void addSet(String exerciseId) {
    final current = state.valueOrNull;
    if (current == null) return;
    final updated = current.exercises.map((e) {
      if (e.id != exerciseId) return e;
      final nextNumber = (e.sets.lastOrNull?.setNumber ?? 0) + 1;
      return e.copyWith(sets: [...e.sets, SetEntry(setNumber: nextNumber)]);
    }).toList();
    state = AsyncValue.data(current.copyWith(exercises: updated));
  }

  void updateWeight(String exerciseId, int setIndex, String text) {
    _updateSet(exerciseId, setIndex, (s) => s.copyWith(weightText: text));
  }

  void updateReps(String exerciseId, int setIndex, String text) {
    _updateSet(exerciseId, setIndex, (s) => s.copyWith(repsText: text));
  }

  Future<void> toggleCompleteSet(String exerciseId, int setIndex) async {
    final current = state.valueOrNull;
    if (current == null) return;
    final entry = current.exercises.firstWhere((e) => e.id == exerciseId);
    final set = entry.sets[setIndex];

    if (set.isCompleted && set.dbId != null) {
      await _db.setsDao.deleteSet(set.dbId!);
      _updateSet(exerciseId, setIndex,
          (s) => s.copyWith(isCompleted: false, isPR: false, clearDbId: true));
      return;
    }

    final weight = double.tryParse(set.weightText);
    final reps = int.tryParse(set.repsText);
    if (weight == null || reps == null || weight <= 0 || reps <= 0) return;

    final best = await _db.setsDao.getBestVolume(exerciseId);
    final isPR = best == null || (weight * reps) > best;
    final bestWeight = await _db.setsDao.getBestWeight(exerciseId);
    final isWeightPR = bestWeight == null || weight > bestWeight;
    final id = _uuid.v4();

    await _db.setsDao.insertSet(WorkoutSetsCompanion(
      id: Value(id),
      sessionId: Value(current.sessionId),
      exerciseId: Value(exerciseId),
      setNumber: Value(set.setNumber),
      weightKg: Value(weight),
      reps: Value(reps),
      isPR: Value(isPR),
      completedAt: Value(DateTime.now()),
    ));

    _updateSet(
        exerciseId,
        setIndex,
        (s) => s.copyWith(
            dbId: id, isCompleted: true, isPR: isPR, isWeightPR: isWeightPR));
  }

  Future<void> startFromTemplate(String templateId) async {
    final template = await _db.templatesDao.getById(templateId);
    if (template == null) return;
    final templateExercises =
        await _db.templatesDao.getExercisesForTemplate(templateId);

    final id = _uuid.v4();
    final now = DateTime.now();
    await _db.sessionsDao.insertSession(WorkoutSessionsCompanion(
      id: Value(id),
      templateId: Value(template.id),
      name: Value(template.name),
      startedAt: Value(now),
    ));

    final prevMap = await _buildLastSetsMap(templateId, id);

    final exercises = <ExerciseEntry>[];
    for (final te in templateExercises) {
      final exercise = await _db.exercisesDao.getById(te.exerciseId);
      if (exercise == null) continue;
      final count = te.defaultSets > 0 ? te.defaultSets : 1;
      final prevForEx = prevMap[exercise.id] ?? {};
      exercises.add(ExerciseEntry(
        id: exercise.id,
        name: exercise.name,
        muscleGroup: exercise.muscleGroup,
        notes: exercise.notes,
        sets: List.generate(count, (i) {
          final setNum = i + 1;
          final prev = prevForEx[setNum];
          return SetEntry(
            setNumber: setNum,
            lastSetLabel: prev == null ? null : _fmtWeight(prev.weightKg, prev.reps),
          );
        }),
      ));
    }

    state = AsyncValue.data(ActiveWorkoutState(
      sessionId: id,
      workoutName: template.name,
      startedAt: now,
      exercises: exercises,
    ));
  }

  /// Fetches the most recent completed session for [templateId] (excluding
  /// [currentSessionId]) and returns a map of exerciseId → setNumber → set.
  Future<Map<String, Map<int, WorkoutSet>>> _buildLastSetsMap(
      String templateId, String currentSessionId) async {
    final prev = await _db.sessionsDao
        .getMostRecentCompletedForTemplate(templateId, currentSessionId);
    if (prev == null) return {};
    final sets = await _db.setsDao.getForSession(prev.id);
    final map = <String, Map<int, WorkoutSet>>{};
    for (final s in sets) {
      map.putIfAbsent(s.exerciseId, () => {})[s.setNumber] = s;
    }
    return map;
  }

  static String _fmtWeight(double kg, int reps) {
    final w = kg % 1 == 0 ? kg.toInt().toString() : kg.toString();
    return '$w × $reps';
  }

  Future<void> updateExerciseNote(String exerciseId, String? note) async {
    await _db.exercisesDao.updateExerciseNote(exerciseId, note);
    final current = state.valueOrNull;
    if (current == null) return;
    state = AsyncValue.data(current.copyWith(
      exercises: current.exercises
          .map((e) => e.id == exerciseId
              ? (note == null || note.isEmpty
                  ? e.copyWith(clearNotes: true)
                  : e.copyWith(notes: note))
              : e)
          .toList(),
    ));
  }

  Future<void> finishWorkout() async {
    final current = state.valueOrNull;
    if (current == null) return;
    state = AsyncValue.data(current.copyWith(isSaving: true));
    await _db.sessionsDao.updateSession(WorkoutSessionsCompanion(
      id: Value(current.sessionId),
      name: Value(current.workoutName),
      startedAt: Value(current.startedAt),
      finishedAt: Value(DateTime.now()),
    ));
    state = const AsyncValue.data(null);
  }

  void _updateSet(
      String exerciseId, int setIndex, SetEntry Function(SetEntry) fn) {
    final current = state.valueOrNull;
    if (current == null) return;
    final updated = current.exercises.map((e) {
      if (e.id != exerciseId) return e;
      final sets = [...e.sets];
      sets[setIndex] = fn(sets[setIndex]);
      return e.copyWith(sets: sets);
    }).toList();
    state = AsyncValue.data(current.copyWith(exercises: updated));
  }
}

// ---------------------------------------------------------------------------
// Provider
// ---------------------------------------------------------------------------

final activeWorkoutProvider = StateNotifierProvider<ActiveWorkoutNotifier,
    AsyncValue<ActiveWorkoutState?>>(
  (ref) => ActiveWorkoutNotifier(ref.watch(databaseProvider)),
);
