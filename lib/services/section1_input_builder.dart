// lib/services/section1_input_builder.dart
//
// PetCut — §1 Pet Risk Profile Input Builder
// ----------------------------------------------------------------------------
// Assembles the Claude Sonnet prompt input JSON for §1 of the paid report.
//
// RESPONSIBILITY
// §1 is the opening section — pet identification and sensitivity context.
// It does NOT include analysis results. Its job is to establish WHO this
// report is about and WHY the report is tailored to this specific pet.
//
// This builder:
//   1. Formats pet profile (name, species, breed, life stage, weight)
//   2. Generates weight_display string combining kg and lbs
//   3. Derives sensitivity_flags from pet profile (copper-sensitive breeds,
//      large-breed puppy, etc.) — this is the ONLY section where Builder
//      adds clinical context beyond Gemini's output
//   4. Summarizes scan context (product count, product mix)
//
// Note: Sensitivity flags are Builder-derived because Gemini doesn't
// analyze pet sensitivity per se — it only analyzes ingredients/nutrients.
// This Builder handles the "who is this pet" layer.
//
// Version: v0.1
// Last updated: 2026-04-21
// ----------------------------------------------------------------------------

import '../models/pet_profile.dart';
import '../models/petcut_analysis_result.dart';

class Section1InputBuilder {
  Section1InputBuilder._();

  // --------------------------------------------------------------------------
  // Copper-sensitive breed list (source: toxicity_thresholds v0.2)
  // --------------------------------------------------------------------------
  static const List<String> _copperSensitiveBreeds = [
    'Bedlington Terrier',
    'West Highland White Terrier',
    'Doberman Pinscher',
    'Labrador Retriever',
    'Dalmatian',
    'Skye Terrier',
    'Cocker Spaniel',
  ];

  static const String _copperSensitiveDetail =
      'This breed is predisposed to copper accumulation in the liver, '
      'requiring stricter dietary copper limits than general dog '
      'guidelines.';

  static const String _largeBreedPuppyDetail =
      'Large-breed puppies (expected adult weight over 25 kg) cannot '
      'self-regulate calcium absorption the way adult dogs can. Chronic '
      'excess during growth plate development is linked to developmental '
      'orthopedic issues.';

  static const String _seniorPetDetail =
      'Senior pets have reduced organ reserve — particularly kidney and '
      'liver function — meaning tolerance for nutrient excess or toxicity '
      'may be narrower than in adult pets.';

  // --------------------------------------------------------------------------
  // Public API
  // --------------------------------------------------------------------------

  /// Assembles the §1 input block for the Claude Sonnet prompt.
  static Map<String, dynamic> build({
    required PetcutAnalysisResult geminiResult,
    required PetProfile pet,
  }) {
    final sensitivityFlags = _deriveSensitivityFlags(pet);
    final weightDisplay = _formatWeightDisplay(pet);
    final scanContext = _buildScanContext(geminiResult);

    return <String, dynamic>{
      'section': 'pet_risk_profile',
      'pet': <String, dynamic>{
        'name': pet.name,
        'species': _speciesToString(pet.species),
        'breed': pet.breed,
        'life_stage': _lifeStageToString(pet.lifeStage),
        'weight_kg': pet.weightKg,
        'weight_display': weightDisplay,
      },
      'sensitivity_flags': sensitivityFlags,
      'scan_context': scanContext,
    };
  }

  // --------------------------------------------------------------------------
  // Sensitivity flag derivation
  // --------------------------------------------------------------------------

  /// Derives sensitivity flags from pet profile. Empty array if no
  /// sensitivities apply.
  static List<Map<String, dynamic>> _deriveSensitivityFlags(PetProfile pet) {
    final flags = <Map<String, dynamic>>[];

    // Copper-sensitive breed (dogs only)
    if (pet.species == Species.dog &&
        pet.breed != null &&
        _copperSensitiveBreeds.contains(pet.breed)) {
      flags.add(<String, dynamic>{
        'flag_key': 'copper_sensitive_breed',
        'display_label': 'Copper-sensitive breed',
        'detail': _copperSensitiveDetail,
      });
    }

    // Large-breed puppy
    if (pet.species == Species.dog &&
        pet.lifeStage == LifeStage.puppy &&
        pet.weightKg >= 25.0) {
      flags.add(<String, dynamic>{
        'flag_key': 'large_breed_puppy',
        'display_label': 'Large-breed puppy',
        'detail': _largeBreedPuppyDetail,
      });
    }

    // Senior pet (both species)
    if (pet.lifeStage == LifeStage.senior ||
        pet.lifeStage == LifeStage.seniorCat) {
      flags.add(<String, dynamic>{
        'flag_key': 'senior_pet',
        'display_label': 'Senior pet',
        'detail': _seniorPetDetail,
      });
    }

    return flags;
  }

  // --------------------------------------------------------------------------
  // Weight display formatting
  // --------------------------------------------------------------------------

  /// Formats weight as "X kg (Y lbs)" or "Y lbs (X kg)" based on user's
  /// original unit. Rounds to 1 decimal for kg and nearest integer for lbs.
  static String _formatWeightDisplay(PetProfile pet) {
    final kg = pet.weightKg;
    final lbs = kg * 2.20462;

    final kgRounded = _roundTo1Decimal(kg);
    final lbsRounded = lbs.round();

    if (pet.weightUnit == WeightUnit.lbs) {
      return '$lbsRounded lbs (${_formatKg(kgRounded)} kg)';
    } else {
      return '${_formatKg(kgRounded)} kg ($lbsRounded lbs)';
    }
  }

  /// Formats kg value removing trailing .0 (e.g. "30" instead of "30.0").
  static String _formatKg(double kg) {
    if (kg == kg.roundToDouble()) {
      return kg.toInt().toString();
    }
    return kg.toStringAsFixed(1);
  }

  static double _roundTo1Decimal(double value) {
    return (value * 10).roundToDouble() / 10;
  }

  // --------------------------------------------------------------------------
  // Scan context summary
  // --------------------------------------------------------------------------

  static Map<String, dynamic> _buildScanContext(PetcutAnalysisResult result) {
    final products = result.products;
    final count = products.length;

    var foodCount = 0;
    var supplementCount = 0;
    var treatCount = 0;

    for (final product in products) {
      switch (product.productType) {
        case 'food':
          foodCount++;
          break;
        case 'supplement':
          supplementCount++;
          break;
        case 'treat':
          treatCount++;
          break;
      }
    }

    final summary = _formatProductMixSummary(
      foodCount: foodCount,
      supplementCount: supplementCount,
      treatCount: treatCount,
    );

    return <String, dynamic>{
      'products_count': count,
      'products_summary': summary,
    };
  }

  /// Formats product mix as "1 food + 1 supplement", "2 supplements", etc.
  static String _formatProductMixSummary({
    required int foodCount,
    required int supplementCount,
    required int treatCount,
  }) {
    final parts = <String>[];
    if (foodCount > 0) {
      parts.add('$foodCount ${foodCount == 1 ? "food" : "foods"}');
    }
    if (supplementCount > 0) {
      parts.add(
          '$supplementCount ${supplementCount == 1 ? "supplement" : "supplements"}');
    }
    if (treatCount > 0) {
      parts.add('$treatCount ${treatCount == 1 ? "treat" : "treats"}');
    }

    if (parts.isEmpty) return 'no products identified';
    return parts.join(' + ');
  }

  // --------------------------------------------------------------------------
  // Enum → string helpers
  // --------------------------------------------------------------------------

  static String _speciesToString(Species species) {
    switch (species) {
      case Species.dog:
        return 'dog';
      case Species.cat:
        return 'cat';
    }
  }

  static String _lifeStageToString(LifeStage lifeStage) {
    switch (lifeStage) {
      case LifeStage.puppy:
        return 'puppy';
      case LifeStage.adult:
        return 'adult';
      case LifeStage.senior:
        return 'senior';
      case LifeStage.kitten:
        return 'kitten';
      case LifeStage.adultCat:
        return 'adult';
      case LifeStage.seniorCat:
        return 'senior';
    }
  }
}
