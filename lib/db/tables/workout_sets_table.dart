import 'package:drift/drift.dart';

import 'workout_sessions_table.dart';
import 'exercises_table.dart';

class WorkoutSets extends Table {
  TextColumn get id => text()();
  TextColumn get sessionId =>
      text().references(WorkoutSessions, #id)();
  TextColumn get exerciseId =>
      text().references(Exercises, #id)();
  IntColumn get setNumber => integer()();
  RealColumn get weightKg => real()();
  IntColumn get reps => integer()();
  BoolColumn get isPR => boolean().withDefault(const Constant(false))();
  BoolColumn get isWeightPR => boolean().withDefault(const Constant(false))();
  DateTimeColumn get completedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}
