// test/services/section2_input_builder_test.dart
//
// PetCut — Section2InputBuilder tests
// ----------------------------------------------------------------------------
// Verifies §2 builder orchestration: status-based splitting, sources string
// parsing with raw fallback, per-kg-body-weight computation with unit
// classification, and null propagation for safety-threshold fields.
// ----------------------------------------------------------------------------

import 'package:flutter_test/flutter_test.dart';
import 'package:petcut/models/pet_profile.dart';
import 'package:petcut/models/petcut_analysis_result.dart';
import 'package:petcut/services/section2_input_builder.dart';

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
  List<NutrientTotal> nutrientTotals = const [],
  String overallStatus = 'caution',
}) {
  return PetcutAnalysisResult(
    products: const [],
    comboAnalysis: PetcutComboAnalysis(
      nutrientTotals: nutrientTotals,
      mechanismConflicts: const [],
      exclusionRecommendations: const [],
    ),
    overallStatus: overallStatus,
    overallSummary: '',
  );
}

NutrientTotal _nutrient({
  required String name,
  required double total,
  String unit = 'mg',
  required String status,
  double? safeUpperLimit,
  String? safeUpperLimitSource,
  double? percentOfLimit,
  List<String> sources = const [],
}) =>
    NutrientTotal(
      nutrient: name,
      totalDailyIntake: total,
      unit: unit,
      sources: sources,
      status: status,
      percentOfLimit: percentOfLimit,
      safeUpperLimit: safeUpperLimit,
      safeUpperLimitSource: safeUpperLimitSource,
    );

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('Section2InputBuilder.build — basic structure', () {
    test('(a) only safe nutrients -> has_any_concerns false', () {
      final result = Section2InputBuilder.build(
        geminiResult: _buildResult(
          nutrientTotals: [
            _nutrient(
              name: 'calcium',
              total: 100.0,
              unit: 'mg',
              status: 'safe',
            ),
            _nutrient(
              name: 'zinc',
              total: 10.0,
              unit: 'mg',
              status: 'safe',
            ),
          ],
        ),
        pet: _dog(),
      );
      expect(result['has_any_concerns'], isFalse);
      expect(result['detailed_nutrients'], isEmpty);
      expect((result['safe_nutrients'] as List).length, 2);
    });

    test('(b) mixed detailed + safe -> each split into correct array', () {
      final result = Section2InputBuilder.build(
        geminiResult: _buildResult(
          nutrientTotals: [
            _nutrient(
              name: 'vitamin_d3',
              total: 1000.0,
              unit: 'IU',
              status: 'caution',
            ),
            _nutrient(
              name: 'iron',
              total: 30.0,
              unit: 'mg',
              status: 'warning',
            ),
            _nutrient(
              name: 'calcium',
              total: 100.0,
              unit: 'mg',
              status: 'safe',
            ),
          ],
        ),
        pet: _dog(),
      );
      final detailedKeys = (result['detailed_nutrients'] as List)
          .map((e) => (e as Map)['nutrient'])
          .toSet();
      expect(detailedKeys, {'vitamin_d3', 'iron'});
      final safeKeys = (result['safe_nutrients'] as List)
          .map((e) => (e as Map)['nutrient'])
          .toSet();
      expect(safeKeys, {'calcium'});
      expect(result['has_any_concerns'], isTrue);
    });

    test('(c) summary counts are accurate for each status', () {
      final result = Section2InputBuilder.build(
        geminiResult: _buildResult(
          nutrientTotals: [
            _nutrient(name: 'a', total: 1.0, status: 'safe'),
            _nutrient(name: 'b', total: 1.0, status: 'safe'),
            _nutrient(name: 'c', total: 1.0, status: 'caution'),
            _nutrient(name: 'd', total: 1.0, status: 'warning'),
            _nutrient(name: 'e', total: 1.0, status: 'critical'),
          ],
        ),
        pet: _dog(),
      );
      final summary = result['summary'] as Map;
      expect(summary['total_tracked'], 5);
      expect(summary['safe_count'], 2);
      expect(summary['caution_count'], 1);
      expect(summary['warning_count'], 1);
      expect(summary['critical_count'], 1);
    });
  });

  group('Section2InputBuilder.build — source_breakdown parsing', () {
    test('(d) well-formed "Product A: 500 IU" parses to structured entry', () {
      final result = Section2InputBuilder.build(
        geminiResult: _buildResult(
          nutrientTotals: [
            _nutrient(
              name: 'vitamin_d3',
              total: 500.0,
              unit: 'IU',
              status: 'caution',
              sources: const ['Product A: 500 IU'],
            ),
          ],
        ),
        pet: _dog(),
      );
      final detail = (result['detailed_nutrients'] as List).first as Map;
      final breakdown = detail['source_breakdown'] as List;
      expect(breakdown.length, 1);
      final first = breakdown.first as Map;
      expect(first['product_name'], 'Product A');
      expect(first['amount'], 500.0);
      expect(first['unit'], 'IU');
      expect(first['percent_of_total'], 100.0);
      // All parsed -> no raw fallback.
      expect(detail['raw_sources_string'], isNull);
    });

    test('(e) malformed source (no colon) falls back to raw_sources_string',
        () {
      final result = Section2InputBuilder.build(
        geminiResult: _buildResult(
          nutrientTotals: [
            _nutrient(
              name: 'vitamin_d3',
              total: 502.0,
              unit: 'IU',
              status: 'caution',
              sources: const ['Blue Buffalo 502 IU'],
            ),
          ],
        ),
        pet: _dog(),
      );
      final detail = (result['detailed_nutrients'] as List).first as Map;
      expect(detail['source_breakdown'], isEmpty);
      expect(detail['raw_sources_string'], 'Blue Buffalo 502 IU');
    });

    test('(f) empty sources array -> empty breakdown and null raw', () {
      final result = Section2InputBuilder.build(
        geminiResult: _buildResult(
          nutrientTotals: [
            _nutrient(
              name: 'vitamin_d3',
              total: 500.0,
              unit: 'IU',
              status: 'caution',
              sources: const [],
            ),
          ],
        ),
        pet: _dog(),
      );
      final detail = (result['detailed_nutrients'] as List).first as Map;
      expect(detail['source_breakdown'], isEmpty);
      expect(detail['raw_sources_string'], isNull);
    });
  });

  group('Section2InputBuilder.build — per_kg_body_weight computation', () {
    test('(g) simple mass unit -> per_kg_body_weight computed by Builder', () {
      final result = Section2InputBuilder.build(
        geminiResult: _buildResult(
          nutrientTotals: [
            _nutrient(
              name: 'iron',
              total: 30.0,
              unit: 'mg',
              status: 'caution',
            ),
          ],
        ),
        pet: _dog(), // 15.0 kg
      );
      final detail = (result['detailed_nutrients'] as List).first as Map;
      final perKg = detail['per_kg_body_weight'] as Map;
      expect(perKg['amount'], 2.0); // 30 / 15
      expect(perKg['unit'], 'mg/kg BW/day');
    });

    test(
        '(h) per-kg-food unit ("mg/kg food DM") is not convertible '
        '-> amount null', () {
      final result = Section2InputBuilder.build(
        geminiResult: _buildResult(
          nutrientTotals: [
            _nutrient(
              name: 'calcium',
              total: 2500.0,
              unit: 'mg/kg food DM',
              status: 'caution',
            ),
          ],
        ),
        pet: _dog(),
      );
      final detail = (result['detailed_nutrients'] as List).first as Map;
      final perKg = detail['per_kg_body_weight'] as Map;
      expect(perKg['amount'], isNull);
      expect(perKg['unit'], 'unit not convertible to per-kg BW');
    });
  });

  group('Section2InputBuilder.build — null handling', () {
    test('(i) null safeUpperLimit + null percentOfLimit pass through as null',
        () {
      final result = Section2InputBuilder.build(
        geminiResult: _buildResult(
          nutrientTotals: [
            _nutrient(
              name: 'iron',
              total: 30.0,
              unit: 'mg',
              status: 'warning',
              // safeUpperLimit, safeUpperLimitSource, percentOfLimit default null
            ),
          ],
        ),
        pet: _dog(),
      );
      final detail = (result['detailed_nutrients'] as List).first as Map;
      final upperLimit = detail['safe_upper_limit'] as Map;
      expect(upperLimit['amount'], isNull);
      expect(upperLimit['source'], isNull);
      expect(detail['percent_of_limit'], isNull);
    });

    test(
        '(j) empty sources -> source_breakdown [] and raw_sources_string '
        'null (both keys present)', () {
      final result = Section2InputBuilder.build(
        geminiResult: _buildResult(
          nutrientTotals: [
            _nutrient(
              name: 'zinc',
              total: 10.0,
              unit: 'mg',
              status: 'caution',
              sources: const [],
            ),
          ],
        ),
        pet: _dog(),
      );
      final detail = (result['detailed_nutrients'] as List).first as Map;
      expect(detail.containsKey('source_breakdown'), isTrue);
      expect(detail.containsKey('raw_sources_string'), isTrue);
      expect(detail['source_breakdown'], isEmpty);
      expect(detail['raw_sources_string'], isNull);
    });
  });

  group('Section2InputBuilder.build — summary', () {
    test('(k) summary.overall_status echoes geminiResult.overallStatus', () {
      final result = Section2InputBuilder.build(
        geminiResult: _buildResult(
          nutrientTotals: const [],
          overallStatus: 'warning',
        ),
        pet: _dog(),
      );
      final summary = result['summary'] as Map;
      expect(summary['overall_status'], 'warning');
    });
  });

  group('Section2InputBuilder.build — edge cases', () {
    test(
        '(l) all-empty inputs -> has_any_concerns false + zero-valued '
        'summary', () {
      final result = Section2InputBuilder.build(
        geminiResult: _buildResult(nutrientTotals: const []),
        pet: _dog(),
      );
      expect(result['has_any_concerns'], isFalse);
      expect(result['detailed_nutrients'], isEmpty);
      expect(result['safe_nutrients'], isEmpty);
      final summary = result['summary'] as Map;
      expect(summary['total_tracked'], 0);
      expect(summary['safe_count'], 0);
      expect(summary['caution_count'], 0);
      expect(summary['warning_count'], 0);
      expect(summary['critical_count'], 0);
    });

    test('(m) unknown status routes to detailed and is counted as caution', () {
      final result = Section2InputBuilder.build(
        geminiResult: _buildResult(
          nutrientTotals: [
            _nutrient(
              name: 'vitamin_a',
              total: 1000.0,
              unit: 'IU',
              status: 'unexpected_value',
            ),
          ],
        ),
        pet: _dog(),
      );
      final detailed = result['detailed_nutrients'] as List;
      expect(detailed.length, 1);
      expect((detailed.first as Map)['nutrient'], 'vitamin_a');
      final summary = result['summary'] as Map;
      expect(summary['caution_count'], 1);
      expect(summary['total_tracked'], 1);
    });
  });
}
