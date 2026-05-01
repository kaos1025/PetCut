// test/models/iap_purchase_state_test.dart
//
// PetCut — PurchaseState enum tests
// ----------------------------------------------------------------------------
// Sprint 2 Chunk 2b — verifies the Pattern D state machine surfaces all five
// states and is switch-exhaustive (the IAP service relies on the compiler to
// flag missing branches when the state machine evolves).
// ----------------------------------------------------------------------------

import 'package:flutter_test/flutter_test.dart';
import 'package:petcut/models/iap_purchase_state.dart';

void main() {
  group('PurchaseState enum surface', () {
    test('exposes exactly the five Pattern D states', () {
      // Order is part of the contract: it documents the happy-path flow
      // (idle → purchasing → awaitingClaude → consumed) followed by the
      // refund branch (claudeFailedPendingRefund). If a future state is
      // inserted, this test forces an explicit decision about ordering.
      expect(PurchaseState.values, <PurchaseState>[
        PurchaseState.idle,
        PurchaseState.purchasing,
        PurchaseState.awaitingClaude,
        PurchaseState.consumed,
        PurchaseState.claudeFailedPendingRefund,
      ]);
    });

    test('every value has a stable string identity for telemetry', () {
      // `name` is what analytics events log. Pin the names so a refactor
      // does not silently break dashboards.
      expect(PurchaseState.idle.name, 'idle');
      expect(PurchaseState.purchasing.name, 'purchasing');
      expect(PurchaseState.awaitingClaude.name, 'awaitingClaude');
      expect(PurchaseState.consumed.name, 'consumed');
      expect(
        PurchaseState.claudeFailedPendingRefund.name,
        'claudeFailedPendingRefund',
      );
    });
  });

  group('PurchaseState exhaustive switch', () {
    test('every state maps to a label without a default branch', () {
      // Drives compile-time exhaustiveness. If a new value is added to
      // PurchaseState without updating this switch, `flutter analyze`
      // raises `non_exhaustive_switch_expression`.
      String label(PurchaseState s) => switch (s) {
            PurchaseState.idle => 'idle',
            PurchaseState.purchasing => 'purchasing',
            PurchaseState.awaitingClaude => 'awaitingClaude',
            PurchaseState.consumed => 'consumed',
            PurchaseState.claudeFailedPendingRefund =>
              'claudeFailedPendingRefund',
          };

      for (final s in PurchaseState.values) {
        expect(label(s), s.name);
      }
    });
  });
}
