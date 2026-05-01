// test/services/report_purchase_orchestrator_test.dart
//
// PetCut — ReportPurchaseOrchestrator state-machine tests
// ----------------------------------------------------------------------------
// Sprint 2 Chunk 5. Verifies every Plan §5 transition end-to-end and pins
// the Pattern D consume gate at the integration layer:
//
//   * IapBillingService.consume is called only on the Claude success
//     branch — verifyNever everywhere else.
//   * IapEntitlementService.grantFreeRetry is called only on the Claude
//     failure branch.
//   * ScanHistoryService.markAsPaid runs in lockstep with consume.
//
// The four downstream services are mocktail-mocked. The Claude success
// fixture is loaded through the shared `loadClaudeFixture` helper so
// schema regressions surface here as well as in the dedicated Claude
// service tests.
// ----------------------------------------------------------------------------

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:mocktail/mocktail.dart';
import 'package:petcut/models/entitlement_token.dart';
import 'package:petcut/models/iap_purchase_state.dart';
import 'package:petcut/models/pet_profile.dart';
import 'package:petcut/models/petcut_analysis_result.dart';
import 'package:petcut/models/report_purchase_result.dart';
import 'package:petcut/services/claude_report_service.dart';
import 'package:petcut/services/iap_billing_service.dart';
import 'package:petcut/services/iap_entitlement_service.dart';
import 'package:petcut/services/report_purchase_orchestrator.dart';
import 'package:petcut/services/scan_history_service.dart';

import '../helpers/load_claude_fixture.dart';

class _MockBilling extends Mock implements IapBillingService {}

class _MockEntitlement extends Mock implements IapEntitlementService {}

class _MockClaude extends Mock implements ClaudeReportService {}

class _MockHistory extends Mock implements ScanHistoryService {}

class _MockProductDetails extends Mock implements ProductDetails {}

class _MockPetProfile extends Mock implements PetProfile {}

class _MockGeminiResult extends Mock implements PetcutAnalysisResult {}

class _FakePurchaseDetails extends Fake implements PurchaseDetails {}

class _FakeProductDetails extends Fake implements ProductDetails {}

class _FakePetProfile extends Fake implements PetProfile {}

class _FakeAnalysisResult extends Fake implements PetcutAnalysisResult {}

const _kProductId = 'petcut_report_standard_v1';
const _kPurchaseToken = 'GPA.1234-5678-9012-34567';
const _kScanId = 'scan_12345';

PurchaseDetails _purchase({
  required PurchaseStatus status,
  String? id,
  IAPError? error,
  bool pendingCompletePurchase = false,
  String transactionDate = '1714521600000',
}) {
  return PurchaseDetails(
    purchaseID: id ?? _kPurchaseToken,
    productID: _kProductId,
    verificationData: PurchaseVerificationData(
      localVerificationData: 'local',
      serverVerificationData: 'server',
      source: 'google_play',
    ),
    transactionDate: transactionDate,
    status: status,
  )
    ..error = error
    ..pendingCompletePurchase = pendingCompletePurchase;
}

void main() {
  setUpAll(() {
    registerFallbackValue(_FakePurchaseDetails());
    registerFallbackValue(_FakeProductDetails());
    registerFallbackValue(_FakePetProfile());
    registerFallbackValue(_FakeAnalysisResult());
  });

  late _MockBilling billing;
  late _MockEntitlement entitlement;
  late _MockClaude claude;
  late _MockHistory history;
  late _MockProductDetails product;
  late _MockPetProfile pet;
  late _MockGeminiResult gemini;
  late ReportPurchaseOrchestrator orchestrator;
  late StreamController<List<PurchaseDetails>> streamController;

  setUp(() {
    billing = _MockBilling();
    entitlement = _MockEntitlement();
    claude = _MockClaude();
    history = _MockHistory();
    product = _MockProductDetails();
    pet = _MockPetProfile();
    gemini = _MockGeminiResult();
    streamController = StreamController<List<PurchaseDetails>>.broadcast();

    when(() => product.id).thenReturn(_kProductId);
    when(() => billing.purchaseStream)
        .thenAnswer((_) => streamController.stream);
    when(() => billing.consume(any())).thenAnswer((_) async {});
    when(() => history.markAsPaid(any())).thenAnswer((_) async {});
    when(() => entitlement.grantFreeRetry(
          purchaseToken: any(named: 'purchaseToken'),
          productId: any(named: 'productId'),
        )).thenAnswer((_) async => EntitlementToken(
          purchaseToken: _kPurchaseToken,
          productId: _kProductId,
          grantedAt: DateTime.now(),
        ));
    when(() => entitlement.getActiveToken())
        .thenAnswer((_) async => null);
    when(() => entitlement.consumeToken()).thenAnswer((_) async {});

    orchestrator = ReportPurchaseOrchestrator(
      billing: billing,
      entitlement: entitlement,
      claude: claude,
      scanHistory: history,
    );
  });

  tearDown(() async {
    await streamController.close();
  });

  group('ReportPurchaseOrchestrator construction', () {
    test('starts in PurchaseState.idle', () {
      expect(orchestrator.state, PurchaseState.idle);
    });
  });

  group('purchaseAndAnalyze — happy path (purchased + Claude success)', () {
    test(
      'consumes purchase, marks scan paid, returns ReportPurchaseSuccess',
      () async {
        when(() => billing.buyConsumable(any())).thenAnswer((_) async {
          // Emit `purchased` after buyConsumable returns, mirroring the
          // real Play Billing flow where purchaseStream events arrive
          // asynchronously.
          Future<void>.microtask(() {
            streamController
                .add([_purchase(status: PurchaseStatus.purchased)]);
          });
          return true;
        });
        when(() => claude.generateReport(
              geminiResult: any(named: 'geminiResult'),
              pet: any(named: 'pet'),
            )).thenAnswer(
          (_) async => loadClaudeFixture('success_full'),
        );

        final result = await orchestrator.purchaseAndAnalyze(
          productDetails: product,
          geminiResult: gemini,
          pet: pet,
          scanId: _kScanId,
        );

        expect(result, isA<ReportPurchaseSuccess>());
        expect(orchestrator.state, PurchaseState.consumed);
        verify(() => billing.consume(any())).called(1);
        verify(() => history.markAsPaid(_kScanId)).called(1);
        verifyNever(() => entitlement.grantFreeRetry(
              purchaseToken: any(named: 'purchaseToken'),
              productId: any(named: 'productId'),
            ));
      },
    );

    test('skips purchases for unrelated productID', () async {
      when(() => billing.buyConsumable(any())).thenAnswer((_) async {
        Future<void>.microtask(() {
          // First an unrelated SKU (should be ignored), then ours.
          streamController.add([
            PurchaseDetails(
              purchaseID: 'GPA.other',
              productID: 'unrelated.product',
              verificationData: PurchaseVerificationData(
                localVerificationData: '',
                serverVerificationData: '',
                source: 'google_play',
              ),
              transactionDate: '0',
              status: PurchaseStatus.purchased,
            ),
            _purchase(status: PurchaseStatus.purchased),
          ]);
        });
        return true;
      });
      when(() => claude.generateReport(
            geminiResult: any(named: 'geminiResult'),
            pet: any(named: 'pet'),
          )).thenAnswer(
        (_) async => loadClaudeFixture('success_full'),
      );

      final result = await orchestrator.purchaseAndAnalyze(
        productDetails: product,
        geminiResult: gemini,
        pet: pet,
        scanId: _kScanId,
      );

      expect(result, isA<ReportPurchaseSuccess>());
    });

    test('ignores pending events while waiting for terminal status',
        () async {
      when(() => billing.buyConsumable(any())).thenAnswer((_) async {
        Future<void>.microtask(() {
          streamController.add([_purchase(status: PurchaseStatus.pending)]);
          // Schedule the terminal event a tick later.
          Future<void>.microtask(() {
            streamController
                .add([_purchase(status: PurchaseStatus.purchased)]);
          });
        });
        return true;
      });
      when(() => claude.generateReport(
            geminiResult: any(named: 'geminiResult'),
            pet: any(named: 'pet'),
          )).thenAnswer(
        (_) async => loadClaudeFixture('success_full'),
      );

      final result = await orchestrator.purchaseAndAnalyze(
        productDetails: product,
        geminiResult: gemini,
        pet: pet,
        scanId: _kScanId,
      );

      expect(result, isA<ReportPurchaseSuccess>());
    });
  });

  group('purchaseAndAnalyze — payment-stage failures (no consume)', () {
    test('user cancellation returns PurchaseCanceledByUser', () async {
      when(() => billing.buyConsumable(any())).thenAnswer((_) async {
        Future<void>.microtask(() {
          streamController.add([_purchase(status: PurchaseStatus.canceled)]);
        });
        return true;
      });

      final result = await orchestrator.purchaseAndAnalyze(
        productDetails: product,
        geminiResult: gemini,
        pet: pet,
        scanId: _kScanId,
      );

      expect(result, isA<PurchaseCanceledByUser>());
      expect(orchestrator.state, PurchaseState.idle);
      verifyNever(() => billing.consume(any()));
      verifyNever(() => history.markAsPaid(any()));
      verifyNever(() => entitlement.grantFreeRetry(
            purchaseToken: any(named: 'purchaseToken'),
            productId: any(named: 'productId'),
          ));
    });

    test('store error returns PaymentError with message', () async {
      when(() => billing.buyConsumable(any())).thenAnswer((_) async {
        Future<void>.microtask(() {
          streamController.add([
            _purchase(
              status: PurchaseStatus.error,
              error: IAPError(
                source: 'google_play',
                code: 'BillingResponse.serviceUnavailable',
                message: 'Unable to connect',
              ),
            ),
          ]);
        });
        return true;
      });

      final result = await orchestrator.purchaseAndAnalyze(
        productDetails: product,
        geminiResult: gemini,
        pet: pet,
        scanId: _kScanId,
      );

      expect(result, isA<PaymentError>());
      expect((result as PaymentError).details, 'Unable to connect');
      expect(orchestrator.state, PurchaseState.idle);
      verifyNever(() => billing.consume(any()));
    });

    test('buyConsumable returning false short-circuits to PaymentError',
        () async {
      when(() => billing.buyConsumable(any())).thenAnswer((_) async => false);

      final result = await orchestrator.purchaseAndAnalyze(
        productDetails: product,
        geminiResult: gemini,
        pet: pet,
        scanId: _kScanId,
      );

      expect(result, isA<PaymentError>());
      expect(orchestrator.state, PurchaseState.idle);
      verifyNever(() => billing.consume(any()));
    });
  });

  group('purchaseAndAnalyze — Claude failure (★ Pattern D refund branch)',
      () {
    test(
      'Claude exception leaves purchase unconsumed and grants a free retry',
      () async {
        when(() => billing.buyConsumable(any())).thenAnswer((_) async {
          Future<void>.microtask(() {
            streamController
                .add([_purchase(status: PurchaseStatus.purchased)]);
          });
          return true;
        });
        when(() => claude.generateReport(
              geminiResult: any(named: 'geminiResult'),
              pet: any(named: 'pet'),
            )).thenThrow(Exception('claude 5xx after retries'));

        final result = await orchestrator.purchaseAndAnalyze(
          productDetails: product,
          geminiResult: gemini,
          pet: pet,
          scanId: _kScanId,
        );

        expect(result, isA<ReportPurchaseFreeRetryGranted>());
        expect((result as ReportPurchaseFreeRetryGranted).purchaseToken,
            _kPurchaseToken);
        expect(orchestrator.state, PurchaseState.claudeFailedPendingRefund);

        // ★ Pattern D consume gate — the load-bearing assertion.
        verifyNever(() => billing.consume(any()));

        verifyNever(() => history.markAsPaid(any()));
        verify(() => entitlement.grantFreeRetry(
              purchaseToken: _kPurchaseToken,
              productId: _kProductId,
            )).called(1);
      },
    );
  });

  group('retryWithFreeToken', () {
    test('happy path consumes the entitlement token, returns Success',
        () async {
      when(() => entitlement.getActiveToken()).thenAnswer(
        (_) async => EntitlementToken(
          purchaseToken: _kPurchaseToken,
          productId: _kProductId,
          grantedAt: DateTime.utc(2026, 5, 1),
        ),
      );
      when(() => claude.generateReport(
            geminiResult: any(named: 'geminiResult'),
            pet: any(named: 'pet'),
          )).thenAnswer((_) async => loadClaudeFixture('success_full'));

      final result = await orchestrator.retryWithFreeToken(
        geminiResult: gemini,
        pet: pet,
        scanId: _kScanId,
      );

      expect(result, isA<ReportPurchaseSuccess>());
      expect(orchestrator.state, PurchaseState.consumed);
      verify(() => entitlement.consumeToken()).called(1);
      verify(() => history.markAsPaid(_kScanId)).called(1);
      // The original purchase has already been refunded, so no IAP
      // consume call is appropriate on this path.
      verifyNever(() => billing.consume(any()));
    });

    test('without an active token returns UnknownError', () async {
      when(() => entitlement.getActiveToken()).thenAnswer((_) async => null);

      final result = await orchestrator.retryWithFreeToken(
        geminiResult: gemini,
        pet: pet,
        scanId: _kScanId,
      );

      expect(result, isA<UnknownError>());
      verifyNever(() => claude.generateReport(
            geminiResult: any(named: 'geminiResult'),
            pet: any(named: 'pet'),
          ));
      verifyNever(() => entitlement.consumeToken());
    });

    test(
      'Claude failure leaves the entitlement token intact for next retry',
      () async {
        when(() => entitlement.getActiveToken()).thenAnswer(
          (_) async => EntitlementToken(
            purchaseToken: _kPurchaseToken,
            productId: _kProductId,
            grantedAt: DateTime.utc(2026, 5, 1),
          ),
        );
        when(() => claude.generateReport(
              geminiResult: any(named: 'geminiResult'),
              pet: any(named: 'pet'),
            )).thenThrow(Exception('still 5xx'));

        final result = await orchestrator.retryWithFreeToken(
          geminiResult: gemini,
          pet: pet,
          scanId: _kScanId,
        );

        expect(result, isA<ClaudeApiError>());
        expect((result as ClaudeApiError).purchaseToken, _kPurchaseToken);
        expect(orchestrator.state, PurchaseState.claudeFailedPendingRefund);
        verifyNever(() => entitlement.consumeToken());
        verifyNever(() => history.markAsPaid(any()));
      },
    );
  });

  group('recoverPendingPurchases (Sprint 2 Chunk 6.5)', () {
    const fastDrain = Duration(milliseconds: 50);

    setUp(() {
      when(() => billing.restorePurchases()).thenAnswer((_) async {});
    });

    test('no pending purchases → no grant, no consume', () async {
      when(() => entitlement.getActiveToken()).thenAnswer((_) async => null);
      // Stream emits nothing during the drain window.

      await orchestrator.recoverPendingPurchases(drainTimeout: fastDrain);

      verify(() => billing.restorePurchases()).called(1);
      verifyNever(() => entitlement.grantFreeRetry(
            purchaseToken: any(named: 'purchaseToken'),
            productId: any(named: 'productId'),
          ));
      verifyNever(() => billing.consume(any()));
    });

    test(
      'pending purchase + no active token → grants a free retry',
      () async {
        when(() => entitlement.getActiveToken())
            .thenAnswer((_) async => null);
        when(() => billing.restorePurchases()).thenAnswer((_) async {
          Future<void>.microtask(() {
            streamController.add([
              _purchase(
                status: PurchaseStatus.purchased,
                id: 'GPA.pending-token',
                pendingCompletePurchase: true,
              ),
            ]);
          });
        });

        await orchestrator.recoverPendingPurchases(
          drainTimeout: fastDrain,
        );

        verify(() => entitlement.grantFreeRetry(
              purchaseToken: 'GPA.pending-token',
              productId: _kProductId,
            )).called(1);
      },
    );

    test(
      'pending purchase + active token → idempotent no-op',
      () async {
        when(() => entitlement.getActiveToken()).thenAnswer(
          (_) async => EntitlementToken(
            purchaseToken: 'existing-token',
            productId: _kProductId,
            grantedAt: DateTime.utc(2026, 5, 1),
          ),
        );
        when(() => billing.restorePurchases()).thenAnswer((_) async {
          Future<void>.microtask(() {
            streamController.add([
              _purchase(
                status: PurchaseStatus.purchased,
                pendingCompletePurchase: true,
              ),
            ]);
          });
        });

        await orchestrator.recoverPendingPurchases(
          drainTimeout: fastDrain,
        );

        verifyNever(() => entitlement.grantFreeRetry(
              purchaseToken: any(named: 'purchaseToken'),
              productId: any(named: 'productId'),
            ));
      },
    );

    test(
      '★ Pattern D: recovery never triggers consume regardless of branch',
      () async {
        when(() => entitlement.getActiveToken())
            .thenAnswer((_) async => null);
        when(() => billing.restorePurchases()).thenAnswer((_) async {
          Future<void>.microtask(() {
            streamController.add([
              _purchase(
                status: PurchaseStatus.restored,
                id: 'GPA.restored',
                pendingCompletePurchase: true,
              ),
            ]);
          });
        });

        await orchestrator.recoverPendingPurchases(
          drainTimeout: fastDrain,
        );

        // The load-bearing assertion for the recovery path: even with
        // a pendingCompletePurchase=true event flowing through the
        // stream, the orchestrator must not consume it. The user is
        // simply offered a free retry instead.
        verifyNever(() => billing.consume(any()));
      },
    );

    test(
      'multiple pending → grants for the most recent transactionDate only',
      () async {
        when(() => entitlement.getActiveToken())
            .thenAnswer((_) async => null);
        when(() => billing.restorePurchases()).thenAnswer((_) async {
          Future<void>.microtask(() {
            streamController.add([
              _purchase(
                status: PurchaseStatus.purchased,
                id: 'GPA.older',
                pendingCompletePurchase: true,
                transactionDate: '1700000000000',
              ),
              _purchase(
                status: PurchaseStatus.purchased,
                id: 'GPA.newer',
                pendingCompletePurchase: true,
                transactionDate: '1714521600000',
              ),
            ]);
          });
        });

        await orchestrator.recoverPendingPurchases(
          drainTimeout: fastDrain,
        );

        // Exactly one grant; pinned to the newer transaction date.
        verify(() => entitlement.grantFreeRetry(
              purchaseToken: 'GPA.newer',
              productId: _kProductId,
            )).called(1);
        verifyNever(() => entitlement.grantFreeRetry(
              purchaseToken: 'GPA.older',
              productId: any(named: 'productId'),
            ));
      },
    );
  });
}
