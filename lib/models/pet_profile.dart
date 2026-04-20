import 'package:uuid/uuid.dart';
import 'pet_enums.dart';
import '../utils/life_stage_calculator.dart';

// Re-export enums for convenience
export 'pet_enums.dart';

// 펫 프로필 모델
class PetProfile {
  final String id;
  final String name;
  final Species species;
  final String? breed;
  final double weight;
  final WeightUnit weightUnit;
  final double? ageYears;
  LifeStage lifeStage;
  final DateTime createdAt;
  DateTime updatedAt;

  PetProfile({
    String? id,
    required this.name,
    required this.species,
    this.breed,
    required this.weight,
    required this.weightUnit,
    this.ageYears,
    LifeStage? lifeStage,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now(),
        lifeStage = lifeStage ??
            LifeStageCalculator.calculate(
              species: species,
              ageYears: ageYears,
              weightKg:
                  weightUnit == WeightUnit.lbs ? weight * 0.453592 : weight,
            );

  double get weightKg {
    switch (weightUnit) {
      case WeightUnit.kg:
        return weight;
      case WeightUnit.lbs:
        return weight * 0.453592;
    }
  }

  bool get isLargeBreed => species == Species.dog && weightKg >= 25;

  String toPromptText() {
    final buf = StringBuffer()
      ..writeln('Pet Profile:')
      ..writeln('- Species: ${species.displayName}');
    if (breed != null && breed!.isNotEmpty) {
      buf.writeln('- Breed: $breed');
    }
    buf
      ..writeln(
          '- Weight: ${weight.toStringAsFixed(1)} ${weightUnit.displayName} '
          '(${weightKg.toStringAsFixed(1)} kg)')
      ..writeln('- Age: ${ageYears?.toStringAsFixed(1) ?? "unknown"} years')
      ..writeln('- Life Stage: ${lifeStage.displayName}');
    if (isLargeBreed) {
      buf.writeln(
          '- Note: Large breed (>25kg) — apply stricter calcium limits');
    }
    return buf.toString();
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'species': species.name,
        'breed': breed,
        'weight': weight,
        'weight_unit': weightUnit.name,
        'age_years': ageYears,
        'life_stage': lifeStage.name,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  factory PetProfile.fromJson(Map<String, dynamic> json) => PetProfile(
        id: json['id'] as String?,
        name: json['name'] as String? ?? '',
        species: Species.values.byName(json['species'] as String? ?? 'dog'),
        breed: json['breed'] as String?,
        weight: (json['weight'] as num?)?.toDouble() ?? 0.0,
        weightUnit:
            WeightUnit.values.byName(json['weight_unit'] as String? ?? 'kg'),
        ageYears: (json['age_years'] as num?)?.toDouble(),
        lifeStage: json['life_stage'] != null
            ? LifeStage.values.byName(json['life_stage'] as String)
            : null,
        createdAt: json['created_at'] != null
            ? DateTime.parse(json['created_at'] as String)
            : null,
        updatedAt: json['updated_at'] != null
            ? DateTime.parse(json['updated_at'] as String)
            : null,
      );

  PetProfile copyWith({
    String? name,
    Species? species,
    String? breed,
    double? weight,
    WeightUnit? weightUnit,
    double? ageYears,
    LifeStage? lifeStage,
  }) =>
      PetProfile(
        id: id,
        name: name ?? this.name,
        species: species ?? this.species,
        breed: breed ?? this.breed,
        weight: weight ?? this.weight,
        weightUnit: weightUnit ?? this.weightUnit,
        ageYears: ageYears ?? this.ageYears,
        lifeStage: lifeStage ?? this.lifeStage,
        createdAt: createdAt,
        updatedAt: DateTime.now(),
      );
}
