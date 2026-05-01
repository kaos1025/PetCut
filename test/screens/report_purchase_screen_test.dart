// test/screens/report_purchase_screen_test.dart
//
// PetCut — purchase entry screen smoke tests
// ----------------------------------------------------------------------------
// Sprint 2 Chunk 7a. Three scenarios:
//   1. No active token → renders price (formattedPrice) + paid CTA.
//   2. Active token    → renders Free Retry CTA, hides price (U6).
//   3. Tap on paid CTA → invokes orchestrator.purchaseAndAnalyze exactly
//      once (silent path — orchestrator returns canceled).
//
// Pricing assertion uses the fake `ProductDetails.price` value so the test
// verifies the screen surfaces formattedPrice verbatim, not a hardcoded
// string.
// ----------------------------------------------------------------------------

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petcut/constants/iap_product_ids.dart';
import 'package:petcut/core/service_locator.dart';
import 'package:petcut/models/entitlement_token.dart';
import 'package:petcut/models/pet_profile.dart';
import 'package:petcut/models/petcut_analysis_result.dart';
import 'package:petcut/screens/report_purchase_screen.dart';
import 'package:petcut/services/iap_billing_service.dart';
import 'package:petcut/services/iap_entitlement_service.dart';
import 'package:petcut/services/report_purchase_orchestrator.dart';
import 'package:petcut/widgets/refund_policy_disclaimer.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

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

ProductDetailsResponse _withProduct(String price) {
  return ProductDetailsResponse(
    productDetails: <ProductDetails>[
      FakeProductDetails(
        id: petcutReportStandardV1,
        title: 'PetCut Detailed Report',
        description: 'Pet-specific detailed Claude report.',
        price: price,
        rawPrice: 1.99,
        currencyCode: 'USD',
      ),
    ],
    notFoundIDs: const <String>[],
  );
}

void main() {
  late FakeBillingService billing;
  late FakeEntitlementService entitlement;
  late FakeOrchestrator orchestrator;

  setUp(() async {
    await getIt.reset();
    billing = FakeBillingService();
    entitlement = FakeEntitlementService();
    orchestrator = FakeOrchestrator();
    getIt.registerSingleton<IapBillingService>(billing);
    getIt.registerSingleton<IapEntitlementService>(entitlement);
    getIt.registerSingleton<ReportPurchaseOrchestrator>(orchestrator);
  });

  tearDown(() async {
    await getIt.reset();
  });

  testWidgets('renders formattedPrice and paid CTA when no token is active',
      (tester) async {
    billing.onQueryProductDetails = () => _withProduct(r'$1.99');
    entitlement.activeToken = null;

    await tester.pumpWidget(
      MaterialApp(
        home: ReportPurchaseScreen(
          petProfile: _pet(),
          analysisResult: _gemini(),
          scanId: 'scan_X',
        ),
      ),
    );
    // Allow bootstrap to complete.
    await tester.pumpAndSettle();

    // Pricing surfaces from ProductDetails.price (Play Billing
    // formattedPrice), never hardcoded.
    expect(find.text(r'$1.99'), findsOneWidget);
    expect(find.text('Get Detailed Report'), findsOneWidget);
    expect(find.text('Use Free Retry'), findsNothing);
    expect(find.byType(RefundPolicyDisclaimer), findsOneWidget);
  });

  testWidgets(
    'renders Free Retry CTA and hides price when a token is active',
    (tester) async {
      // Even if billing returns a product, an active token suppresses the
      // price line per U6.
      billing.onQueryProductDetails = () => _withProduct(r'$1.99');
      entitlement.activeToken = EntitlementToken(
        purchaseToken: 'GPA.token',
        productId: petcutReportStandardV1,
        grantedAt: DateTime.utc(2026, 5, 1),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: ReportPurchaseScreen(
            petProfile: _pet(),
            analysisResult: _gemini(),
            scanId: 'scan_X',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Use Free Retry'), findsOneWidget);
      expect(find.text('Get Detailed Report'), findsNothing);
      expect(find.text(r'$1.99'), findsNothing);
      expect(find.byType(RefundPolicyDisclaimer), findsOneWidget);
    },
  );

  testWidgets('paid CTA tap dispatches to orchestrator.purchaseAndAnalyze',
      (tester) async {
    billing.onQueryProductDetails = () => _withProduct(r'$1.99');
    entitlement.activeToken = null;

    await tester.pumpWidget(
      MaterialApp(
        home: ReportPurchaseScreen(
          petProfile: _pet(),
          analysisResult: _gemini(),
          scanId: 'scan_X',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(orchestrator.purchaseAndAnalyzeCalls, 0);

    await tester.tap(find.text('Get Detailed Report'));
    await tester.pumpAndSettle();

    expect(orchestrator.purchaseAndAnalyzeCalls, 1);
    expect(orchestrator.retryWithFreeTokenCalls, 0);
  });
}
