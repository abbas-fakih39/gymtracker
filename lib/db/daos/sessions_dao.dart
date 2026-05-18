import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/workout_sessions_table.dart';

part 'sessions_dao.g.dart';

@DriftAccessor(tables: [WorkoutSessions])
class SessionsDao extends DatabaseAccessor<AppDatabase>
    with _$SessionsDaoMixin {
  SessionsDao(super.db);

  /// Emits every time any session row changes.
  Stream<List<WorkoutSession>> watchAll() =>
      (select(workoutSessions)
            ..orderBy([(t) => OrderingTerm.desc(t.startedAt)]))
          .watch();

  /// Sessions that have not been finished yet (active workout).
  Stream<WorkoutSession?> watchActive() =>
      (select(workoutSessions)
            ..where((t) => t.finishedAt.isNull())
            ..orderBy([(t) => OrderingTerm.desc(t.startedAt)])
            ..limit(1))
          .watchSingleOrNull();

  /// Completed sessions, newest first.
  Stream<List<WorkoutSession>> watchHistory() =>
      (select(workoutSessions)
            ..where((t) => t.finishedAt.isNotNull())
            ..orderBy([(t) => OrderingTerm.desc(t.startedAt)]))
          .watch();

  Future<WorkoutSession?> getById(String id) =>
      (select(workoutSessions)..where((t) => t.id.equals(id)))
          .getSingleOrNull();

  Future<String> insertSession(WorkoutSessionsCompanion entry) =>
      into(workoutSessions).insert(entry).then((_) => entry.id.value);

  Future<bool> updateSession(WorkoutSessionsCompanion entry) =>
      update(workoutSessions).replace(entry);

  Future<int> deleteSession(String id) =>
      (delete(workoutSessions)..where((t) => t.id.equals(id))).go();
}
