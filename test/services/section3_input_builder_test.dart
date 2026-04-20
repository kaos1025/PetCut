// test/services/section3_input_builder_test.dart
//
// PetCut — Section3InputBuilder tests
// ----------------------------------------------------------------------------
// Verifies §3 builder orchestration: integration of mechanism_conflicts
// with flagged_ingredients via ingredient alias matching, orphan flag
// routing to standalone_flags, display name mapping, and alert-presence
// semantics.
// ----------------------------------------------------------------------------

import 'package:flutter_test/flutter_test.dart';
import 'package:petcut/models/pet_profile.dart';
import 'package:petcut/models/petcut_analysis_result.dart';
import 'package:petcut/services/section3_input_builder.dart';

// ---------------------------------------------------------------------------
// Helpers — independent of other test files by design
// ---------------------------------------------------------------------------

PetProfile _dog() => PetProfile(
      name: 'Rex',
      species: Species.dog,
      weight: 15.0,
      weightUnit: WeightUnit.kg,
      lifeStage: LifeStage.adult,
    );

PetcutAnalysisResult _buildResult({
  List<MechanismConflict> mechanismConflicts = const [],
  List<PetcutProduct> products = const [],
}) =>
    PetcutAnalysisResult(
      products: products,
      comboAnalysis: PetcutComboAnalysis(
        nutrientTotals: const [],
        mechanismConflicts: mechanismConflicts,
        exclusionRecommendations: const [],
      ),
      overallStatus: 'caution',
      overallSummary: '',
    );

MechanismConflict _conflict({
  required String conflictType,
  String severity = 'caution',
  List<String> involvedIngredients = const [],
  List<String> involvedProducts = const [],
  String explanation = '',
}) =>
    MechanismConflict(
      conflictType: conflictType,
      involvedIngredients: involvedIngredients,
      involvedProducts: involvedProducts,
      severity: severity,
      explanation: explanation,
    );

PetcutProduct _product({
  String productName = 'Test Product',
  List<FlaggedIngredient> flaggedIngredients = const [],
}) =>
    PetcutProduct(
      productName: productName,
      productType: 'food',
      ingredientsRaw: '',
      keyNutrients: const [],
      flaggedIngredients: flaggedIngredients,
    );

FlaggedIngredient _flag({
  required String ingredient,
  required String reason,
  String severity = 'caution',
  String detail = '',
}) =>
    FlaggedIngredient(
      ingredient: ingredient,
      reason: reason,
      severity: severity,
      detail: detail,
    );

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('Section3InputBuilder.build — alert_groups integration', () {
    test('(a) mechanism_conflict alone yields empty related_flags', () {
      final result = Section3InputBuilder.build(
        geminiResult: _buildResult(
          mechanismConflicts: [_conflict(conflictType: 'hemolytic_risk')],
        ),
        pet: _dog(),
      );
      final groups = result['alert_groups'] as List;
      expect(groups.length, 1);
      expect((groups.first as Map)['related_flags'], isEmpty);
    });

    test('(b) hemolytic_risk absorbs Garlic toxic_to_species flag + dedup', () {
      final result = Section3InputBuilder.build(
        geminiResult: _buildResult(
          mechanismConflicts: [_conflict(conflictType: 'hemolytic_risk')],
          products: [
            _product(
              productName: 'Food A',
              flaggedIngredients: [
                _flag(
                  ingredient: 'Garlic Powder',
                  reason: 'toxic_to_species',
                ),
              ],
            ),
          ],
        ),
        pet: _dog(),
      );
      final groups = result['alert_groups'] as List;
      expect(groups.length, 1);
      final relatedFlags = (groups.first as Map)['related_flags'] as List;
      expect(relatedFlags.length, 1);
      // Dedup: matched flag must not also appear in standalone_flags.
      expect(
        result['standalone_flags'],
        isEmpty,
        reason: 'Matched flag should not appear in both related and standalone',
      );
    });

    test(
        '(c) multi-product: related_flags absorbs across products with '
        'correct product_name', () {
      final result = Section3InputBuilder.build(
        geminiResult: _buildResult(
          mechanismConflicts: [_conflict(conflictType: 'hemolytic_risk')],
          products: [
            _product(
              productName: 'Food A',
              flaggedIngredients: [
                _flag(ingredient: 'Garlic', reason: 'toxic_to_species'),
              ],
            ),
            _product(
              productName: 'Supplement B',
              flaggedIngredients: [
                _flag(ingredient: 'Onion', reason: 'toxic_to_species'),
              ],
            ),
          ],
        ),
        pet: _dog(),
      );
      final groups = result['alert_groups'] as List;
      expect(groups.length, 1);
      final relatedFlags =
          ((groups.first as Map)['related_flags'] as List).cast<Map>();
      expect(relatedFlags.length, 2);
      final mapping = <Object?, Object?>{
        for (final f in relatedFlags) f['ingredient']: f['product_name'],
      };
      expect(mapping['Garlic'], 'Food A');
      expect(mapping['Onion'], 'Supplement B');
    });

    test(
        '(d) involved_ingredients, involved_products, gemini_explanation '
        'passed through verbatim', () {
      final result = Section3InputBuilder.build(
        geminiResult: _buildResult(
          mechanismConflicts: [
            _conflict(
              conflictType: 'hemolytic_risk',
              involvedIngredients: const ['Garlic Powder', 'Onion Extract'],
              involvedProducts: const ['Food A', 'Supplement B'],
              explanation: 'Allium family oxidizes hemoglobin.',
            ),
          ],
        ),
        pet: _dog(),
      );
      final group = (result['alert_groups'] as List).first as Map;
      expect(
        group['involved_ingredients'],
        ['Garlic Powder', 'Onion Extract'],
      );
      expect(group['involved_products'], ['Food A', 'Supplement B']);
      expect(group['gemini_explanation'], 'Allium family oxidizes hemoglobin.');
    });
  });

  group('Section3InputBuilder.build — ingredient matching', () {
    test('(e) hemolytic_risk matches "Garlic Powder" + toxic_to_species', () {
      final result = Section3InputBuilder.build(
        geminiResult: _buildResult(
          mechanismConflicts: [_conflict(conflictType: 'hemolytic_risk')],
          products: [
            _product(flaggedIngredients: [
              _flag(ingredient: 'Garlic Powder', reason: 'toxic_to_species'),
            ]),
          ],
        ),
        pet: _dog(),
      );
      final relatedFlags = ((result['alert_groups'] as List).first
          as Map)['related_flags'] as List;
      expect(relatedFlags.length, 1);
      expect((relatedFlags.first as Map)['ingredient'], 'Garlic Powder');
    });

    test('(f) hemolytic_risk matches "Onion" + toxic_to_species', () {
      final result = Section3InputBuilder.build(
        geminiResult: _buildResult(
          mechanismConflicts: [_conflict(conflictType: 'hemolytic_risk')],
          products: [
            _product(flaggedIngredients: [
              _flag(ingredient: 'Onion', reason: 'toxic_to_species'),
            ]),
          ],
        ),
        pet: _dog(),
      );
      final relatedFlags = ((result['alert_groups'] as List).first
          as Map)['related_flags'] as List;
      expect(relatedFlags.length, 1);
      expect((relatedFlags.first as Map)['ingredient'], 'Onion');
    });

    test(
        '(g) hemolytic_risk does NOT match Garlic + cumulative_risk '
        '(reason mismatch)', () {
      final result = Section3InputBuilder.build(
        geminiResult: _buildResult(
          mechanismConflicts: [_conflict(conflictType: 'hemolytic_risk')],
          products: [
            _product(flaggedIngredients: [
              _flag(ingredient: 'Garlic', reason: 'cumulative_risk'),
            ]),
          ],
        ),
        pet: _dog(),
      );
      final relatedFlags = ((result['alert_groups'] as List).first
          as Map)['related_flags'] as List;
      expect(relatedFlags, isEmpty);
      final standalone = result['standalone_flags'] as List;
      expect(standalone.length, 1);
      expect((standalone.first as Map)['ingredient'], 'Garlic');
    });

    test('(h) anticoagulant_stacking matches "Fish Oil" + cumulative_risk', () {
      final result = Section3InputBuilder.build(
        geminiResult: _buildResult(
          mechanismConflicts: [
            _conflict(conflictType: 'anticoagulant_stacking'),
          ],
          products: [
            _product(flaggedIngredients: [
              _flag(ingredient: 'Fish Oil', reason: 'cumulative_risk'),
            ]),
          ],
        ),
        pet: _dog(),
      );
      final relatedFlags = ((result['alert_groups'] as List).first
          as Map)['related_flags'] as List;
      expect(relatedFlags.length, 1);
      expect((relatedFlags.first as Map)['ingredient'], 'Fish Oil');
    });

    test('(i) hepatotoxic_combo matches "Comfrey" + cumulative_risk', () {
      final result = Section3InputBuilder.build(
        geminiResult: _buildResult(
          mechanismConflicts: [_conflict(conflictType: 'hepatotoxic_combo')],
          products: [
            _product(flaggedIngredients: [
              _flag(ingredient: 'Comfrey', reason: 'cumulative_risk'),
            ]),
          ],
        ),
        pet: _dog(),
      );
      final relatedFlags = ((result['alert_groups'] as List).first
          as Map)['related_flags'] as List;
      expect(relatedFlags.length, 1);
      expect((relatedFlags.first as Map)['ingredient'], 'Comfrey');
    });

    test(
        '(j) unknown ingredient with cumulative_risk does not match '
        'hepatotoxic_combo', () {
      final result = Section3InputBuilder.build(
        geminiResult: _buildResult(
          mechanismConflicts: [_conflict(conflictType: 'hepatotoxic_combo')],
          products: [
            _product(flaggedIngredients: [
              _flag(ingredient: 'Mystery Herb', reason: 'cumulative_risk'),
            ]),
          ],
        ),
        pet: _dog(),
      );
      final relatedFlags = ((result['alert_groups'] as List).first
          as Map)['related_flags'] as List;
      expect(relatedFlags, isEmpty);
      final standalone = result['standalone_flags'] as List;
      expect(standalone.length, 1);
      expect((standalone.first as Map)['ingredient'], 'Mystery Herb');
    });
  });

  group('Section3InputBuilder.build — standalone_flags routing', () {
    test('(k) life_stage_mismatch flag routes to standalone_flags', () {
      final result = Section3InputBuilder.build(
        geminiResult: _buildResult(
          products: [
            _product(flaggedIngredients: [
              _flag(
                ingredient: 'Puppy Formula',
                reason: 'life_stage_mismatch',
              ),
            ]),
          ],
        ),
        pet: _dog(),
      );
      expect(result['alert_groups'], isEmpty);
      final standalone = result['standalone_flags'] as List;
      expect(standalone.length, 1);
      expect((standalone.first as Map)['reason'], 'life_stage_mismatch');
    });

    test('(l) allergen flag routes to standalone_flags', () {
      final result = Section3InputBuilder.build(
        geminiResult: _buildResult(
          products: [
            _product(flaggedIngredients: [
              _flag(ingredient: 'Chicken', reason: 'allergen'),
            ]),
          ],
        ),
        pet: _dog(),
      );
      final standalone = result['standalone_flags'] as List;
      expect(standalone.length, 1);
      expect((standalone.first as Map)['reason'], 'allergen');
    });

    test(
        '(m) mechanism-related flag without matching conflict routes to '
        'standalone', () {
      final result = Section3InputBuilder.build(
        geminiResult: _buildResult(
          // No mechanism_conflicts entry for hemolytic_risk.
          products: [
            _product(flaggedIngredients: [
              _flag(ingredient: 'Garlic', reason: 'toxic_to_species'),
            ]),
          ],
        ),
        pet: _dog(),
      );
      expect(result['alert_groups'], isEmpty);
      final standalone = result['standalone_flags'] as List;
      expect(standalone.length, 1);
      expect((standalone.first as Map)['ingredient'], 'Garlic');
    });
  });

  group('Section3InputBuilder.build — display_name mapping', () {
    test('(n) hemolytic_risk display_name uses the preset', () {
      final result = Section3InputBuilder.build(
        geminiResult: _buildResult(
          mechanismConflicts: [_conflict(conflictType: 'hemolytic_risk')],
        ),
        pet: _dog(),
      );
      final group = (result['alert_groups'] as List).first as Map;
      expect(
        group['display_name'],
        'Hemolytic Risk from Allium Ingredients',
      );
    });

    test('(o) unknown conflict_type falls back to snake_case Title Case', () {
      final result = Section3InputBuilder.build(
        geminiResult: _buildResult(
          mechanismConflicts: [
            _conflict(conflictType: 'unknown_mystery_interaction'),
          ],
        ),
        pet: _dog(),
      );
      final group = (result['alert_groups'] as List).first as Map;
      expect(group['display_name'], 'Unknown Mystery Interaction');
    });
  });

  group('Section3InputBuilder.build — edge cases', () {
    test('(p-1) has_any_alerts true when only alert_groups populated', () {
      final result = Section3InputBuilder.build(
        geminiResult: _buildResult(
          mechanismConflicts: [
            _conflict(conflictType: 'anticoagulant_stacking'),
          ],
          products: const [],
        ),
        pet: _dog(),
      );
      expect(result['has_any_alerts'], isTrue);
      expect((result['alert_groups'] as List).length, 1);
      expect(result['standalone_flags'], isEmpty);
    });

    test('(p-2) has_any_alerts true when only standalone_flags populated', () {
      final result = Section3InputBuilder.build(
        geminiResult: _buildResult(
          mechanismConflicts: const [],
          products: [
            _product(flaggedIngredients: [
              _flag(ingredient: 'Puppy Food', reason: 'life_stage_mismatch'),
            ]),
          ],
        ),
        pet: _dog(),
      );
      expect(result['has_any_alerts'], isTrue);
      expect(result['alert_groups'], isEmpty);
      expect((result['standalone_flags'] as List).length, 1);
    });

    test(
        '(q) completely empty input yields empty arrays and '
        'has_any_alerts false', () {
      final result = Section3InputBuilder.build(
        geminiResult: _buildResult(),
        pet: _dog(),
      );
      expect(result['alert_groups'], isEmpty);
      expect(result['standalone_flags'], isEmpty);
      expect(result['has_any_alerts'], isFalse);
    });
  });
}
