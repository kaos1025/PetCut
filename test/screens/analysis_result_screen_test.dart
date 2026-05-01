// test/screens/analysis_result_screen_test.dart
//
// PetCut — AnalysisResultScreen IAP CTA wiring tests
// ----------------------------------------------------------------------------
// Sprint 2 Chunk 8 — verifies the entry point into the Pattern D pipeline:
//   1. The "Get Detailed Report" CTA + caption render between the
//      Recommendations and Disclaimer sections (P1.6 location).
//   2. Tapping the CTA pushes ReportPurchaseScreen.
//   3. The auto-save is idempotent — tapping the CTA twice does not
//      duplicate the underlying ScanHistoryEntry.
// ----------------------------------------------------------------------------

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petcut/core/service_locator.dart';
import 'package:petcut/models/pet_profile.dart';
import 'package:petcut/models/petcut_analysis_result.dart';
import 'package:petcut/screens/analysis_result_screen.dart';
import 'package:petcut/screens/report_purchase_screen.dart';
import 'package:petcut/services/iap_billing_service.dart';
import 'package:petcut/services/iap_entitlement_service.dart';
import 'package:petcut/services/report_purchase_orchestrator.dart';
import 'package:petcut/services/scan_history_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  late ScanHistoryService scanHistory;

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await getIt.reset();
    scanHistory = ScanHistoryService();
    // The screen reads orchestrator/billing/entitlement only on the
    // ReportPurchaseScreen push that happens AFTER the CTA tap. We
    // still register them so the navigated-to route can build cleanly
    // if a test pushes through.
    getIt.registerSingleton<ScanHistoryService>(scanHistory);
    getIt.registerSingleton<IapBillingService>(FakeBillingService());
    getIt.registerSingleton<IapEntitlementService>(FakeEntitlementService());
    getIt.registerSingleton<ReportPurchaseOrchestrator>(FakeOrchestrator());
  });

  tearDown(() async {
    await getIt.reset();
  });

  testWidgets(
    'CTA + caption render between Recommendations and Disclaimer (P1.6)',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 4000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp(
          home: AnalysisResultScreen(
            result: _gemini(),
            petProfile: _pet(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Get Detailed Report'), findsOneWidget);
      expect(find.text('Premium analysis · See more details'), findsOneWidget);
      expect(
        find.text('Not a substitute for professional veterinary advice.'),
        findsOneWidget,
      );
    },
  );

  testWidgets('CTA tap pushes ReportPurchaseScreen', (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 4000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: AnalysisResultScreen(
          result: _gemini(),
          petProfile: _pet(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(ReportPurchaseScreen), findsNothing);

    await tester.tap(find.text('Get Detailed Report'));
    // ReportPurchaseScreen's bootstrap shows a CircularProgressIndicator
    // until queryProductDetails resolves; pumpAndSettle is fine here
    // because FakeBillingService returns synchronously.
    await tester.pumpAndSettle();

    expect(find.byType(ReportPurchaseScreen), findsOneWidget);
  });

  testWidgets(
    'CTA tap auto-saves the scan idempotently (twice → 1 entry)',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 4000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp(
          home: AnalysisResultScreen(
            result: _gemini(),
            petProfile: _pet(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // First tap → save scan + push
      await tester.tap(find.text('Get Detailed Report'));
      await tester.pumpAndSettle();
      var entries = await scanHistory.getAll();
      expect(entries, hasLength(1));
      final firstId = entries.first.id;

      // Pop back to the AnalysisResultScreen so we can tap the CTA
      // again. The PurchaseScreen exposes its own AppBar back arrow.
      await tester.pageBack();
      await tester.pumpAndSettle();

      expect(find.byType(AnalysisResultScreen), findsOneWidget);

      // Second tap → should NOT add another entry; reuses the same
      // _scanId via the _isSaved guard in the screen.
      await tester.tap(find.text('Get Detailed Report'));
      await tester.pumpAndSettle();
      entries = await scanHistory.getAll();
      expect(entries, hasLength(1));
      expect(entries.first.id, firstId);
    },
  );
}
