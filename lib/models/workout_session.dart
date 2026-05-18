const _sentinel = Object();

class WorkoutSession {
  final String id;
  final String? templateId;
  final String name;
  final DateTime startedAt;
  final DateTime? finishedAt;
  final String? notes;

  const WorkoutSession({
    required this.id,
    this.templateId,
    required this.name,
    required this.startedAt,
    this.finishedAt,
    this.notes,
  });

  WorkoutSession copyWith({
    String? id,
    Object? templateId = _sentinel,
    String? name,
    DateTime? startedAt,
    Object? finishedAt = _sentinel,
    Object? notes = _sentinel,
  }) =>
      WorkoutSession(
        id: id ?? this.id,
        templateId: identical(templateId, _sentinel)
            ? this.templateId
            : templateId as String?,
        name: name ?? this.name,
        startedAt: startedAt ?? this.startedAt,
        finishedAt: identical(finishedAt, _sentinel)
            ? this.finishedAt
            : finishedAt as DateTime?,
        notes: identical(notes, _sentinel) ? this.notes : notes as String?,
      );

  factory WorkoutSession.fromJson(Map<String, dynamic> json) => WorkoutSession(
        id: json['id'] as String,
        templateId: json['templateId'] as String?,
        name: json['name'] as String,
        startedAt: DateTime.parse(json['startedAt'] as String),
        finishedAt: json['finishedAt'] == null
            ? null
            : DateTime.parse(json['finishedAt'] as String),
        notes: json['notes'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'templateId': templateId,
        'name': name,
        'startedAt': startedAt.toIso8601String(),
        'finishedAt': finishedAt?.toIso8601String(),
        'notes': notes,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WorkoutSession &&
          id == other.id &&
          templateId == other.templateId &&
          name == other.name &&
          startedAt == other.startedAt &&
          finishedAt == other.finishedAt &&
          notes == other.notes;

  @override
  int get hashCode =>
      Object.hash(id, templateId, name, startedAt, finishedAt, notes);

  @override
  String toString() =>
      'WorkoutSession(id: $id, templateId: $templateId, name: $name, '
      'startedAt: $startedAt, finishedAt: $finishedAt, notes: $notes)';
}
