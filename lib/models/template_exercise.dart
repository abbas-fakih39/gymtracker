class TemplateExercise {
  final String id;
  final String templateId;
  final String exerciseId;
  final int position;
  final int defaultSets;

  const TemplateExercise({
    required this.id,
    required this.templateId,
    required this.exerciseId,
    required this.position,
    required this.defaultSets,
  });

  TemplateExercise copyWith({
    String? id,
    String? templateId,
    String? exerciseId,
    int? position,
    int? defaultSets,
  }) =>
      TemplateExercise(
        id: id ?? this.id,
        templateId: templateId ?? this.templateId,
        exerciseId: exerciseId ?? this.exerciseId,
        position: position ?? this.position,
        defaultSets: defaultSets ?? this.defaultSets,
      );

  factory TemplateExercise.fromJson(Map<String, dynamic> json) =>
      TemplateExercise(
        id: json['id'] as String,
        templateId: json['templateId'] as String,
        exerciseId: json['exerciseId'] as String,
        position: json['position'] as int,
        defaultSets: json['defaultSets'] as int,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'templateId': templateId,
        'exerciseId': exerciseId,
        'position': position,
        'defaultSets': defaultSets,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TemplateExercise &&
          id == other.id &&
          templateId == other.templateId &&
          exerciseId == other.exerciseId &&
          position == other.position &&
          defaultSets == other.defaultSets;

  @override
  int get hashCode =>
      Object.hash(id, templateId, exerciseId, position, defaultSets);

  @override
  String toString() =>
      'TemplateExercise(id: $id, templateId: $templateId, '
      'exerciseId: $exerciseId, position: $position, defaultSets: $defaultSets)';
}
