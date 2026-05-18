import 'package:drift/drift.dart';

import 'workout_templates_table.dart';
import 'exercises_table.dart';

class TemplateExercises extends Table {
  TextColumn get id => text()();
  TextColumn get templateId =>
      text().references(WorkoutTemplates, #id)();
  TextColumn get exerciseId =>
      text().references(Exercises, #id)();
  IntColumn get position => integer()();
  IntColumn get defaultSets => integer()();

  @override
  Set<Column> get primaryKey => {id};
}
