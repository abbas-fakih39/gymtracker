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
- fl_chart 0.66.x for charts (LineChart + BarChart in stats_screen.dart)
- uuid for UUID generation
- path_provider + path for DB file location

## Conventions
- All UI text in English
- Riverpod providers for all state — no setState except inside StatefulWidgets that own
  TextEditingControllers or local ephemeral state
- Drift for all DB operations — no raw SQL (exception: migration ALTER TABLE statements
  in app_database.dart use `customStatement`)
- go_router for navigation; sub-screens not needing deep links use Navigator.push
- Conventional Commits for git (feat:, fix:, chore:...)
- Keep widgets under ~80 lines; extract private classes or separate files beyond that
- Dark theme enforced globally (ThemeMode.dark in main.dart)
- Screen-local StreamProviders declared at file scope are acceptable for simple read-only
  screens (see history_screen.dart pattern)
- FutureProvider.autoDispose.family is used for per-entity data keyed by ID (e.g., exercise
  stats in stats_screen.dart). autoDispose ensures unused providers are cleaned up when the
  user switches selection.
- ConsumerStatefulWidget is used for screens that hold local interactive state (search query,
  filter chip selection, selected exercise) alongside Riverpod-watched async data.
- Drift-generated types (Exercise, WorkoutSession, etc.) are used directly in the DB/
  provider layer. Plain models in lib/models/ exist for serialisation (toJson/fromJson)
  and are NOT imported in the same files as Drift types to avoid name conflicts.
- Canonical muscle group order: Chest / Back / Legs / Shoulders / Biceps / Triceps / Core.
  "Arms" was split into "Biceps" and "Triceps" — do not reintroduce "Arms" anywhere.

## Data models (SQLite schema) — schemaVersion 2

### exercises
id TEXT PK, name TEXT, muscle_group TEXT, category TEXT, is_custom INTEGER (bool),
notes TEXT nullable

### workout_templates
id TEXT PK, name TEXT, day_of_week TEXT (JSON array e.g. "[0,2,4]", empty array = unscheduled),
created_at INTEGER

### template_exercises
id TEXT PK, template_id TEXT FK, exercise_id TEXT FK, position INTEGER, default_sets INTEGER

### workout_sessions
id TEXT PK, template_id TEXT nullable FK, name TEXT, started_at INTEGER,
finished_at INTEGER nullable, notes TEXT nullable

### workout_sets
id TEXT PK, session_id TEXT FK, exercise_id TEXT FK, set_number INTEGER,
weight_kg REAL, reps INTEGER, is_p_r INTEGER (bool), is_weight_p_r INTEGER (bool),
completed_at INTEGER

Key: dayOfWeek uses IntListConverter (dart:convert JSON ↔ List<int>). Empty list = no
scheduled days (template is available any time via "Start Workout" on the home screen).
Key: isPR is auto-calculated in SetsDao.insertSet — volume PR (weightKg × reps vs best ever).
Key: isWeightPR is auto-calculated in SetsDao.insertSet — weight PR (weightKg vs heaviest ever).
Both flags are recalculated together in SetsDao.recalculatePRs.
Key: exercises.notes stores a persistent per-exercise sticky note, shown on the exercise card
during active workouts and editable via a note icon. Survives across sessions.

## Folder structure (current state)

```
lib/
├── main.dart                        — init DB → seed → runApp with ProviderScope + dark theme
├── router.dart                      — GoRouter with StatefulShellRoute (6 branches)
├── db/
│   ├── app_database.dart            — @DriftDatabase class + openAppDatabase() helper
│   │                                  schemaVersion=2; migration adds exercises.notes
│   │                                  and workout_sets.isWeightPR via customStatement
│   ├── app_database.g.dart          — generated (do not edit)
│   ├── exercise_seeder.dart         — seedExercisesIfEmpty(db): inserts default exercises
│   │                                  using Biceps/Triceps (not Arms)
│   ├── tables/
│   │   ├── exercises_table.dart     — includes nullable notes column
│   │   ├── workout_templates_table.dart  (+ IntListConverter)
│   │   ├── template_exercises_table.dart
│   │   ├── workout_sessions_table.dart
│   │   └── workout_sets_table.dart  — includes isWeightPR column
│   └── daos/
│       ├── exercises_dao.dart       — watchAll, getAll, getById, search, watchByMuscleGroup,
│       │                              updateExerciseNote, CRUD
│       ├── sessions_dao.dart        — watchAll, watchActive, watchHistory, getById,
│       │                              getMostRecentCompletedForTemplate, CRUD
│       ├── sets_dao.dart            — watchForSession, getForSession, getForExercise,
│       │                              getBestVolume, getBestWeight, insertSet (auto-PR +
│       │                              auto-weightPR), recalculatePRs (both flags), CRUD
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
│                                      State: SetEntry (+ isWeightPR, lastSetLabel),
│                                      ExerciseEntry (+ notes), ActiveWorkoutState
│                                      Methods: startFromTemplate, _buildLastSetsMap,
│                                      updateExerciseNote, toggleCompleteSet (computes both PRs)
├── screens/
│   ├── home_screen.dart             — COMPLETE ✓
│   ├── active_workout_screen.dart   — COMPLETE ✓
│   ├── templates_screen.dart        — COMPLETE ✓
│   ├── template_form_screen.dart    — COMPLETE ✓ (create/edit; Navigator.push from templates)
│   ├── history_screen.dart          — COMPLETE ✓
│   ├── session_detail_screen.dart   — COMPLETE ✓ (Navigator.push from history)
│   ├── stats_screen.dart            — COMPLETE ✓
│   └── exercise_library_screen.dart — COMPLETE ✓
└── widgets/
    ├── app_shell.dart               — BottomNavigationBar shell (6 tabs, fixed type)
    ├── exercise_card.dart           — Always-expanded exercise card used in active workout;
    │                                  note icon (sticky_note_2_outlined) opens edit dialog;
    │                                  _NoteHint shown below exercise name when note exists
    ├── exercise_picker_sheet.dart   — DraggableScrollableSheet with live search + muscle
    │                                  group filter chips; reused by active_workout_screen,
    │                                  template_form_screen, and stats_screen
    ├── set_row.dart                 — StatefulWidget owning weight/reps TextEditingControllers;
    │                                  check button completes a set; amber star = Volume PR;
    │                                  orange barbell = Weight PR; ghost text "Last: X × Y"
    │                                  shown below each incomplete set for template workouts
    └── template_card.dart           — Template list tile: name, days (Mon • Wed or "Any day"),
                                       exercise count
```

## Screen status

| Screen | Status | Notes |
|---|---|---|
| Home | Complete | Active workout banner; smart "today" section shows templates scheduled for today (or all if none scheduled); Start button pre-fills exercises; weekly stats; recent sessions |
| Active Workout | Complete | Start/finish, exercises, sets, Volume PR (amber star) + Weight PR (orange barbell) badges, ghost text from last session, sticky notes per exercise, elapsed timer, editable name, start from template |
| Templates | Complete | List with swipe-delete; form with optional days chips, drag-drop exercises, default sets; exercise picker has muscle group filter chips |
| History | Complete | Tappable sessions (chevron); tapping opens detail screen |
| History Detail | Complete | Workout name, date, start–end time, duration; sets grouped by exercise with weight × reps + PR badges |
| Stats | Complete | Exercise picker, max-weight line chart, volume bar chart, PR list, weekly volume bar chart |
| Exercise Library | Complete | Grouped by muscle group (Biceps/Triceps split), search bar, filter chips, swipe-delete custom, add custom sheet |

## Active workout — how it works
- `ActiveWorkoutNotifier._init()` checks `sessionsDao.watchActive()` on startup.
  If a session exists (app was killed mid-workout), state is restored from DB.
  For template sessions, exercises are reconstructed from the template definition (ordered
  by position), with completed sets overlaid and empty slots filled to meet defaultSets.
  This means exercises persist correctly even if the app is killed before any sets are saved.
- Sets are written to DB only when the checkmark is tapped (not on text change).
- Both `isPR` (volume = weightKg × reps) and `isWeightPR` (heaviest weight) are computed
  in `toggleCompleteSet` and also in `SetsDao.insertSet` (the DAO value wins; duplication
  is a known issue but both paths must stay in sync).
- Ghost text (`SetEntry.lastSetLabel`): populated from the most recent completed session
  sharing the same `templateId` via `_buildLastSetsMap()`. Shows "Last: 80 × 8" under each
  incomplete set row. Only present for template-started workouts.
- Exercise sticky notes (`ExerciseEntry.notes`): loaded from `exercises.notes` column when
  building ExerciseEntry. Saved back via `updateExerciseNote()` which writes to the DB and
  updates in-memory state. Persists across all sessions for that exercise.
- Finishing a workout sets `finishedAt = now` and resets state to null (shows Start view).
- The `databaseProvider` override means all DAO access goes through one shared AppDatabase.
- `startFromTemplate(templateId)` builds the full ActiveWorkoutState from a template's
  exercises in one shot (including defaultSets empty rows per exercise, ghost text from the
  previous session, and exercise notes) and creates the session row with templateId set.

## Templates — how it works
- `setTemplateExercises` in `TemplatesDao` replaces the entire exercise list atomically
  (delete all + re-insert) — safe because position is always rebuilt from list order.
- `deleteTemplate` cascades to template_exercises in a single transaction.
- The form (`TemplateFormScreen`) is pushed imperatively via `Navigator.push`; it is NOT
  a go_router route (no deep-link requirement).
- In edit mode, the form calls `getExercisesForTemplate` + `exercisesDao.getById` per
  entry to resolve names — this runs once in initState behind a loading spinner.
- Day-of-week assignment is optional. An empty `dayOfWeek` list means the template has no
  scheduled day. Such templates still appear on the Home screen's "Start Workout" section
  (all templates shown when none are scheduled for today).
- The exercise picker inside the form has the same muscle group filter chips as the exercise
  library screen, reusing `ExercisePickerSheet`.

## Home screen — how it works
- `_homeDataProvider` is a StreamProvider that wraps `sessionsDao.watchAll().asyncMap()`.
  On each emission it fetches: today's templates (by weekday index 0=Mon…6=Sun), exercise
  counts per template, weekly volume (completed sessions since last Monday), and the 3 most
  recent completed sessions with set counts.
- The active session banner appears when any session has `finishedAt == null`; tapping it
  calls `context.go('/workout')` to switch tabs.
- "Today's workouts" section: filters templates by `dayOfWeek.contains(todayIdx)`. If none
  are scheduled for today, falls back to showing all templates (allowing any-day starts).
  Tapping "Start" calls `notifier.startFromTemplate(id)` then navigates to /workout.

## History — how it works
- `_historyProvider` watches `sessionsDao.watchHistory()` (finished sessions, newest first).
  Per session it fetches set count for the summary card.
- Each `_SessionCard` is tappable and navigates to `SessionDetailScreen` via `Navigator.push`.
- `SessionDetailScreen` uses a `FutureProvider.autoDispose.family` keyed by `sessionId`.
  It fetches the session, all its sets, and the exercise name for each exerciseId. Sets are
  grouped by exercise (ordered by first `completedAt`), then sorted by `setNumber`.
- The detail screen header shows: workout name, date ("Mon, 18 May 2026"),
  start time – end time ("08:30 – 09:45  ·  1h 15m").
- Each set row shows weight × reps, amber star for isPR, orange barbell for isWeightPR.

## Exercise Library — how it works
- `_exercisesProvider` wraps `exercisesDao.watchAll()` — reactive to inserts/deletes.
- Filtering is client-side: `_selectedGroup` (nullable String) and `_searchQuery` are local
  state in the ConsumerStatefulWidget. `_apply()` filters, `_group()` buckets by muscle group
  in the canonical order (Chest/Back/Legs/Shoulders/Biceps/Triceps/Core).
- Only `isCustom == true` rows are wrapped in `Dismissible`; default library exercises are
  not swipeable.
- Adding a custom exercise uses `_AddExerciseSheet` (modal bottom sheet) with name field,
  muscle group dropdown, and compound/isolation SegmentedButton. Saves with `isCustom: true`.

## Stats — how it works
- `_exerciseStatsProvider` is `FutureProvider.autoDispose.family<_ExerciseStats, String>`
  keyed by exercise ID. It calls `setsDao.getForExercise(id)`, groups sets by sessionId,
  derives per-session maxWeight + volume, collects isPR entries, and computes 4 summary
  stats (sessions, total volume, heaviest weight, best reps at heaviest).
- `_weeklyVolumeProvider` is `StreamProvider.autoDispose` watching `sessionsDao.watchHistory()`.
  On each emission it sums `weightKg × reps` for all sets per session, buckets by Monday-
  anchored week, and yields the 12 most recent weeks in ascending order.
- The exercise picker reuses `ExercisePickerSheet` via `showModalBottomSheet`. Selecting an
  exercise updates `_selectedExercise` state, causing `_exerciseStatsProvider(id)` to fire.
- Chart x-axes use integer indices 0…n-1; `_xLabel` suppresses crowded labels by showing
  only every nth label (≈5 visible labels regardless of dataset size).

## Known issues / TODOs
- `SetsDao.insertSet` duplicates the PR check that `ActiveWorkoutNotifier.toggleCompleteSet`
  also performs. Both must stay in sync. The DAO's computed value wins (it overwrites whatever
  the notifier passes). A future refactor could remove the duplication.
- No confirmation dialog before swipe-deleting a template (could accidentally lose data).
- The active workout state is not fully persisted for manually-added exercises that have no
  completed sets — if the app is killed before completing any set on a manually-added (non-
  template) exercise, that exercise entry disappears on restart.

## Batch 3 — upcoming

1. **Calendar screen** — monthly view with highlighted workout days; tap a day to open that
   session's detail screen; monthly stats breakdown (total sessions, total volume, total sets)
2. **Exercise library rows tappable** — tapping an exercise in the library opens a detail
   screen showing its progress charts (max weight over time, volume over time) and the
   sticky note field, reusing chart logic from stats_screen.dart
3. **Stats screen metric toggle** — filter chips or segmented button to switch the chart
   between Volume / Max Weight / Total Reps views for the selected exercise

## Running code generation
After any change to Drift table or DAO files:
```
dart run build_runner build
```
Generated files (*.g.dart) are committed to the repo.
When adding new columns or tables, also bump `schemaVersion` in `app_database.dart` and
add the corresponding migration inside the `onUpgrade` callback using `customStatement`.
