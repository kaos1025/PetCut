// test/services/section4_input_builder_test.dart
//
// PetCut — Section4InputBuilder tests
// ----------------------------------------------------------------------------
// Verifies that the §4 input builder correctly orchestrates RiskDetector,
// ObservableWarningSigns, and ObservationExpression into the Claude Sonnet
// prompt input Map, including species-specific filtering and tier
// escalation.
// ----------------------------------------------------------------------------

import 'package:flutter_test/flutter_test.dart';
import 'package:petcut/constants/observable_warning_signs.dart';
import 'package:petcut/models/pet_profile.dart';
import 'package:petcut/models/petcut_analysis_result.dart';
import 'package:petcut/services/section4_input_builder.dart';
import 'package:petcut/utils/observation_expression.dart';

// ---------------------------------------------------------------------------
// Helpers — independent of risk_detector_test.dart by design
// ---------------------------------------------------------------------------

PetProfile _dog() => PetProfile(
      name: 'Rex',
      species: Species.dog,
      weight: 15.0,
      weightUnit: WeightUnit.kg,
      lifeStage: LifeStage.adult,
    );

PetProfile _cat() => PetProfile(
      name: 'Whiskers',
      species: Species.cat,
      weight: 4.0,
      weightUnit: WeightUnit.kg,
      lifeStage: LifeStage.adultCat,
    );

PetProfile _largeBreedPuppy() => PetProfile(
      name: 'Max',
      species: Species.dog,
      weight: 30.0,
      weightUnit: WeightUnit.kg,
      lifeStage: LifeStage.puppy,
    );

PetcutAnalysisResult _buildResult({
  List<NutrientTotal> nutrientTotals = const [],
  List<MechanismConflict> mechanismConflicts = const [],
  List<FlaggedIngredient> flaggedIngredients = const [],
}) {
  final products = flaggedIngredients.isEmpty
      ? const <PetcutProduct>[]
      : [
          PetcutProduct(
            productName: 'Test Product',
            productType: 'food',
            ingredientsRaw: '',
            keyNutrients: const [],
            flaggedIngredients: flaggedIngredients,
          ),
        ];
  return PetcutAnalysisResult(
    products: products,
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

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('Section4InputBuilder.build — basic structure', () {
    test('(a) no detections -> has_any_risks false and empty detected_risks',
        () {
      final result = Section4InputBuilder.build(
        geminiResult: _buildResult(),
        pet: _dog(),
      );
      expect(result['has_any_risks'], isFalse);
      expect(result['detected_risks'], isEmpty);
    });

    test('(b) single risk detection yields one entry in detected_risks', () {
      final result = Section4InputBuilder.build(
        geminiResult: _buildResult(
          flaggedIngredients: [_flag('Xylitol', 'toxic_to_species')],
        ),
        pet: _dog(),
      );
      expect(result['has_any_risks'], isTrue);
      expect((result['detected_risks'] as List).length, 1);
    });

    test('(c) multiple risks detected (order-agnostic)', () {
      final result = Section4InputBuilder.build(
        geminiResult: _buildResult(
          nutrientTotals: [_nutrient('vitamin_d3', 'warning')],
          flaggedIngredients: [
            _flag('Garlic Powder', 'toxic_to_species'),
            _flag('Xylitol', 'toxic_to_species'),
          ],
        ),
        pet: _dog(),
      );
      final risks = (result['detected_risks'] as List).cast<Map>();
      final keys = risks.map((r) => r['risk_key']).toSet();
      expect(keys, {'d3_excess', 'garlic_exposure', 'xylitol_exposure'});
    });

    test('(d) top-level keys are exactly the four required keys', () {
      final result = Section4InputBuilder.build(
        geminiResult: _buildResult(),
        pet: _dog(),
      );
      expect(
        result.keys.toSet(),
        {'section', 'pet', 'detected_risks', 'has_any_risks'},
      );
      expect(result['section'], 'observable_warning_signs');
    });

    test('(e) pet block exposes exactly name/species/life_stage/weight_kg', () {
      final result = Section4InputBuilder.build(
        geminiResult: _buildResult(),
        pet: _dog(),
      );
      final pet = result['pet'] as Map<String, dynamic>;
      expect(
        pet.keys.toSet(),
        {'name', 'species', 'life_stage', 'weight_kg'},
      );
      expect(pet['name'], 'Rex');
      expect(pet['species'], 'dog');
      expect(pet['life_stage'], 'adult');
      expect(pet['weight_kg'], 15.0);
    });
  });

  group('Section4InputBuilder.build — per-risk field integrity', () {
    test('(f) early_signs matches the registered entry verbatim', () {
      final result = Section4InputBuilder.build(
        geminiResult: _buildResult(
          nutrientTotals: [_nutrient('vitamin_d3', 'warning')],
        ),
        pet: _dog(),
      );
      final risk = (result['detected_risks'] as List).first as Map;
      final entry = ObservableWarningSigns.byKey('d3_excess')!;
      expect(risk['early_signs'], entry.earlySigns);
    });

    test('(g) escalate_signs matches the registered entry verbatim', () {
      final result = Section4InputBuilder.build(
        geminiResult: _buildResult(
          nutrientTotals: [_nutrient('vitamin_d3', 'warning')],
        ),
        pet: _dog(),
      );
      final risk = (result['detected_risks'] as List).first as Map;
      final entry = ObservableWarningSigns.byKey('d3_excess')!;
      expect(risk['escalate_signs'], entry.escalateSigns);
    });

    test('(h) observation_expression matches fromHours(observation_hours)', () {
      // Trigger multiple risks with different observation windows.
      final result = Section4InputBuilder.build(
        geminiResult: _buildResult(
          nutrientTotals: [
            _nutrient('vitamin_d3', 'warning'),
            _nutrient('iron', 'warning'),
          ],
          flaggedIngredients: [_flag('Xylitol', 'toxic_to_species')],
        ),
        pet: _dog(),
      );
      final risks = (result['detected_risks'] as List).cast<Map>();
      expect(risks, isNotEmpty);
      for (final risk in risks) {
        final hours = risk['observation_hours'] as int;
        expect(
          risk['observation_expression'],
          ObservationExpression.fromHours(hours),
          reason: '${risk['risk_key']} expression must match fromHours($hours)',
        );
      }
    });

    test('(i) default_tier serializes the registered entry default tier', () {
      final result = Section4InputBuilder.build(
        geminiResult: _buildResult(
          nutrientTotals: [_nutrient('vitamin_d3', 'warning')],
        ),
        pet: _dog(),
      );
      final risk = (result['detected_risks'] as List).first as Map;
      // d3_excess.defaultTier = SeverityTier.monitor.
      expect(risk['default_tier'], 'monitor');
    });
  });

  group('Section4InputBuilder.build — effective_tier evaluation', () {
    test('(j) D3 critical escalates effective_tier to urgent', () {
      final result = Section4InputBuilder.build(
        geminiResult: _buildResult(
          nutrientTotals: [_nutrient('vitamin_d3', 'critical')],
        ),
        pet: _dog(),
      );
      final risk = (result['detected_risks'] as List).first as Map;
      expect(risk['risk_key'], 'd3_excess');
      expect(risk['effective_tier'], 'urgent');
    });

    test('(k) D3 non-critical keeps effective_tier at monitor', () {
      final result = Section4InputBuilder.build(
        geminiResult: _buildResult(
          nutrientTotals: [_nutrient('vitamin_d3', 'warning')],
        ),
        pet: _dog(),
      );
      final risk = (result['detected_risks'] as List).first as Map;
      expect(risk['effective_tier'], 'monitor');
    });

    test('(l) garlic_exposure for dog keeps effective_tier at monitor', () {
      final result = Section4InputBuilder.build(
        geminiResult: _buildResult(
          flaggedIngredients: [_flag('Garlic Powder', 'toxic_to_species')],
        ),
        pet: _dog(),
      );
      final risk = (result['detected_risks'] as List).first as Map;
      expect(risk['risk_key'], 'garlic_exposure');
      expect(risk['effective_tier'], 'monitor');
    });

    test('(m) garlic_exposure for cat escalates effective_tier to urgent', () {
      final result = Section4InputBuilder.build(
        geminiResult: _buildResult(
          flaggedIngredients: [_flag('Garlic Powder', 'toxic_to_species')],
        ),
        pet: _cat(),
      );
      final risk = (result['detected_risks'] as List).first as Map;
      expect(risk['risk_key'], 'garlic_exposure');
      expect(risk['effective_tier'], 'urgent');
    });

    test('(n) iron_excess always has effective_tier urgent (no escalation)',
        () {
      final result = Section4InputBuilder.build(
        geminiResult: _buildResult(
          nutrientTotals: [_nutrient('iron', 'warning')],
        ),
        pet: _dog(),
      );
      final risk = (result['detected_risks'] as List).first as Map;
      expect(risk['risk_key'], 'iron_excess');
      expect(risk['effective_tier'], 'urgent');
    });
  });

  group('Section4InputBuilder.build — species_specific_note filtering', () {
    test('(o) garlic_exposure for dog suppresses species_specific_note', () {
      final result = Section4InputBuilder.build(
        geminiResult: _buildResult(
          flaggedIngredients: [_flag('Garlic Powder', 'toxic_to_species')],
        ),
        pet: _dog(),
      );
      final risk = (result['detected_risks'] as List).first as Map;
      expect(risk['species_specific_note'], isNull);
    });

    test('(p) garlic_exposure for cat exposes the entry species_specific_note',
        () {
      final result = Section4InputBuilder.build(
        geminiResult: _buildResult(
          flaggedIngredients: [_flag('Garlic Powder', 'toxic_to_species')],
        ),
        pet: _cat(),
      );
      final risk = (result['detected_risks'] as List).first as Map;
      final entry = ObservableWarningSigns.byKey('garlic_exposure')!;
      expect(risk['species_specific_note'], isNotNull);
      expect(risk['species_specific_note'], entry.speciesSpecificNote);
    });

    test('(q) non-garlic entries always have null species_specific_note', () {
      // Large-breed puppy triggers all 4 non-garlic entries in one pass.
      final result = Section4InputBuilder.build(
        geminiResult: _buildResult(
          nutrientTotals: [
            _nutrient('vitamin_d3', 'warning'),
            _nutrient('iron', 'warning'),
            _nutrient('calcium', 'warning'),
          ],
          flaggedIngredients: [_flag('Xylitol', 'toxic_to_species')],
        ),
        pet: _largeBreedPuppy(),
      );
      final risks = (result['detected_risks'] as List).cast<Map>();
      final nonGarlic =
          risks.where((r) => r['risk_key'] != 'garlic_exposure').toList();
      // Sanity: we really did trigger all four non-garlic entries.
      expect(nonGarlic.map((r) => r['risk_key']).toSet(), {
        'd3_excess',
        'iron_excess',
        'calcium_excess_large_breed_puppy',
        'xylitol_exposure',
      });
      for (final r in nonGarlic) {
        expect(
          r['species_specific_note'],
          isNull,
          reason: '${r['risk_key']} must have null species_specific_note',
        );
      }
    });
  });

  group('Section4InputBuilder.build — edge cases', () {
    test('(r) life_stage adultCat serializes to "adult"', () {
      final result = Section4InputBuilder.build(
        geminiResult: _buildResult(),
        pet: _cat(),
      );
      expect((result['pet'] as Map)['life_stage'], 'adult');
    });

    test('(s) species serializes to "cat"/"dog" lowercase strings', () {
      final resultCat = Section4InputBuilder.build(
        geminiResult: _buildResult(),
        pet: _cat(),
      );
      expect((resultCat['pet'] as Map)['species'], 'cat');

      final resultDog = Section4InputBuilder.build(
        geminiResult: _buildResult(),
        pet: _dog(),
      );
      expect((resultDog['pet'] as Map)['species'], 'dog');
    });

    test('(t) calcium entry is included only for large-breed puppy', () {
      // Large-breed puppy: calcium entry included.
      final resultPuppy = Section4InputBuilder.build(
        geminiResult: _buildResult(
          nutrientTotals: [_nutrient('calcium', 'warning')],
        ),
        pet: _largeBreedPuppy(),
      );
      final keysPuppy = (resultPuppy['detected_risks'] as List)
          .map((r) => (r as Map)['risk_key'])
          .toSet();
      expect(keysPuppy, contains('calcium_excess_large_breed_puppy'));

      // Adult dog with same Gemini output: calcium entry excluded by
      // ObservableWarningSigns.resolveForPet scope filtering.
      final resultAdult = Section4InputBuilder.build(
        geminiResult: _buildResult(
          nutrientTotals: [_nutrient('calcium', 'warning')],
        ),
        pet: _dog(),
      );
      final keysAdult = (resultAdult['detected_risks'] as List)
          .map((r) => (r as Map)['risk_key'])
          .toSet();
      expect(
        keysAdult,
        isNot(contains('calcium_excess_large_breed_puppy')),
      );
    });
  });
}
