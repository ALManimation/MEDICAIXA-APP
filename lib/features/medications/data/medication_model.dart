class MedicationModel {
  final String name;
  final String type;
  final String dosage;
  final String generic;
  final String? category;
  final String? instruction;

  const MedicationModel({
    required this.name,
    required this.type,
    required this.dosage,
    required this.generic,
    this.category,
    this.instruction,
  });

  factory MedicationModel.fromJson(Map<String, dynamic> json) {
    return MedicationModel(
      name: json['n'] as String? ?? '',
      type: json['t'] as String? ?? 'comprimido',
      dosage: json['d'] as String? ?? '',
      generic: json['g'] as String? ?? '',
      category: json['c'] as String?,
      instruction: json['i'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'n': name,
      't': type,
      'd': dosage,
      'g': generic,
      if (category != null) 'c': category,
      if (instruction != null) 'i': instruction,
    };
  }
}
