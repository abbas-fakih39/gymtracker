// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'templates_dao.dart';

// ignore_for_file: type=lint
mixin _$TemplatesDaoMixin on DatabaseAccessor<AppDatabase> {
  $WorkoutTemplatesTable get workoutTemplates =>
      attachedDatabase.workoutTemplates;
  $ExercisesTable get exercises => attachedDatabase.exercises;
  $TemplateExercisesTable get templateExercises =>
      attachedDatabase.templateExercises;
  TemplatesDaoManager get managers => TemplatesDaoManager(this);
}

class TemplatesDaoManager {
  final _$TemplatesDaoMixin _db;
  TemplatesDaoManager(this._db);
  $$WorkoutTemplatesTableTableManager get workoutTemplates =>
      $$WorkoutTemplatesTableTableManager(
        _db.attachedDatabase,
        _db.workoutTemplates,
      );
  $$ExercisesTableTableManager get exercises =>
      $$ExercisesTableTableManager(_db.attachedDatabase, _db.exercises);
  $$TemplateExercisesTableTableManager get templateExercises =>
      $$TemplateExercisesTableTableManager(
        _db.attachedDatabase,
        _db.templateExercises,
      );
}
