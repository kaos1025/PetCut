import '../models/pet_enums.dart';

// LifeStage 자동 계산 (대형견 25kg+ 기준)
class LifeStageCalculator {
  LifeStageCalculator._();

  static const double largeBreedThresholdKg = 25.0;

  static LifeStage calculate({
    required Species species,
    double? ageYears,
    double? weightKg,
  }) {
    if (ageYears == null) {
      return species == Species.cat ? LifeStage.adultCat : LifeStage.adult;
    }

    if (species == Species.cat) {
      if (ageYears < 1) return LifeStage.kitten;
      if (ageYears < 10) return LifeStage.adultCat;
      return LifeStage.seniorCat;
    }

    final isLarge = (weightKg ?? 0) >= largeBreedThresholdKg;
    if (isLarge) {
      if (ageYears < 2) return LifeStage.puppy;
      if (ageYears < 5) return LifeStage.adult;
      return LifeStage.senior;
    } else {
      if (ageYears < 1) return LifeStage.puppy;
      if (ageYears < 7) return LifeStage.adult;
      return LifeStage.senior;
    }
  }
}
