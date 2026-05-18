import 'package:drift/drift.dart' show Value;
import 'package:uuid/uuid.dart';

import 'app_database.dart';

const _uuid = Uuid();

Future<void> seedExercisesIfEmpty(AppDatabase db) async {
  if ((await db.exercisesDao.getAll()).isNotEmpty) return;
  await db.batch((batch) {
    for (final row in _exercises) {
      batch.insert(
        db.exercises,
        ExercisesCompanion(
          id: Value(_uuid.v4()),
          name: Value(row.$1),
          muscleGroup: Value(row.$2),
          category: Value(row.$3),
          isCustom: const Value(false),
        ),
      );
    }
  });
}

// (name, muscleGroup, category)
const _exercises = [
  // Chest
  ('Bench Press', 'Chest', 'compound'),
  ('Incline Bench Press', 'Chest', 'compound'),
  ('Push-Up', 'Chest', 'compound'),
  ('Dumbbell Fly', 'Chest', 'isolation'),
  ('Cable Fly', 'Chest', 'isolation'),
  // Back
  ('Deadlift', 'Back', 'compound'),
  ('Pull-Up', 'Back', 'compound'),
  ('Barbell Row', 'Back', 'compound'),
  ('Lat Pulldown', 'Back', 'compound'),
  ('Seated Cable Row', 'Back', 'compound'),
  ('Face Pull', 'Back', 'isolation'),
  // Legs
  ('Squat', 'Legs', 'compound'),
  ('Romanian Deadlift', 'Legs', 'compound'),
  ('Leg Press', 'Legs', 'compound'),
  ('Walking Lunge', 'Legs', 'compound'),
  ('Leg Curl', 'Legs', 'isolation'),
  ('Calf Raise', 'Legs', 'isolation'),
  // Shoulders
  ('Overhead Press', 'Shoulders', 'compound'),
  ('Arnold Press', 'Shoulders', 'compound'),
  ('Upright Row', 'Shoulders', 'compound'),
  ('Dumbbell Lateral Raise', 'Shoulders', 'isolation'),
  ('Rear Delt Fly', 'Shoulders', 'isolation'),
  // Arms
  ('Barbell Curl', 'Arms', 'isolation'),
  ('Hammer Curl', 'Arms', 'isolation'),
  ('Preacher Curl', 'Arms', 'isolation'),
  ('Tricep Pushdown', 'Arms', 'isolation'),
  ('Skull Crusher', 'Arms', 'isolation'),
  ('Overhead Tricep Extension', 'Arms', 'isolation'),
  // Core
  ('Plank', 'Core', 'compound'),
  ('Ab Rollout', 'Core', 'compound'),
  ('Hanging Leg Raise', 'Core', 'compound'),
  ('Crunch', 'Core', 'isolation'),
  ('Cable Crunch', 'Core', 'isolation'),
];
