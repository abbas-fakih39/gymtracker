import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/exercises_table.dart';

part 'exercises_dao.g.dart';

@DriftAccessor(tables: [Exercises])
class ExercisesDao extends DatabaseAccessor<AppDatabase>
    with _$ExercisesDaoMixin {
  ExercisesDao(super.db);

  Stream<List<Exercise>> watchAll() => select(exercises).watch();

  Future<List<Exercise>> getAll() => select(exercises).get();

  Future<Exercise?> getById(String id) =>
      (select(exercises)..where((t) => t.id.equals(id))).getSingleOrNull();

  Stream<List<Exercise>> watchByMuscleGroup(String muscleGroup) =>
      (select(exercises)
            ..where((t) => t.muscleGroup.equals(muscleGroup)))
          .watch();

  Future<List<Exercise>> search(String query) =>
      (select(exercises)
            ..where((t) => t.name.like('%$query%')))
          .get();

  Future<String> insertExercise(ExercisesCompanion entry) =>
      into(exercises).insert(entry).then((_) => entry.id.value);

  Future<bool> updateExercise(ExercisesCompanion entry) =>
      update(exercises).replace(entry);

  Future<int> deleteExercise(String id) =>
      (delete(exercises)..where((t) => t.id.equals(id))).go();
}
