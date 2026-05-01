// test/helpers/orchestrator_test_doubles.dart
//
// PetCut — shared test doubles for IAP-related screens.
// ----------------------------------------------------------------------------
// Sprint 2 Chunk 7a. Widget tests for `report_purchase_screen` and
// `report_failure_screen` resolve services via `getIt`. Registering simple
// hand-rolled fakes (rather than mocktail mocks for every test) keeps the
// widget-test setup small and avoids forcing every screen test to
// registerFallbackValue for the full IAP type surface.
//
// Chunk 7b extension: `pendingPurchaseCompleter` lets a test pin
// ReportGeneratingScreen mid-flow without racing the auto-pop that
// happens when an orchestrator default returns immediately.
// ----------------------------------------------------------------------------

import 'dart:async';

import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:petcut/models/entitlement_token.dart';
import 'package:petcut/models/pet_profile.dart';
import 'package:petcut/models/petcut_analysis_result.dart';
import 'package:petcut/models/report_purchase_result.dart';
import 'package:petcut/services/iap_billing_service.dart';
import 'package:petcut/services/iap_entitlement_service.dart';
import 'package:petcut/services/report_purchase_orchestrator.dart';

class FakeOrchestrator implements ReportPurchaseOrchestrator {
  ReportPurchaseResult Function()? onPurchaseAndAnalyze;
  ReportPurchaseResult Function()? onRetryWithFreeToken;

  /// When non-null, `purchaseAndAnalyze` returns this completer's future
  /// instead of resolving via `onPurchaseAndAnalyze`. Tests use it to hold
  /// `ReportGeneratingScreen` on the loading state long enough to assert
  /// against.
  Completer<ReportPurchaseResult>? pendingPurchaseCompleter;

  int purchaseAndAnalyzeCalls = 0;
  int retryWithFreeTokenCalls = 0;

  @override
  Future<ReportPurchaseResult> purchaseAndAnalyze({
    required ProductDetails productDetails,
    required PetcutAnalysisResult geminiResult,
    required PetProfile pet,
    required String scanId,
  }) {
    purchaseAndAnalyzeCalls += 1;
    if (pendingPurchaseCompleter != null) {
      return pendingPurchaseCompleter!.future;
    }
    return Future.value(
      onPurchaseAndAnalyze?.call() ?? const PurchaseCanceledByUser(),
    );
  }

  @override
  Future<ReportPurchaseResult> retryWithFreeToken({
    required PetcutAnalysisResult geminiResult,
    required PetProfile pet,
    required String scanId,
  }) async {
    retryWithFreeTokenCalls += 1;
    return onRetryWithFreeToken?.call() ??
        const PurchaseCanceledByUser();
  }

  @override
  Future<void> recoverPendingPurchases({
    Duration drainTimeout = const Duration(milliseconds: 500),
  }) async {}

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeBillingService implements IapBillingService {
  ProductDetailsResponse Function()? onQueryProductDetails;

  @override
  Future<ProductDetailsResponse> queryProductDetails() async {
    return onQueryProductDetails?.call() ??
        ProductDetailsResponse(
          productDetails: const <ProductDetails>[],
          notFoundIDs: const <String>[],
        );
  }

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeEntitlementService implements IapEntitlementService {
  EntitlementToken? activeToken;

  @override
  Future<EntitlementToken?> getActiveToken() async => activeToken;

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeProductDetails implements ProductDetails {
  FakeProductDetails({
    required this.id,
    required this.title,
    required this.description,
    required this.price,
    required this.rawPrice,
    required this.currencyCode,
    this.currencySymbol = r'$',
  });

  @override
  final String id;
  @override
  final String title;
  @override
  final String description;
  @override
  final String price;
  @override
  final double rawPrice;
  @override
  final String currencyCode;
  @override
  final String currencySymbol;
}
