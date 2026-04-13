import 'dart:math';
import '../models/pet_enums.dart';

// RER/MER 기반 일일 급여량 추정 (NRC 2006, WSAVA)
class DailyIntakeCalculator {
  DailyIntakeCalculator._();

  static const double kibbleKcalPerKg = 3500.0;

  static double rer(double weightKg) {
    if (weightKg <= 0) return 0.0;
    return 70.0 * pow(weightKg, 0.75).toDouble();
  }

  static double merMultiplier(LifeStage stage) {
    switch (stage) {
      case LifeStage.puppy:
        return 2.0; // v2: <4mo → 3.0
      case LifeStage.adult:
        return 1.6;
      case LifeStage.senior:
        return 1.2;
      case LifeStage.kitten:
        return 2.5;
      case LifeStage.adultCat:
        return 1.4;
      case LifeStage.seniorCat:
        return 1.1;
    }
  }

  static double mer(double weightKg, LifeStage stage) {
    return rer(weightKg) * merMultiplier(stage);
  }

  static double dailyKibbleKg(double weightKg, LifeStage stage) {
    return mer(weightKg, stage) / kibbleKcalPerKg;
  }

  static double dailyKibbleGrams(double weightKg, LifeStage stage) {
    return dailyKibbleKg(weightKg, stage) * 1000.0;
  }

  static double perKgFoodToDaily(
      double amountPerKgFood, double weightKg, LifeStage stage) {
    return amountPerKgFood * dailyKibbleKg(weightKg, stage);
  }

  static double percentDietToDaily(
      double percentOfDiet, double weightKg, LifeStage stage) {
    return (percentOfDiet / 100.0) * dailyKibbleGrams(weightKg, stage);
  }
}
