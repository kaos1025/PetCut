// test/services/section5_input_builder_test.dart
//
// PetCut — Section5InputBuilder tests
// ----------------------------------------------------------------------------
// Verifies that the §5 input builder correctly determines the overall
// triage tier, maps exclusion_recommendations into triage-classified
// action cards, renders action verbs, and emits the legal-reviewed
// prescription medication note.
// ----------------------------------------------------------------------------

import 'package:flutter_test/flutter_test.dart';
import 'package:petcut/models/pet_profile.dart';
import 'package:petcut/models/petcut_analysis_result.dart';
import 'package:petcut/services/section5_input_builder.dart';

// ---------------------------------------------------------------------------
// Factory helpers — independent per-test fixtures
// ---------------------------------------------------------------------------

PetProfile _dog({
  String breed = 'Mixed',
  LifeStage lifeStage = LifeStage.adult,
}) =>
    PetProfile(
      name: 'Buddy',
      species: Species.dog,
      breed: breed,
      weight: 15.0,
      weightUnit: WeightUnit.kg,
      lifeStage: lifeStage,
    );

// Constructs a PetcutAnalysisResult directly via const constructor, which
// bypasses PetcutAnalysisResult.fromJson's _enforceOverallStatus() so the
// overallStatus stays exactly as provided by the test scenario.
PetcutAnalysisResult _buildResult({
  List<MechanismConflict> mechanismConflicts = const [],
  List<NutrientTotal> nutrientTotals = const [],
  List<ExclusionRecommendation> exclusions = const [],
  List<PetcutProduct> products = const [],
  String overallStatus = 'caution',
}) =>
    PetcutAnalysisResult(
      products: products,
      comboAnalysis: PetcutComboAnalysis(
        nutrientTotals: nutrientTotals,
        mechanismConflicts: mechanismConflicts,
        exclusionRecommendations: exclusions,
      ),
      overallStatus: overallStatus,
      overallSummary: '',
    );

ExclusionRecommendation _exclusion({
  required int tier,
  String action = 'remove',
  String targetProduct = 'Test Product',
  String reason = '',
  double? monthlySavingsUsd,
}) =>
    ExclusionRecommendation(
      tier: tier,
      action: action,
      targetProduct: targetProduct,
      reason: reason,
      monthlySavingsUsd: monthlySavingsUsd,
    );

MechanismConflict _conflict({
  String conflictType = 'anticoagulant_stacking',
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

FlaggedIngredient _flag({
  String ingredient = 'Test',
  String reason = 'toxic_to_species',
  String severity = 'caution',
  String detail = '',
}) =>
    FlaggedIngredient(
      ingredient: ingredient,
      reason: reason,
      severity: severity,
      detail: detail,
    );

NutrientTotal _nutrient({
  String nutrient = 'Calcium',
  String status = 'safe',
  double totalDailyIntake = 0.0,
  String unit = 'mg',
  List<String> sources = const [],
  double? percentOfLimit,
  double? safeUpperLimit,
  String? safeUpperLimitSource,
}) =>
    NutrientTotal(
      nutrient: nutrient,
      totalDailyIntake: totalDailyIntake,
      unit: unit,
      sources: sources,
      percentOfLimit: percentOfLimit,
      status: status,
      safeUpperLimit: safeUpperLimit,
      safeUpperLimitSource: safeUpperLimitSource,
    );

PetcutProduct _product({
  String productName = 'Food A',
  String productType = 'food',
  List<FlaggedIngredient> flaggedIngredients = const [],
}) =>
    PetcutProduct(
      productName: productName,
      productType: productType,
      ingredientsRaw: '',
      keyNutrients: const [],
      flaggedIngredients: flaggedIngredients,
    );

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('Section5InputBuilder.build — triage tier determination', () {
    test('(a) warning + critical mechanism -> urgent', () {
      final result = Section5InputBuilder.build(
        geminiResult: _buildResult(
          overallStatus: 'warning',
          mechanismConflicts: [_conflict(severity: 'critical')],
          products: const [],
          nutrientTotals: const [],
        ),
        pet: _dog(),
      );
      expect((result['triage'] as Map)['final_tier'], 'urgent');
    });

    test('(b) warning + critical flag -> urgent', () {
      final result = Section5InputBuilder.build(
        geminiResult: _buildResult(
          overallStatus: 'warning',
          products: [
            _product(flaggedIngredients: [
              _flag(severity: 'critical', reason: 'toxic_to_species'),
            ]),
          ],
          mechanismConflicts: const [],
          nutrientTotals: const [],
        ),
        pet: _dog(),
      );
      expect((result['triage'] as Map)['final_tier'], 'urgent');
    });

    test('(c) warning + critical nutrient -> urgent', () {
      final result = Section5InputBuilder.build(
        geminiResult: _buildResult(
          overallStatus: 'warning',
          nutrientTotals: [_nutrient(status: 'critical')],
          mechanismConflicts: const [],
          products: const [],
        ),
        pet: _dog(),
      );
      expect((result['triage'] as Map)['final_tier'], 'urgent');
    });

    test('(d) caution + non-critical mechanism -> next_vet_visit', () {
      final result = Section5InputBuilder.build(
        geminiResult: _buildResult(
          overallStatus: 'caution',
          mechanismConflicts: [_conflict(severity: 'caution')],
          products: const [],
          nutrientTotals: const [],
        ),
        pet: _dog(),
      );
      expect((result['triage'] as Map)['final_tier'], 'next_vet_visit');
    });

    test('(e) caution + life_stage_mismatch flag -> next_vet_visit', () {
      final result = Section5InputBuilder.build(
        geminiResult: _buildResult(
          overallStatus: 'caution',
          products: [
            _product(flaggedIngredients: [
              _flag(reason: 'life_stage_mismatch'),
            ]),
          ],
          mechanismConflicts: const [],
          nutrientTotals: const [],
        ),
        pet: _dog(),
      );
      expect((result['triage'] as Map)['final_tier'], 'next_vet_visit');
    });

    test('(f) caution-level nutrient only -> self_adjust', () {
      final geminiResult = _buildResult(
        overallStatus: 'caution',
        nutrientTotals: [_nutrient(status: 'caution')],
        mechanismConflicts: const [],
        products: const [],
      );
      // Sanity: const constructor bypasses _enforceOverallStatus, so the
      // test-supplied overallStatus survives intact.
      expect(
        geminiResult.overallStatus,
        'caution',
        reason: 'Sanity: const constructor bypasses _enforceOverallStatus',
      );
      final result = Section5InputBuilder.build(
        geminiResult: geminiResult,
        pet: _dog(),
      );
      expect((result['triage'] as Map)['final_tier'], 'self_adjust');
    });
  });

  group('Section5InputBuilder.build — action verb mapping', () {
    test('(g) action "remove" -> action_verb "stop"', () {
      final result = Section5InputBuilder.build(
        geminiResult: _buildResult(
          exclusions: [_exclusion(tier: 1, action: 'remove')],
        ),
        pet: _dog(),
      );
      final actions = (result['urgent_actions'] as List).cast<Map>();
      expect(actions.first['action_verb'], 'stop');
    });

    test('(h) action "replace" -> action_verb "switch"', () {
      final result = Section5InputBuilder.build(
        geminiResult: _buildResult(
          exclusions: [_exclusion(tier: 1, action: 'replace')],
        ),
        pet: _dog(),
      );
      final actions = (result['urgent_actions'] as List).cast<Map>();
      expect(actions.first['action_verb'], 'switch');
    });

    test('(i) action "reduce" -> action_verb "reduce"', () {
      final result = Section5InputBuilder.build(
        geminiResult: _buildResult(
          exclusions: [_exclusion(tier: 1, action: 'reduce')],
        ),
        pet: _dog(),
      );
      final actions = (result['urgent_actions'] as List).cast<Map>();
      expect(actions.first['action_verb'], 'reduce');
    });

    test('(j) unknown action -> action_verb "adjust" (fallback)', () {
      final result = Section5InputBuilder.build(
        geminiResult: _buildResult(
          exclusions: [_exclusion(tier: 1, action: 'discuss')],
        ),
        pet: _dog(),
      );
      final actions = (result['urgent_actions'] as List).cast<Map>();
      expect(actions.first['action_verb'], 'adjust');
    });
  });

  group('Section5InputBuilder.build — exclusion tier routing', () {
    test('(k) Gemini tier 1 -> urgent_actions', () {
      final result = Section5InputBuilder.build(
        geminiResult: _buildResult(
          exclusions: [_exclusion(tier: 1, targetProduct: 'P1')],
        ),
        pet: _dog(),
      );
      expect((result['urgent_actions'] as List).length, 1);
      expect((result['next_visit_actions'] as List), isEmpty);
      expect((result['self_adjust_actions'] as List), isEmpty);
    });

    test('(l) Gemini tier 2 -> urgent_actions', () {
      final result = Section5InputBuilder.build(
        geminiResult: _buildResult(
          exclusions: [_exclusion(tier: 2, targetProduct: 'P2')],
        ),
        pet: _dog(),
      );
      expect((result['urgent_actions'] as List).length, 1);
      expect((result['next_visit_actions'] as List), isEmpty);
      expect((result['self_adjust_actions'] as List), isEmpty);
    });

    test('(m) Gemini tier 3 -> next_visit_actions', () {
      final result = Section5InputBuilder.build(
        geminiResult: _buildResult(
          exclusions: [_exclusion(tier: 3, targetProduct: 'P3')],
        ),
        pet: _dog(),
      );
      expect((result['urgent_actions'] as List), isEmpty);
      expect((result['next_visit_actions'] as List).length, 1);
      expect((result['self_adjust_actions'] as List), isEmpty);
    });

    test('(n) Gemini tier 4 -> self_adjust_actions', () {
      final result = Section5InputBuilder.build(
        geminiResult: _buildResult(
          exclusions: [_exclusion(tier: 4, targetProduct: 'P4')],
        ),
        pet: _dog(),
      );
      expect((result['urgent_actions'] as List), isEmpty);
      expect((result['next_visit_actions'] as List), isEmpty);
      expect((result['self_adjust_actions'] as List).length, 1);
    });
  });

  group('Section5InputBuilder.build — bucket independence', () {
    test('(o) tier 1 + 3 + 4 concurrent -> one in each bucket', () {
      final result = Section5InputBuilder.build(
        geminiResult: _buildResult(
          exclusions: [
            _exclusion(tier: 1, targetProduct: 'Urgent Product'),
            _exclusion(tier: 3, targetProduct: 'Visit Product'),
            _exclusion(tier: 4, targetProduct: 'Adjust Product'),
          ],
        ),
        pet: _dog(),
      );
      final urgent = (result['urgent_actions'] as List).cast<Map>();
      final nextVisit = (result['next_visit_actions'] as List).cast<Map>();
      final selfAdjust = (result['self_adjust_actions'] as List).cast<Map>();
      expect(urgent.length, 1);
      expect(nextVisit.length, 1);
      expect(selfAdjust.length, 1);
      expect(urgent.first['target_product'], 'Urgent Product');
      expect(nextVisit.first['target_product'], 'Visit Product');
      expect(selfAdjust.first['target_product'], 'Adjust Product');
    });

    test(
        '(p) overall triage urgent but exclusion tier 4 still lands in '
        'self_adjust_actions (triage vs per-exclusion routing are independent)',
        () {
      final result = Section5InputBuilder.build(
        geminiResult: _buildResult(
          overallStatus: 'warning',
          mechanismConflicts: [_conflict(severity: 'critical')],
          exclusions: [_exclusion(tier: 4, targetProduct: 'Low Priority')],
        ),
        pet: _dog(),
      );
      expect((result['triage'] as Map)['final_tier'], 'urgent');
      expect((result['urgent_actions'] as List), isEmpty);
      expect((result['self_adjust_actions'] as List).length, 1);
      expect(
        (result['self_adjust_actions'] as List).first['target_product'],
        'Low Priority',
      );
    });
  });

  group('Section5InputBuilder.build — prescription_medication_note', () {
    test('(q) prescription note always shown with legal-reviewed text', () {
      // Exercised across three very different scenarios to confirm
      // the MVP constant is unconditionally emitted.
      const expectedText =
          'If your pet is currently taking any prescription medication from '
          'a vet, please share this combo with them as well. Some '
          'supplements interact with common prescriptions.';

      final scenarios = <PetcutAnalysisResult>[
        _buildResult(),
        _buildResult(
          overallStatus: 'warning',
          mechanismConflicts: [_conflict(severity: 'critical')],
        ),
        _buildResult(
          overallStatus: 'safe',
          exclusions: [_exclusion(tier: 4)],
        ),
      ];

      for (final scenario in scenarios) {
        final result = Section5InputBuilder.build(
          geminiResult: scenario,
          pet: _dog(),
        );
        final note =
            result['prescription_medication_note'] as Map<String, dynamic>;
        expect(note['show'], isTrue);
        expect(note['text'], expectedText);
      }
    });
  });

  group('Section5InputBuilder.build — has_any_actions and rationale', () {
    test('(r) empty exclusions -> has_any_actions false', () {
      final result = Section5InputBuilder.build(
        geminiResult: _buildResult(exclusions: const []),
        pet: _dog(),
      );
      expect(result['has_any_actions'], isFalse);
    });

    test('(s) one exclusion -> has_any_actions true', () {
      final result = Section5InputBuilder.build(
        geminiResult: _buildResult(
          exclusions: [_exclusion(tier: 3)],
        ),
        pet: _dog(),
      );
      expect(result['has_any_actions'], isTrue);
    });

    test(
        '(t) mechanism + life_stage_mismatch + critical nutrient produces '
        'a rationale covering every signal', () {
      final result = Section5InputBuilder.build(
        geminiResult: _buildResult(
          overallStatus: 'warning',
          mechanismConflicts: [
            _conflict(
              conflictType: 'anticoagulant_stacking',
              severity: 'caution',
            ),
          ],
          products: [
            _product(flaggedIngredients: [
              _flag(reason: 'life_stage_mismatch'),
            ]),
          ],
          nutrientTotals: [
            _nutrient(nutrient: 'Vitamin D3', status: 'critical'),
          ],
        ),
        pet: _dog(),
      );
      final rationale =
          ((result['triage'] as Map)['tier_rationale'] as List).cast<String>();
      expect(rationale.length, greaterThanOrEqualTo(4));
      expect(rationale, contains('Overall status: warning'));
      expect(
        rationale,
        contains('Mechanism conflict: anticoagulant_stacking (caution)'),
      );
      expect(rationale, contains('Life stage mismatch flagged'));
      expect(rationale, contains('Critical nutrient: Vitamin D3'));
    });

    test('(u) overall safe with no signals -> rationale holds only the status',
        () {
      final result = Section5InputBuilder.build(
        geminiResult: _buildResult(overallStatus: 'safe'),
        pet: _dog(),
      );
      final rationale =
          ((result['triage'] as Map)['tier_rationale'] as List).cast<String>();
      expect(rationale, ['Overall status: safe']);
    });

    test('(v) invalid exclusion tier (0 or 5) falls back to self_adjust', () {
      final result = Section5InputBuilder.build(
        geminiResult: _buildResult(
          exclusions: [
            _exclusion(tier: 0, targetProduct: 'Tier Zero'),
            _exclusion(tier: 5, targetProduct: 'Tier Five'),
          ],
        ),
        pet: _dog(),
      );
      expect((result['urgent_actions'] as List), isEmpty);
      expect((result['next_visit_actions'] as List), isEmpty);
      final selfAdjust = (result['self_adjust_actions'] as List).cast<Map>();
      expect(selfAdjust.length, 2);
      final targets = selfAdjust.map((a) => a['target_product']).toSet();
      expect(targets, {'Tier Zero', 'Tier Five'});
    });
  });
}
