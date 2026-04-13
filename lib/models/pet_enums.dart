// 펫 프로필 관련 enum 정의
// pet_profile.dart와 life_stage_calculator.dart가 모두 참조

enum Species {
  dog,
  cat;

  String get displayName {
    switch (this) {
      case Species.dog:
        return 'Dog';
      case Species.cat:
        return 'Cat';
    }
  }
}

enum WeightUnit {
  kg,
  lbs;

  String get displayName {
    switch (this) {
      case WeightUnit.kg:
        return 'kg';
      case WeightUnit.lbs:
        return 'lbs';
    }
  }
}

enum LifeStage {
  puppy,
  adult,
  senior,
  kitten,
  adultCat,
  seniorCat;

  String get displayName {
    switch (this) {
      case LifeStage.puppy:
        return 'Puppy';
      case LifeStage.adult:
        return 'Adult';
      case LifeStage.senior:
        return 'Senior';
      case LifeStage.kitten:
        return 'Kitten';
      case LifeStage.adultCat:
        return 'Adult';
      case LifeStage.seniorCat:
        return 'Senior';
    }
  }

  static List<LifeStage> forSpecies(Species species) {
    switch (species) {
      case Species.dog:
        return [LifeStage.puppy, LifeStage.adult, LifeStage.senior];
      case Species.cat:
        return [LifeStage.kitten, LifeStage.adultCat, LifeStage.seniorCat];
    }
  }
}
