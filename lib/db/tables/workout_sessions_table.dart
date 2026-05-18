import 'package:drift/drift.dart';

import 'workout_templates_table.dart';

class WorkoutSessions extends Table {
  TextColumn get id => text()();
  // Nullable — a session can be started without a template
  TextColumn get templateId =>
      text().nullable().references(WorkoutTemplates, #id)();
  TextColumn get name => text()();
  DateTimeColumn get startedAt => dateTime()();
  DateTimeColumn get finishedAt => dateTime().nullable()();
  TextColumn get notes => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
