// test/utils/observation_expression_test.dart
//
// PetCut — ObservationExpression tests
// ----------------------------------------------------------------------------
// Verifies the closed-mapping formatter that converts
// WarningSignEntry.observationHours into §4 observation-window phrases, and
// guards against unmapped values leaking in without clinical review.
// ----------------------------------------------------------------------------

import 'package:flutter_test/flutter_test.dart';
import 'package:petcut/constants/observable_warning_signs.dart';
import 'package:petcut/utils/observation_expression.dart';

void main() {
  group('ObservationExpression.fromHours — approved values', () {
    test('(a) 24h maps to "over the next 24 hours"', () {
      expect(ObservationExpression.fromHours(24), 'over the next 24 hours');
    });

    test('(b) 48h maps to "over the next 48 hours"', () {
      expect(ObservationExpression.fromHours(48), 'over the next 48 hours');
    });

    test('(c) 72h maps to "over the next 3 days"', () {
      expect(ObservationExpression.fromHours(72), 'over the next 3 days');
    });

    test('(d) 168h maps to "over the next week"', () {
      expect(ObservationExpression.fromHours(168), 'over the next week');
    });

    test(
      '(e) 336h maps to "during walks and rest over the next 2-3 weeks"',
      () {
        expect(
          ObservationExpression.fromHours(336),
          'during walks and rest over the next 2-3 weeks',
        );
      },
    );
  });

  group('ObservationExpression.fromHours — rejected values', () {
    test('(f) rejects 25h (value not in mapping)', () {
      expect(
        () => ObservationExpression.fromHours(25),
        throwsA(isA<StateError>()),
      );
    });

    test('(g) rejects 0h (invalid observation window)', () {
      expect(
        () => ObservationExpression.fromHours(0),
        throwsA(isA<StateError>()),
      );
    });

    test('(h) rejects 1000h (value not in mapping)', () {
      expect(
        () => ObservationExpression.fromHours(1000),
        throwsA(isA<StateError>()),
      );
    });
  });

  group('ObservationExpression.approvedHours', () {
    test('(i) contains exactly the five approved hour values', () {
      expect(
        ObservationExpression.approvedHours.toSet(),
        {24, 48, 72, 168, 336},
      );
    });
  });

  group('integration with observable_warning_signs', () {
    test('(j) every registered riskKey has a mapped observationHours', () {
      for (final key in ObservableWarningSigns.allRiskKeys) {
        final entry = ObservableWarningSigns.byKey(key)!;
        expect(
          () => ObservationExpression.fromHours(entry.observationHours),
          returnsNormally,
          reason:
              '$key has unmapped observationHours: ${entry.observationHours}',
        );
      }
    });
  });
}
