import '../models/pet_enums.dart';

// 체중별 독성 역치 상수 (v0.2 약사 검증)
// 출처: Merck Vet Manual, NRC 2006, ASPCA, AAFCO 2024
class ToxicityThresholds {
  ToxicityThresholds._();

  // ── Vitamin D3 (PetCut 핵심) ──
  static const double vitD3SafeMax = 0.005; // mg/kg BW/day
  static const double vitD3ChronicToxic = 0.01; // mg/kg BW/day (NRC)
  static const double vitD3AcuteToxic = 0.1; // mg/kg BW single dose
  static const double vitD3McgToIu = 40.0;
  static const double vitD3AafcoMin = 500; // IU/kg food
  static const double vitD3AafcoMax = 3000; // IU/kg food

  // ── Iron (이원 판단) ──
  static const double ironDietMin = 80; // mg/kg food DM
  static const double ironDietMax = 3000; // mg/kg food DM
  static const double ironAcuteToxic = 20; // mg/kg BW
  static const double ironAcuteLethal = 60; // mg/kg BW

  // ── Calcium (% of diet DM) ──
  static const double calciumDogAdultMax = 1.8;
  static const double calciumPuppyLargeMax = 1.5;
  static const double calciumPuppyLargeCaution = 1.2;
  static const double calciumCatMax = 1.0;
  static const double caPRatioMin = 1.0;
  static const double caPRatioMax = 2.0;

  // ── Zinc (mg/kg BW/day) ──
  static double zincSafeMax(Species s) => s == Species.dog ? 10.0 : 8.0;
  static double zincToxic(Species s) => s == Species.dog ? 25.0 : 20.0;

  // ── Copper (mg/kg BW/day) ──
  static const double copperSafeMax = 0.5;
  static const double copperToxic = 1.0;
  static const double copperSensitiveMax = 0.25;

  static const List<String> copperSensitiveBreeds = [
    'Bedlington Terrier',
    'West Highland White Terrier',
    'Doberman Pinscher',
    'Labrador Retriever',
    'Dalmatian',
    'Skye Terrier',
    'Cocker Spaniel',
  ];

  static bool isCopperSensitive(String? breed) {
    if (breed == null || breed.isEmpty) return false;
    final lower = breed.toLowerCase();
    return copperSensitiveBreeds.any((b) => lower.contains(b.toLowerCase()));
  }

  // ── 이진 독성 성분 ──
  static double garlicToxicDose(Species s) => s == Species.dog ? 15.0 : 5.0;
  static const double xylitolDogHypoglycemia = 0.1;
  static const double xylitolDogLiverFailure = 0.5;

  // ── 기전 충돌 성분 그룹 ──
  static const List<String> anticoagulants = [
    'fish oil',
    'omega-3',
    'omega 3',
    'ginkgo',
    'ginseng',
    'turmeric',
    'curcumin',
    'vitamin e',
    'garlic',
  ];
  static const List<String> thyroidDisruptors = [
    'kelp',
    'seaweed',
    'iodine',
    'bladderwrack',
  ];
  static const List<String> hemolytic = [
    'garlic',
    'garlic powder',
    'onion',
    'onion powder',
    'chives',
    'leek',
  ];
  static const List<String> hepatotoxicHerbs = [
    'comfrey',
    'pennyroyal',
    'kava',
    'germander',
    'black cohosh',
    'chaparral',
    'greater celandine',
  ];

  // ── 상태 판정 ──
  static String calculateStatus(double intake, double safeMax,
      {double? toxicThreshold}) {
    if (toxicThreshold != null && intake >= toxicThreshold) return 'critical';
    final ratio = safeMax > 0 ? intake / safeMax : 0.0;
    if (ratio >= 1.5) return 'warning';
    if (ratio >= 1.0) return 'caution';
    if (ratio >= 0.8) return 'monitor';
    return 'safe';
  }

  static String vitD3Status(double perKgIntake) {
    if (perKgIntake >= vitD3ChronicToxic) return 'critical';
    if (perKgIntake >= vitD3SafeMax) return 'warning';
    if (perKgIntake >= vitD3SafeMax * 0.8) return 'caution';
    return 'safe';
  }
}
