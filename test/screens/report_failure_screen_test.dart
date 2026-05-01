// test/screens/report_failure_screen_test.dart
//
// PetCut — failure screen smoke test
// ----------------------------------------------------------------------------
// Sprint 2 Chunk 7a — verifies the D6 refund copy is rendered verbatim
// and that the screen shows the Retry / Close buttons plus the shared
// disclaimer.
// ----------------------------------------------------------------------------

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petcut/core/service_locator.dart';
import 'package:petcut/models/pet_profile.dart';
import 'package:petcut/models/petcut_analysis_result.dart';
import 'package:petcut/screens/report_failure_screen.dart';
import 'package:petcut/services/report_purchase_orchestrator.dart';
import 'package:petcut/widgets/refund_policy_disclaimer.dart';

import '../helpers/orchestrator_test_doubles.dart';

PetProfile _pet() => PetProfile(
      name: 'Buddy',
      species: Species.dog,
      weight: 30,
      weightUnit: WeightUnit.kg,
    );

PetcutAnalysisResult _gemini() => const PetcutAnalysisResult(
      products: [],
      comboAnalysis: PetcutComboAnalysis(
        nutrientTotals: [],
        mechanismConflicts: [],
        exclusionRecommendations: [],
      ),
      overallStatus: 'caution',
      overallSummary: '',
    );

void main() {
  setUp(() async {
    await getIt.reset();
    getIt.registerSingleton<ReportPurchaseOrchestrator>(
      FakeOrchestrator(),
    );
  });

  tearDown(() async {
    await getIt.reset();
  });

  testWidgets('renders D6 refund copy verbatim and core actions',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ReportFailureScreen(
          petProfile: _pet(),
          analysisResult: _gemini(),
          scanId: 'scan_X',
        ),
      ),
    );

    // D6 verbatim copy.
    expect(
      find.text(
        'Your payment will be refunded automatically by Google Play '
        'within 3 days, and one free retry has been granted to your account.',
      ),
      findsOneWidget,
    );

    // Status banner header.
    expect(find.text('Report generation failed'), findsOneWidget);

    // Action buttons.
    expect(find.text('Retry Now (Free)'), findsOneWidget);
    expect(find.text('Close'), findsOneWidget);

    // Shared D8 disclaimer is included on this screen too.
    expect(find.byType(RefundPolicyDisclaimer), findsOneWidget);
  });
}
