/// Represents a master manufacturing process step template.
class ProcessStep {
  final String id;
  final String name;
  final int stepOrder;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  const ProcessStep({
    required this.id,
    required this.name,
    required this.stepOrder,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ProcessStep.fromJson(Map<String, dynamic> json) {
    return ProcessStep(
      id: json['id'] as String,
      name: json['name'] as String,
      stepOrder: json['stepOrder'] as int,
      isActive: json['isActive'] as bool? ?? true,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'stepOrder': stepOrder,
      'isActive': isActive,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }
}
