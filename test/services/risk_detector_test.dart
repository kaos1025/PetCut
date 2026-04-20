// test/services/risk_detector_test.dart
//
// PetCut — RiskDetector tests
// ----------------------------------------------------------------------------
// Verifies that RiskDetector correctly maps Gemini v0.4 analysis output to
// Observable Warning Signs riskKeys and evaluates escalation conditions.
// ----------------------------------------------------------------------------

import 'package:flutter_test/flutter_test.dart';
import 'package:petcut/constants/observable_warning_signs.dart';
import 'package:petcut/models/pet_profile.dart';
import 'package:petcut/models/petcut_analysis_result.dart';
import 'package:petcut/services/risk_detector.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

PetProfile _dogProfile() => PetProfile(
      name: 'Rex',
      species: Species.dog,
      weight: 15.0,
      weightUnit: WeightUnit.kg,
      ageYears: 3.0,
    );

PetProfile _catProfile() => PetProfile(
      name: 'Whiskers',
      species: Species.cat,
      weight: 4.0,
      weightUnit: WeightUnit.kg,
      ageYears: 3.0,
    );

PetcutAnalysisResult _buildResult({
  List<NutrientTotal> nutrientTotals = const [],
  List<MechanismConflict> mechanismConflicts = const [],
  List<FlaggedIngredient> flaggedIngredients = const [],
  List<PetcutProduct>? products,
}) {
  final effectiveProducts = products ??
      (flaggedIngredients.isEmpty
          ? const <PetcutProduct>[]
          : [
              PetcutProduct(
                productName: 'Test Product',
                productType: 'food',
                ingredientsRaw: '',
                keyNutrients: const [],
                flaggedIngredients: flaggedIngredients,
              ),
            ]);
  return PetcutAnalysisResult(
    products: effectiveProducts,
    comboAnalysis: PetcutComboAnalysis(
      nutrientTotals: nutrientTotals,
      mechanismConflicts: mechanismConflicts,
      exclusionRecommendations: const [],
    ),
    overallStatus: 'caution',
    overallSummary: '',
  );
}

FlaggedIngredient _flag(String ingredient, String reason) => FlaggedIngredient(
      ingredient: ingredient,
      reason: reason,
      severity: 'caution',
      detail: '',
    );

NutrientTotal _nutrient(String nutrient, String status) => NutrientTotal(
      nutrient: nutrient,
      totalDailyIntake: 0.0,
      unit: '',
      sources: const [],
      status: status,
    );

MechanismConflict _conflict(String conflictType) => MechanismConflict(
      conflictType: conflictType,
      involvedIngredients: const [],
      involvedProducts: const [],
      severity: 'caution',
      explanation: '',
    );

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('RiskDetector.detectRiskKeys', () {
    test('(a) empty result returns empty set', () {
      final result = _buildResult();
      final keys = RiskDetector.detectRiskKeys(
        geminiResult: result,
        pet: _dogProfile(),
      );
      expect(keys, isEmpty);
    });

    test('(b) d3_excess via nutrient_totals caution', () {
      final result = _buildResult(
        nutrientTotals: [_nutrient('vitamin_d3', 'caution')],
      );
      final keys = RiskDetector.detectRiskKeys(
        geminiResult: result,
        pet: _dogProfile(),
      );
      expect(keys, {'d3_excess'});
    });

    test('(c) d3_excess via nutrient_totals critical', () {
      final result = _buildResult(
        nutrientTotals: [_nutrient('vitamin_d3', 'critical')],
      );
      final keys = RiskDetector.detectRiskKeys(
        geminiResult: result,
        pet: _dogProfile(),
      );
      expect(keys, {'d3_excess'});
    });

    test('(d) d3 safe is not detected', () {
      final result = _buildResult(
        nutrientTotals: [_nutrient('vitamin_d3', 'safe')],
      );
      final keys = RiskDetector.detectRiskKeys(
        geminiResult: result,
        pet: _dogProfile(),
      );
      expect(keys, isEmpty);
    });

    test('(e) iron_excess via nutrient_totals warning', () {
      final result = _buildResult(
        nutrientTotals: [_nutrient('iron', 'warning')],
      );
      final keys = RiskDetector.detectRiskKeys(
        geminiResult: result,
        pet: _dogProfile(),
      );
      expect(keys, {'iron_excess'});
    });

    test('(f) iron caution alone is NOT detected', () {
      final result = _buildResult(
        nutrientTotals: [_nutrient('iron', 'caution')],
      );
      final keys = RiskDetector.detectRiskKeys(
        geminiResult: result,
        pet: _dogProfile(),
      );
      expect(keys, isEmpty);
    });

    test('(g) iron_excess via flagged_ingredients cumulative_risk', () {
      final result = _buildResult(
        flaggedIngredients: [_flag('Ferrous Sulfate', 'cumulative_risk')],
      );
      final keys = RiskDetector.detectRiskKeys(
        geminiResult: result,
        pet: _dogProfile(),
      );
      expect(keys, {'iron_excess'});
    });

    test('(h) iron ingredient with wrong reason is NOT detected', () {
      final result = _buildResult(
        flaggedIngredients: [_flag('iron', 'allergen')],
      );
      final keys = RiskDetector.detectRiskKeys(
        geminiResult: result,
        pet: _dogProfile(),
      );
      expect(keys, isEmpty);
    });

    test('(i) calcium_excess detected (filtering deferred to resolveForPet)',
        () {
      final result = _buildResult(
        nutrientTotals: [_nutrient('calcium', 'warning')],
      );
      final keys = RiskDetector.detectRiskKeys(
        geminiResult: result,
        pet: _dogProfile(),
      );
      expect(keys, {'calcium_excess_large_breed_puppy'});
    });

    test('(j) garlic_exposure via flagged_ingredients toxic_to_species', () {
      final result = _buildResult(
        flaggedIngredients: [_flag('Garlic Powder', 'toxic_to_species')],
      );
      final keys = RiskDetector.detectRiskKeys(
        geminiResult: result,
        pet: _dogProfile(),
      );
      expect(keys, {'garlic_exposure'});
    });

    test('(k) garlic_exposure via mechanism_conflicts hemolytic_risk', () {
      final result = _buildResult(
        mechanismConflicts: [_conflict('hemolytic_risk')],
      );
      final keys = RiskDetector.detectRiskKeys(
        geminiResult: result,
        pet: _dogProfile(),
      );
      expect(keys, {'garlic_exposure'});
    });

    test('(l) allium family (onion) is detected', () {
      final result = _buildResult(
        flaggedIngredients: [_flag('Onion Powder', 'allergen')],
      );
      final keys = RiskDetector.detectRiskKeys(
        geminiResult: result,
        pet: _dogProfile(),
      );
      expect(keys, {'garlic_exposure'});
    });

    test('(m) xylitol_exposure detected', () {
      final result = _buildResult(
        flaggedIngredients: [_flag('Xylitol', 'toxic_to_species')],
      );
      final keys = RiskDetector.detectRiskKeys(
        geminiResult: result,
        pet: _dogProfile(),
      );
      expect(keys, {'xylitol_exposure'});
    });

    test('(n) xylitol case-insensitive match', () {
      final result = _buildResult(
        flaggedIngredients: [_flag('XYLITOL', 'toxic_to_species')],
      );
      final keys = RiskDetector.detectRiskKeys(
        geminiResult: result,
        pet: _dogProfile(),
      );
      expect(keys, {'xylitol_exposure'});
    });

    test('(o-1) dedup: same risk from flagged + mechanism -> single entry', () {
      final result = _buildResult(
        flaggedIngredients: [_flag('Garlic', 'toxic_to_species')],
        mechanismConflicts: [_conflict('hemolytic_risk')],
      );
      final keys = RiskDetector.detectRiskKeys(
        geminiResult: result,
        pet: _dogProfile(),
      );
      expect(keys, {'garlic_exposure'});
      expect(keys.length, 1);
    });

    test('(o-2) dedup: same risk from multiple products -> single entry', () {
      final result = _buildResult(
        products: [
          PetcutProduct(
            productName: 'Product A',
            productType: 'food',
            ingredientsRaw: '',
            keyNutrients: const [],
            flaggedIngredients: [_flag('Garlic', 'toxic_to_species')],
          ),
          PetcutProduct(
            productName: 'Product B',
            productType: 'supplement',
            ingredientsRaw: '',
            keyNutrients: const [],
            flaggedIngredients: [_flag('Onion Powder', 'allergen')],
          ),
        ],
      );
      final keys = RiskDetector.detectRiskKeys(
        geminiResult: result,
        pet: _dogProfile(),
      );
      expect(keys, {'garlic_exposure'});
      expect(keys.length, 1);
    });

    test(
        '(o-3) dedup: iron from nutrient_totals + flagged -> single entry',
        () {
      final result = _buildResult(
        nutrientTotals: [_nutrient('iron', 'warning')],
        flaggedIngredients: [_flag('Ferrous Sulfate', 'cumulative_risk')],
      );
      final keys = RiskDetector.detectRiskKeys(
        geminiResult: result,
        pet: _dogProfile(),
      );
      expect(keys, {'iron_excess'});
      expect(keys.length, 1);
    });

    test('(p) multiple risks detected simultaneously', () {
      final result = _buildResult(
        nutrientTotals: [_nutrient('vitamin_d3', 'warning')],
        flaggedIngredients: [
          _flag('Garlic Powder', 'toxic_to_species'),
          _flag('Xylitol', 'toxic_to_species'),
        ],
      );
      final keys = RiskDetector.detectRiskKeys(
        geminiResult: result,
        pet: _dogProfile(),
      );
      expect(keys, {'d3_excess', 'garlic_exposure', 'xylitol_exposure'});
    });
  });

  group('RiskDetector.evaluateEffectiveTier', () {
    test('(q) d3_excess non-critical returns defaultTier (monitor)', () {
      final result = _buildResult(
        nutrientTotals: [_nutrient('vitamin_d3', 'warning')],
      );
      final tier = RiskDetector.evaluateEffectiveTier(
        riskKey: 'd3_excess',
        geminiResult: result,
        pet: _dogProfile(),
      );
      expect(tier, SeverityTier.monitor);
    });

    test('(r) d3_excess critical returns escalatedTier (urgent)', () {
      final result = _buildResult(
        nutrientTotals: [_nutrient('vitamin_d3', 'critical')],
      );
      final tier = RiskDetector.evaluateEffectiveTier(
        riskKey: 'd3_excess',
        geminiResult: result,
        pet: _dogProfile(),
      );
      expect(tier, SeverityTier.urgent);
    });

    test('(s) garlic_exposure for dog returns defaultTier (monitor)', () {
      final result = _buildResult(
        flaggedIngredients: [_flag('Garlic Powder', 'toxic_to_species')],
      );
      final tier = RiskDetector.evaluateEffectiveTier(
        riskKey: 'garlic_exposure',
        geminiResult: result,
        pet: _dogProfile(),
      );
      expect(tier, SeverityTier.monitor);
    });

    test('(t) garlic_exposure for cat returns escalatedTier (urgent)', () {
      final result = _buildResult(
        flaggedIngredients: [_flag('Garlic Powder', 'toxic_to_species')],
      );
      final tier = RiskDetector.evaluateEffectiveTier(
        riskKey: 'garlic_exposure',
        geminiResult: result,
        pet: _catProfile(),
      );
      expect(tier, SeverityTier.urgent);
    });

    test('(u) iron_excess always returns defaultTier (urgent)', () {
      final result = _buildResult(
        nutrientTotals: [_nutrient('iron', 'warning')],
      );
      final tier = RiskDetector.evaluateEffectiveTier(
        riskKey: 'iron_excess',
        geminiResult: result,
        pet: _dogProfile(),
      );
      expect(tier, SeverityTier.urgent);
    });

    test('(v) xylitol_exposure always returns defaultTier (urgent)', () {
      final result = _buildResult(
        flaggedIngredients: [_flag('Xylitol', 'toxic_to_species')],
      );
      final tier = RiskDetector.evaluateEffectiveTier(
        riskKey: 'xylitol_exposure',
        geminiResult: result,
        pet: _dogProfile(),
      );
      expect(tier, SeverityTier.urgent);
    });

    test(
        '(w) calcium_excess_large_breed_puppy always returns defaultTier '
        '(monitor)', () {
      final result = _buildResult(
        nutrientTotals: [_nutrient('calcium', 'warning')],
      );
      final tier = RiskDetector.evaluateEffectiveTier(
        riskKey: 'calcium_excess_large_breed_puppy',
        geminiResult: result,
        pet: _dogProfile(),
      );
      expect(tier, SeverityTier.monitor);
    });

    test('(x) unknown riskKey throws StateError', () {
      final result = _buildResult();
      expect(
        () => RiskDetector.evaluateEffectiveTier(
          riskKey: 'nonexistent_risk',
          geminiResult: result,
          pet: _dogProfile(),
        ),
        throwsStateError,
      );
    });
  });
}
