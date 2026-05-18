// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sets_dao.dart';

// ignore_for_file: type=lint
mixin _$SetsDaoMixin on DatabaseAccessor<AppDatabase> {
  $WorkoutTemplatesTable get workoutTemplates =>
      attachedDatabase.workoutTemplates;
  $WorkoutSessionsTable get workoutSessions => attachedDatabase.workoutSessions;
  $ExercisesTable get exercises => attachedDatabase.exercises;
  $WorkoutSetsTable get workoutSets => attachedDatabase.workoutSets;
  SetsDaoManager get managers => SetsDaoManager(this);
}

class SetsDaoManager {
  final _$SetsDaoMixin _db;
  SetsDaoManager(this._db);
  $$WorkoutTemplatesTableTableManager get workoutTemplates =>
      $$WorkoutTemplatesTableTableManager(
        _db.attachedDatabase,
        _db.workoutTemplates,
      );
  $$WorkoutSessionsTableTableManager get workoutSessions =>
      $$WorkoutSessionsTableTableManager(
        _db.attachedDatabase,
        _db.workoutSessions,
      );
  $$ExercisesTableTableManager get exercises =>
      $$ExercisesTableTableManager(_db.attachedDatabase, _db.exercises);
  $$WorkoutSetsTableTableManager get workoutSets =>
      $$WorkoutSetsTableTableManager(_db.attachedDatabase, _db.workoutSets);
}
