class WorkoutSet {
  final String id;
  final String sessionId;
  final String exerciseId;
  final int setNumber;
  final double weightKg;
  final int reps;
  final bool isPR;
  final DateTime completedAt;

  const WorkoutSet({
    required this.id,
    required this.sessionId,
    required this.exerciseId,
    required this.setNumber,
    required this.weightKg,
    required this.reps,
    required this.isPR,
    required this.completedAt,
  });

  WorkoutSet copyWith({
    String? id,
    String? sessionId,
    String? exerciseId,
    int? setNumber,
    double? weightKg,
    int? reps,
    bool? isPR,
    DateTime? completedAt,
  }) =>
      WorkoutSet(
        id: id ?? this.id,
        sessionId: sessionId ?? this.sessionId,
        exerciseId: exerciseId ?? this.exerciseId,
        setNumber: setNumber ?? this.setNumber,
        weightKg: weightKg ?? this.weightKg,
        reps: reps ?? this.reps,
        isPR: isPR ?? this.isPR,
        completedAt: completedAt ?? this.completedAt,
      );

  factory WorkoutSet.fromJson(Map<String, dynamic> json) => WorkoutSet(
        id: json['id'] as String,
        sessionId: json['sessionId'] as String,
        exerciseId: json['exerciseId'] as String,
        setNumber: json['setNumber'] as int,
        weightKg: (json['weightKg'] as num).toDouble(),
        reps: json['reps'] as int,
        isPR: json['isPR'] as bool,
        completedAt: DateTime.parse(json['completedAt'] as String),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'sessionId': sessionId,
        'exerciseId': exerciseId,
        'setNumber': setNumber,
        'weightKg': weightKg,
        'reps': reps,
        'isPR': isPR,
        'completedAt': completedAt.toIso8601String(),
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WorkoutSet &&
          id == other.id &&
          sessionId == other.sessionId &&
          exerciseId == other.exerciseId &&
          setNumber == other.setNumber &&
          weightKg == other.weightKg &&
          reps == other.reps &&
          isPR == other.isPR &&
          completedAt == other.completedAt;

  @override
  int get hashCode => Object.hash(
      id, sessionId, exerciseId, setNumber, weightKg, reps, isPR, completedAt);

  @override
  String toString() =>
      'WorkoutSet(id: $id, sessionId: $sessionId, exerciseId: $exerciseId, '
      'setNumber: $setNumber, weightKg: $weightKg, reps: $reps, '
      'isPR: $isPR, completedAt: $completedAt)';
}
