import 'dart:convert';

import 'package:drift/drift.dart';

class IntListConverter extends TypeConverter<List<int>, String> {
  const IntListConverter();

  @override
  List<int> fromSql(String fromDb) =>
      (jsonDecode(fromDb) as List).cast<int>();

  @override
  String toSql(List<int> value) => jsonEncode(value);
}

class WorkoutTemplates extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  // Stored as JSON array, e.g. "[0,2,4]" — 0=Mon … 6=Sun
  TextColumn get dayOfWeek =>
      text().map(const IntListConverter()).withDefault(const Constant('[]'))();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}
