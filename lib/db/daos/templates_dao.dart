import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/exercises_table.dart';
import '../tables/template_exercises_table.dart';
import '../tables/workout_templates_table.dart';

part 'templates_dao.g.dart';

class TemplateWithExercises {
  final WorkoutTemplate template;
  final List<TemplateExercise> templateExercises;

  const TemplateWithExercises({
    required this.template,
    required this.templateExercises,
  });
}

@DriftAccessor(tables: [WorkoutTemplates, TemplateExercises, Exercises])
class TemplatesDao extends DatabaseAccessor<AppDatabase>
    with _$TemplatesDaoMixin {
  TemplatesDao(super.db);

  Stream<List<WorkoutTemplate>> watchAll() =>
      select(workoutTemplates).watch();

  Future<List<WorkoutTemplate>> getAll() =>
      select(workoutTemplates).get();

  Future<WorkoutTemplate?> getById(String id) =>
      (select(workoutTemplates)..where((t) => t.id.equals(id)))
          .getSingleOrNull();

  Future<List<TemplateExercise>> getExercisesForTemplate(
          String templateId) =>
      (select(templateExercises)
            ..where((t) => t.templateId.equals(templateId))
            ..orderBy([(t) => OrderingTerm.asc(t.position)]))
          .get();

  Stream<List<TemplateExercise>> watchExercisesForTemplate(
          String templateId) =>
      (select(templateExercises)
            ..where((t) => t.templateId.equals(templateId))
            ..orderBy([(t) => OrderingTerm.asc(t.position)]))
          .watch();

  Future<String> insertTemplate(WorkoutTemplatesCompanion entry) =>
      into(workoutTemplates).insert(entry).then((_) => entry.id.value);

  Future<bool> updateTemplate(WorkoutTemplatesCompanion entry) =>
      update(workoutTemplates).replace(entry);

  Future<int> deleteTemplate(String id) => transaction(() async {
        await (delete(templateExercises)
              ..where((t) => t.templateId.equals(id)))
            .go();
        return (delete(workoutTemplates)..where((t) => t.id.equals(id))).go();
      });

  Future<String> insertTemplateExercise(
          TemplateExercisesCompanion entry) =>
      into(templateExercises).insert(entry).then((_) => entry.id.value);

  Future<bool> updateTemplateExercise(
          TemplateExercisesCompanion entry) =>
      update(templateExercises).replace(entry);

  Future<int> deleteTemplateExercise(String id) =>
      (delete(templateExercises)..where((t) => t.id.equals(id))).go();

  /// Replaces the ordered exercise list for a template in one transaction.
  Future<void> setTemplateExercises(
      String templateId, List<TemplateExercisesCompanion> entries) =>
      transaction(() async {
        await (delete(templateExercises)
              ..where((t) => t.templateId.equals(templateId)))
            .go();
        for (final entry in entries) {
          await into(templateExercises).insert(entry);
        }
      });
}
