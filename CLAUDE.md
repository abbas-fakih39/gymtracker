# GymTracker — Claude Code Context

## What this app is
A personal gym workout tracker for Android, built with Flutter.
Open source, MIT licensed. No backend — all data is local (SQLite).
Inspired by apps like Strong. Clean, fast, minimal UI.

## Tech stack
- Flutter + Dart
- Drift 2.14 (SQLite ORM) for local database — code-generated via build_runner
- flutter_riverpod 2.x for state management
- go_router 13.x for navigation (StatefulShellRoute.indexedStack for bottom nav)
- fl_chart for progress graphs (not yet used)
- uuid for UUID generation
- path_provider + path for DB file location

## Conventions
- All UI text in English
- Riverpod providers for all state — no setState except inside StatefulWidgets that own
  TextEditingControllers or local ephemeral state
- Drift for all DB operations — no raw SQL
- go_router for navigation; sub-screens not needing deep links use Navigator.push
- Conventional Commits for git (feat:, fix:, chore:...)
- Keep widgets under ~80 lines; extract private classes or separate files beyond that
- Dark theme enforced globally (ThemeMode.dark in main.dart)
- Screen-local StreamProviders declared at file scope are acceptable for simple read-only
  screens (see history_screen.dart pattern)
- Drift-generated types (Exercise, WorkoutSession, etc.) are used directly in the DB/
  provider layer. Plain models in lib/models/ exist for serialisation (toJson/fromJson)
  and are NOT imported in the same files as Drift types to avoid name conflicts.

## Data models (SQLite schema)

### exercises
id TEXT PK, name TEXT, muscle_group TEXT, category TEXT, is_custom INTEGER (bool)

### workout_templates
id TEXT PK, name TEXT, day_of_week TEXT (JSON array e.g. "[0,2,4]"), created_at INTEGER

### template_exercises
id TEXT PK, template_id TEXT FK, exercise_id TEXT FK, position INTEGER, default_sets INTEGER

### workout_sessions
id TEXT PK, template_id TEXT nullable FK, name TEXT, started_at INTEGER,
finished_at INTEGER nullable, notes TEXT nullable

### workout_sets
id TEXT PK, session_id TEXT FK, exercise_id TEXT FK, set_number INTEGER,
weight_kg REAL, reps INTEGER, is_p_r INTEGER (bool), completed_at INTEGER

Key: dayOfWeek uses IntListConverter (dart:convert JSON ↔ List<int>).
Key: isPR is auto-calculated in SetsDao.insertSet (volume = weightKg × reps vs best ever).

## Folder structure (current state)

```
lib/
├── main.dart                        — init DB → seed → runApp with ProviderScope + dark theme
├── router.dart                      — GoRouter with StatefulShellRoute (6 branches)
├── db/
│   ├── app_database.dart            — @DriftDatabase class + openAppDatabase() helper
│   ├── app_database.g.dart          — generated (do not edit)
│   ├── exercise_seeder.dart         — seedExercisesIfEmpty(db): inserts 33 default exercises
│   ├── tables/
│   │   ├── exercises_table.dart
│   │   ├── workout_templates_table.dart  (+ IntListConverter)
│   │   ├── template_exercises_table.dart
│   │   ├── workout_sessions_table.dart
│   │   └── workout_sets_table.dart
│   └── daos/
│       ├── exercises_dao.dart       — watchAll, getAll, getById, search, watchByMuscleGroup, CRUD
│       ├── sessions_dao.dart        — watchAll, watchActive, watchHistory, getById, CRUD
│       ├── sets_dao.dart            — watchForSession, getForSession, getForExercise,
│       │                              getBestVolume, insertSet (auto-PR), recalculatePRs, CRUD
│       └── templates_dao.dart       — watchAll, getById, getExercisesForTemplate,
│                                      watchExercisesForTemplate, setTemplateExercises
│                                      (atomic replace), deleteTemplate (cascades), CRUD
├── models/                          — Plain Dart PODOs (no Drift import): copyWith, toJson,
│   ├── models.dart                    fromJson, ==, hashCode. Import via models.dart barrel.
│   ├── exercise.dart
│   ├── workout_template.dart
│   ├── template_exercise.dart
│   ├── workout_session.dart
│   └── workout_set.dart
├── providers/
│   ├── database_provider.dart       — Provider<AppDatabase> (overridden in main via ProviderScope)
│   └── active_workout_provider.dart — StateNotifierProvider<ActiveWorkoutNotifier,
│                                      AsyncValue<ActiveWorkoutState?>>
│                                      State classes: SetEntry, ExerciseEntry, ActiveWorkoutState
├── screens/
│   ├── home_screen.dart             — STUB (placeholder only)
│   ├── active_workout_screen.dart   — COMPLETE ✓
│   ├── templates_screen.dart        — COMPLETE ✓
│   ├── template_form_screen.dart    — COMPLETE ✓ (create/edit; Navigator.push from templates)
│   ├── history_screen.dart          — COMPLETE ✓
│   ├── stats_screen.dart            — STUB (placeholder only)
│   └── exercise_library_screen.dart — STUB (placeholder only)
└── widgets/
    ├── app_shell.dart               — BottomNavigationBar shell (6 tabs, fixed type)
    ├── exercise_card.dart           — Always-expanded exercise card used in active workout
    ├── exercise_picker_sheet.dart   — DraggableScrollableSheet with live search; reused by
    │                                  active_workout_screen and template_form_screen
    ├── set_row.dart                 — StatefulWidget owning weight/reps TextEditingControllers;
    │                                  check button completes a set; gold star = PR
    └── template_card.dart           — Template list tile: name, days (Mon • Wed), exercise count
```

## Screen status

| Screen | Status | Notes |
|---|---|---|
| Home | Stub | Needs: weekly volume summary, today's template quick-start |
| Active Workout | Complete | Start/finish, exercises, sets, PR badges, elapsed timer, editable name |
| Templates | Complete | List with swipe-delete; form with days chips, drag-drop exercises, default sets |
| History | Complete | Stream of finished sessions; name, date, duration, set count |
| Stats | Stub | Needs: per-exercise volume charts (fl_chart), PR timeline |
| Exercise Library | Stub | Needs: searchable list, muscle group filter, add custom exercise |

## Active workout — how it works
- `ActiveWorkoutNotifier._init()` checks `sessionsDao.watchActive()` on startup.
  If a session exists (app was killed mid-workout), state is restored from DB.
- Sets are written to DB only when the checkmark is tapped (not on text change).
- PR is computed in the notifier before the DB insert (same logic as `SetsDao.insertSet`).
- Finishing a workout sets `finishedAt = now` and resets state to null (shows Start view).
- The `databaseProvider` override means all DAO access goes through one shared AppDatabase.

## Templates — how it works
- `setTemplateExercises` in `TemplatesDao` replaces the entire exercise list atomically
  (delete all + re-insert) — safe because position is always rebuilt from list order.
- `deleteTemplate` cascades to template_exercises in a single transaction.
- The form (`TemplateFormScreen`) is pushed imperatively via `Navigator.push`; it is NOT
  a go_router route (no deep-link requirement).
- In edit mode, the form calls `getExercisesForTemplate` + `exercisesDao.getById` per
  entry to resolve names — this runs once in initState behind a loading spinner.

## Known issues / TODOs
- Home screen is a stub — the most impactful next screen to build.
- Stats screen is a stub — requires fl_chart integration.
- Exercise Library screen is a stub — needs CRUD for custom exercises.
- No way to start a workout FROM a template yet (Home screen feature).
- `SetsDao.insertSet` duplicates the PR check that `ActiveWorkoutNotifier` also performs;
  they should stay in sync but a future refactor could unify them.
- No confirmation dialog before swipe-deleting a template (could accidentally lose data).
- The active workout state is not persisted for in-progress (unchecked) sets — only
  completed (checked) sets survive an app kill.

## What to build next (suggested order)
1. **Home screen** — weekly volume bar, today's scheduled template chip, quick-start button
   that pre-fills Active Workout with a selected template's exercises
2. **Exercise Library screen** — searchable, filterable list; add/edit/delete custom exercises
3. **Stats screen** — per-exercise volume over time (fl_chart LineChart), PR history list
4. **Start from template** — wire up template tap on Home → start session with template exercises

## Running code generation
After any change to Drift table or DAO files:
```
dart run build_runner build --delete-conflicting-outputs
```
Generated files (*.g.dart) are committed to the repo.
