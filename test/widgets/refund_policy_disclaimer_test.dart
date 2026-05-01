// test/widgets/refund_policy_disclaimer_test.dart
//
// PetCut — D8 fine print widget smoke test
// ----------------------------------------------------------------------------
// Sprint 2 Chunk 7a — pins the verbatim D8 lock-in copy. The text is shared
// between the purchase screen and the failure screen, so a regression here
// is caught before either surface drifts.
// ----------------------------------------------------------------------------

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petcut/widgets/refund_policy_disclaimer.dart';

void main() {
  testWidgets('renders the verbatim D8 refund copy', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: RefundPolicyDisclaimer()),
      ),
    );

    // The static constant is the canonical source — assert the rendered
    // tree matches it exactly.
    expect(find.text(RefundPolicyDisclaimer.text), findsOneWidget);
    expect(
      RefundPolicyDisclaimer.text,
      'If analysis fails, Google Play refunds your payment automatically '
      '(within 3 days), and you get one free retry. No additional charge.',
    );
  });
}
