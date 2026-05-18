class Exercise {
  final String id;
  final String name;
  final String muscleGroup;
  final String category;
  final bool isCustom;

  const Exercise({
    required this.id,
    required this.name,
    required this.muscleGroup,
    required this.category,
    required this.isCustom,
  });

  Exercise copyWith({
    String? id,
    String? name,
    String? muscleGroup,
    String? category,
    bool? isCustom,
  }) =>
      Exercise(
        id: id ?? this.id,
        name: name ?? this.name,
        muscleGroup: muscleGroup ?? this.muscleGroup,
        category: category ?? this.category,
        isCustom: isCustom ?? this.isCustom,
      );

  factory Exercise.fromJson(Map<String, dynamic> json) => Exercise(
        id: json['id'] as String,
        name: json['name'] as String,
        muscleGroup: json['muscleGroup'] as String,
        category: json['category'] as String,
        isCustom: json['isCustom'] as bool,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'muscleGroup': muscleGroup,
        'category': category,
        'isCustom': isCustom,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Exercise &&
          id == other.id &&
          name == other.name &&
          muscleGroup == other.muscleGroup &&
          category == other.category &&
          isCustom == other.isCustom;

  @override
  int get hashCode =>
      Object.hash(id, name, muscleGroup, category, isCustom);

  @override
  String toString() =>
      'Exercise(id: $id, name: $name, muscleGroup: $muscleGroup, '
      'category: $category, isCustom: $isCustom)';
}
