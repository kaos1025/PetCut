// test/models/petcut_analysis_result_test.dart
//
// PetCut — NutrientTotal safety-threshold fields tests
// ----------------------------------------------------------------------------
// Verifies fromJson graceful degradation for the nullable UL fields
// (safeUpperLimit / safeUpperLimitSource). Gemini output may omit these
// keys; parsing must still succeed with the fields set to null.
// ----------------------------------------------------------------------------

import 'package:flutter_test/flutter_test.dart';
import 'package:petcut/models/petcut_analysis_result.dart';

void main() {
  group('NutrientTotal.fromJson — safety threshold fields', () {
    test('(a) missing UL keys -> both fields null (graceful degradation)', () {
      final n = NutrientTotal.fromJson({
        'nutrient': 'vitamin_d3',
        'total_daily_intake': 1002.8,
        'unit': 'IU',
        'sources': <String>[],
        'status': 'caution',
      });
      expect(n.safeUpperLimit, isNull);
      expect(n.safeUpperLimitSource, isNull);
      // Sanity: existing fields still parsed correctly.
      expect(n.nutrient, 'vitamin_d3');
      expect(n.totalDailyIntake, 1002.8);
      expect(n.status, 'caution');
    });

    test('(b) present UL keys -> parsed with correct types', () {
      final n = NutrientTotal.fromJson({
        'nutrient': 'vitamin_d3',
        'total_daily_intake': 1002.8,
        'unit': 'IU',
        'sources': <String>[],
        'status': 'caution',
        'safe_upper_limit': 200.0,
        'safe_upper_limit_source': 'NRC',
      });
      expect(n.safeUpperLimit, 200.0);
      expect(n.safeUpperLimitSource, 'NRC');
    });
  });
}
