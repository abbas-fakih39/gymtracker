import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'dart:io';

import 'daos/exercises_dao.dart';
import 'daos/sessions_dao.dart';
import 'daos/sets_dao.dart';
import 'daos/templates_dao.dart';
import 'tables/exercises_table.dart';
import 'tables/template_exercises_table.dart';
import 'tables/workout_sessions_table.dart';
import 'tables/workout_sets_table.dart';
import 'tables/workout_templates_table.dart';

part 'app_database.g.dart';

@DriftDatabase(
  tables: [
    Exercises,
    WorkoutTemplates,
    TemplateExercises,
    WorkoutSessions,
    WorkoutSets,
  ],
  daos: [
    ExercisesDao,
    TemplatesDao,
    SessionsDao,
    SetsDao,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onUpgrade: (migrator, from, to) async {
      if (from < 2) {
        await customStatement(
            'ALTER TABLE exercises ADD COLUMN notes TEXT;');
        await customStatement(
            'ALTER TABLE workout_sets ADD COLUMN is_weight_pr INTEGER NOT NULL DEFAULT 0;');
      }
    },
  );
}

Future<AppDatabase> openAppDatabase() async {
  final dir = await getApplicationDocumentsDirectory();
  final dbPath = p.join(dir.path, 'gymtracker.db');
  return AppDatabase(NativeDatabase(File(dbPath)));
}
