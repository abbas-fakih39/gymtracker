class WorkoutTemplate {
  final String id;
  final String name;
  final List<int> dayOfWeek;
  final DateTime createdAt;

  const WorkoutTemplate({
    required this.id,
    required this.name,
    required this.dayOfWeek,
    required this.createdAt,
  });

  WorkoutTemplate copyWith({
    String? id,
    String? name,
    List<int>? dayOfWeek,
    DateTime? createdAt,
  }) =>
      WorkoutTemplate(
        id: id ?? this.id,
        name: name ?? this.name,
        dayOfWeek: dayOfWeek ?? this.dayOfWeek,
        createdAt: createdAt ?? this.createdAt,
      );

  factory WorkoutTemplate.fromJson(Map<String, dynamic> json) =>
      WorkoutTemplate(
        id: json['id'] as String,
        name: json['name'] as String,
        dayOfWeek: (json['dayOfWeek'] as List).cast<int>(),
        createdAt: DateTime.parse(json['createdAt'] as String),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'dayOfWeek': dayOfWeek,
        'createdAt': createdAt.toIso8601String(),
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WorkoutTemplate &&
          id == other.id &&
          name == other.name &&
          _listEquals(dayOfWeek, other.dayOfWeek) &&
          createdAt == other.createdAt;

  @override
  int get hashCode => Object.hash(id, name, Object.hashAll(dayOfWeek), createdAt);

  @override
  String toString() =>
      'WorkoutTemplate(id: $id, name: $name, dayOfWeek: $dayOfWeek, '
      'createdAt: $createdAt)';
}

bool _listEquals(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
