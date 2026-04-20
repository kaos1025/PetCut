// lib/services/risk_detector.dart
//
// PetCut — Gemini JSON → riskKey Bridge
// ----------------------------------------------------------------------------
// Maps Gemini v0.4 analysis output to Observable Warning Signs risk keys,
// and evaluates escalation conditions.
//
// This service is the bridge between:
//   - Gemini's analytical output (PetcutAnalysisResult)
//   - Static clinical reference (ObservableWarningSigns)
//
// PRINCIPLE: This service translates, it does not re-analyze.
// Gemini's `status` and `reason` fields are trusted as source of truth.
// risk_detector only does:
//   1. Field name matching (vitamin_d3, iron, calcium)
//   2. Ingredient keyword scanning (garlic, xylitol)
//   3. Escalation condition evaluation (species == cat, status == critical)
//
// Sources of detection (per riskKey):
//   - d3_excess          ← nutrient_totals[vitamin_d3].status
//   - iron_excess        ← nutrient_totals[iron].status + flagged_ingredients
//   - calcium_excess_... ← nutrient_totals[calcium].status
//   - garlic_exposure    ← flagged_ingredients + mechanism_conflicts
//   - xylitol_exposure   ← flagged_ingredients
//
// Species/lifestage filtering is NOT done here. That is ObservableWarningSigns
// .resolveForPet()'s responsibility. This file only detects "is this risk
// logically present?", not "does it apply to this pet?".
//
// Version: v0.1
// Last updated: 2026-04-21
// ----------------------------------------------------------------------------

import '../constants/observable_warning_signs.dart';
import '../models/pet_enums.dart';
import '../models/pet_profile.dart';
import '../models/petcut_analysis_result.dart';

class RiskDetector {
  RiskDetector._();

  // --------------------------------------------------------------------------
  // Ingredient keyword aliases for ingredient-name-based detection.
  // Kept minimal to avoid false positives while covering common variants.
  // --------------------------------------------------------------------------
  static const List<String> _garlicAliases = [
    'garlic',
    'onion',
    'chives',
    'leek',
    'shallot',
    'allium',
  ];

  static const List<String> _xylitolAliases = [
    'xylitol',
  ];

  static const List<String> _ironAliases = [
    'iron',
    'ferrous',
  ];

  // --------------------------------------------------------------------------
  // Status values treated as "risk present" per Gemini v0.4 spec.
  // --------------------------------------------------------------------------
  static const Set<String> _elevatedStatuses = {
    'caution',
    'warning',
    'critical',
  };

  static const Set<String> _nutrientWarningStatuses = {
    'warning',
    'critical',
  };

  // --------------------------------------------------------------------------
  // Public API
  // --------------------------------------------------------------------------

  /// Detect risk keys present in the Gemini result.
  ///
  /// Returns a Set (dedup guaranteed). Species/lifestage filtering is the
  /// caller's responsibility (pass this to ObservableWarningSigns.resolveForPet).
  static Set<String> detectRiskKeys({
    required PetcutAnalysisResult geminiResult,
    required PetProfile pet,
  }) {
    final detected = <String>{};

    if (_detectD3Excess(geminiResult)) {
      detected.add('d3_excess');
    }
    if (_detectIronExcess(geminiResult)) {
      detected.add('iron_excess');
    }
    if (_detectCalciumExcess(geminiResult)) {
      detected.add('calcium_excess_large_breed_puppy');
    }
    if (_detectGarlicExposure(geminiResult)) {
      detected.add('garlic_exposure');
    }
    if (_detectXylitolExposure(geminiResult)) {
      detected.add('xylitol_exposure');
    }

    return detected;
  }

  /// Evaluate the effective severity tier for a detected risk.
  ///
  /// If the entry has no escalatedTier, returns defaultTier unchanged.
  /// If the escalation condition is met, returns escalatedTier.
  ///
  /// Throws StateError if riskKey is not registered in ObservableWarningSigns.
  static SeverityTier evaluateEffectiveTier({
    required String riskKey,
    required PetcutAnalysisResult geminiResult,
    required PetProfile pet,
  }) {
    final entry = ObservableWarningSigns.byKey(riskKey);
    if (entry == null) {
      throw StateError('Unknown riskKey: $riskKey');
    }

    if (entry.escalatedTier == null) {
      return entry.defaultTier;
    }

    final shouldEscalate = _evaluateEscalation(
      riskKey: riskKey,
      geminiResult: geminiResult,
      pet: pet,
    );

    return shouldEscalate ? entry.escalatedTier! : entry.defaultTier;
  }

  // --------------------------------------------------------------------------
  // Detection logic per riskKey
  // --------------------------------------------------------------------------

  /// D3 excess: nutrient_totals contains vitamin_d3 with elevated status.
  static bool _detectD3Excess(PetcutAnalysisResult result) {
    return result.comboAnalysis.nutrientTotals.any((n) =>
        n.nutrient == 'vitamin_d3' && _elevatedStatuses.contains(n.status));
  }

  /// Iron excess: either
  ///   (a) nutrient_totals entry for iron with warning/critical, OR
  ///   (b) any flagged_ingredient where name contains iron/ferrous
  ///       AND reason is cumulative_risk.
  ///
  /// Caution-level iron is NOT treated as excess (too noisy for acute-toxicity
  /// framing). Only warning+ triggers the urgent tier that Iron carries.
  static bool _detectIronExcess(PetcutAnalysisResult result) {
    final fromNutrientTotals = result.comboAnalysis.nutrientTotals.any((n) =>
        n.nutrient == 'iron' && _nutrientWarningStatuses.contains(n.status));
    if (fromNutrientTotals) return true;

    for (final product in result.products) {
      for (final flag in product.flaggedIngredients) {
        if (flag.reason != 'cumulative_risk') continue;
        final name = flag.ingredient.toLowerCase();
        if (_ironAliases.any(name.contains)) {
          return true;
        }
      }
    }
    return false;
  }

  /// Calcium excess: nutrient_totals entry for calcium with elevated status.
  /// Large-breed-puppy filtering happens in ObservableWarningSigns.resolveForPet.
  static bool _detectCalciumExcess(PetcutAnalysisResult result) {
    return result.comboAnalysis.nutrientTotals.any(
        (n) => n.nutrient == 'calcium' && _elevatedStatuses.contains(n.status));
  }

  /// Garlic exposure: either
  ///   (a) any flagged_ingredient where ingredient matches allium aliases, OR
  ///   (b) any mechanism_conflict with conflict_type == 'hemolytic_risk'.
  static bool _detectGarlicExposure(PetcutAnalysisResult result) {
    for (final product in result.products) {
      for (final flag in product.flaggedIngredients) {
        final name = flag.ingredient.toLowerCase();
        if (_garlicAliases.any(name.contains)) {
          return true;
        }
      }
    }

    final fromMechanism = result.comboAnalysis.mechanismConflicts
        .any((c) => c.conflictType == 'hemolytic_risk');
    return fromMechanism;
  }

  /// Xylitol exposure: any flagged_ingredient containing 'xylitol'.
  static bool _detectXylitolExposure(PetcutAnalysisResult result) {
    for (final product in result.products) {
      for (final flag in product.flaggedIngredients) {
        final name = flag.ingredient.toLowerCase();
        if (_xylitolAliases.any(name.contains)) {
          return true;
        }
      }
    }
    return false;
  }

  // --------------------------------------------------------------------------
  // Escalation evaluation
  // --------------------------------------------------------------------------

  static bool _evaluateEscalation({
    required String riskKey,
    required PetcutAnalysisResult geminiResult,
    required PetProfile pet,
  }) {
    switch (riskKey) {
      case 'd3_excess':
        // Escalate if vitamin_d3 status is 'critical'.
        return geminiResult.comboAnalysis.nutrientTotals
            .any((n) => n.nutrient == 'vitamin_d3' && n.status == 'critical');

      case 'garlic_exposure':
        // Escalate if pet is a cat.
        return pet.species == Species.cat;

      default:
        // Other riskKeys have no escalation defined.
        return false;
    }
  }
}
