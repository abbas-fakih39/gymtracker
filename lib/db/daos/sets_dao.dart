import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/workout_sets_table.dart';

part 'sets_dao.g.dart';

@DriftAccessor(tables: [WorkoutSets])
class SetsDao extends DatabaseAccessor<AppDatabase> with _$SetsDaoMixin {
  SetsDao(super.db);

  Stream<List<WorkoutSet>> watchForSession(String sessionId) =>
      (select(workoutSets)
            ..where((t) => t.sessionId.equals(sessionId))
            ..orderBy([
              (t) => OrderingTerm.asc(t.exerciseId),
              (t) => OrderingTerm.asc(t.setNumber),
            ]))
          .watch();

  Future<List<WorkoutSet>> getForSession(String sessionId) =>
      (select(workoutSets)
            ..where((t) => t.sessionId.equals(sessionId)))
          .get();

  Future<List<WorkoutSet>> getForExercise(String exerciseId) =>
      (select(workoutSets)
            ..where((t) => t.exerciseId.equals(exerciseId))
            ..orderBy([(t) => OrderingTerm.desc(t.completedAt)]))
          .get();

  /// Returns the all-time best volume (weightKg * reps) for an exercise.
  Future<double?> getBestVolume(String exerciseId) async {
    final sets = await getForExercise(exerciseId);
    if (sets.isEmpty) return null;
    return sets
        .map((s) => s.weightKg * s.reps)
        .reduce((a, b) => a > b ? a : b);
  }

  /// Inserts a set and marks it as a PR if it beats the previous best volume.
  Future<String> insertSet(WorkoutSetsCompanion entry) async {
    final volume = entry.weightKg.value * entry.reps.value;
    final best = await getBestVolume(entry.exerciseId.value);
    final isPR = best == null || volume > best;
    final finalEntry = entry.copyWith(isPR: Value(isPR));
    await into(workoutSets).insert(finalEntry);
    return finalEntry.id.value;
  }

  Future<bool> updateSet(WorkoutSetsCompanion entry) =>
      update(workoutSets).replace(entry);

  Future<int> deleteSet(String id) =>
      (delete(workoutSets)..where((t) => t.id.equals(id))).go();

  /// Recalculates and updates the isPR flag for all sets of a given exercise.
  Future<void> recalculatePRs(String exerciseId) async {
    final sets = await (select(workoutSets)
          ..where((t) => t.exerciseId.equals(exerciseId))
          ..orderBy([(t) => OrderingTerm.asc(t.completedAt)]))
        .get();

    double bestVolume = 0;
    for (final s in sets) {
      final volume = s.weightKg * s.reps;
      final isPR = volume > bestVolume;
      if (isPR) bestVolume = volume;
      if (s.isPR != isPR) {
        await (update(workoutSets)..where((t) => t.id.equals(s.id)))
            .write(WorkoutSetsCompanion(isPR: Value(isPR)));
      }
    }
  }
}
