// PetCut — Pattern D state-machine orchestrator.
// ----------------------------------------------------------------------------
// Sprint 2 Chunk 5. Wires the four purchase-related services together so
// that the load-bearing Pattern D invariants are enforced at exactly one
// point in the codebase:
//
//   * `IapBillingService.consume` is called only after a successful
//     Claude report. Any Claude failure leaves the purchase
//     **unconsumed** and grants a free-retry receipt instead.
//   * `IapEntitlementService.grantFreeRetry` is the only allocator of
//     retry receipts; the orchestrator is the only caller.
//   * `ScanHistoryService.markAsPaid` runs only on the consume branch.
//
// State transitions (Plan §5):
//
//   idle ─[buyConsumable]→ purchasing
//                            ├─[stream:canceled]→ idle  (no consume)
//                            ├─[stream:error]   → idle  (no consume)
//                            └─[stream:purchased]→ awaitingClaude
//                                                  ├─[Claude success]
//                                                  │    → consumed
//                                                  │      (consume + markAsPaid)
//                                                  └─[Claude failure]
//                                                       → claudeFailedPendingRefund
//                                                         (grantFreeRetry,
//                                                          NO consume)
//
// `retryWithFreeToken` skips the buy step: the original purchase has
// already been refunded by Google, so the entitlement receipt alone
// authorizes the Claude regeneration. No `IapBillingService.consume`
// call is appropriate on this path; the entitlement is consumed via
// `IapEntitlementService.consumeToken` instead.
// ----------------------------------------------------------------------------

import 'dart:async';

import 'package:in_app_purchase/in_app_purchase.dart';

import '../models/iap_purchase_state.dart';
import '../models/pet_profile.dart';
import '../models/petcut_analysis_result.dart';
import '../models/report_purchase_result.dart';
import 'claude_report_service.dart';
import 'iap_billing_service.dart';
import 'iap_entitlement_service.dart';
import 'scan_history_service.dart';

class ReportPurchaseOrchestrator {
  ReportPurchaseOrchestrator({
    required IapBillingService billing,
    required IapEntitlementService entitlement,
    required ClaudeReportService claude,
    required ScanHistoryService scanHistory,
  })  : _billing = billing,
        _entitlement = entitlement,
        _claude = claude,
        _scanHistory = scanHistory;

  final IapBillingService _billing;
  final IapEntitlementService _entitlement;
  final ClaudeReportService _claude;
  final ScanHistoryService _scanHistory;

  PurchaseState _state = PurchaseState.idle;
  PurchaseState get state => _state;

  /// Full happy-path: open Play Billing, await purchase, run Claude,
  /// consume on success / grant free retry on Claude failure.
  Future<ReportPurchaseResult> purchaseAndAnalyze({
    required ProductDetails productDetails,
    required PetcutAnalysisResult geminiResult,
    required PetProfile pet,
    required String scanId,
  }) async {
    _state = PurchaseState.purchasing;

    final purchaseCompleter = Completer<PurchaseDetails>();
    final sub = _billing.purchaseStream.listen((events) {
      for (final p in events) {
        if (p.productID != productDetails.id) continue;
        if (p.status == PurchaseStatus.pending) continue;
        if (!purchaseCompleter.isCompleted) {
          purchaseCompleter.complete(p);
        }
      }
    });

    try {
      final ok = await _billing.buyConsumable(productDetails);
      if (!ok) {
        _state = PurchaseState.idle;
        return const PaymentError(
          details: 'Failed to initiate purchase',
        );
      }

      final purchase = await purchaseCompleter.future;

      switch (purchase.status) {
        case PurchaseStatus.canceled:
          _state = PurchaseState.idle;
          return const PurchaseCanceledByUser();
        case PurchaseStatus.error:
          _state = PurchaseState.idle;
          return PaymentError(
            details: purchase.error?.message ?? 'Payment failed',
          );
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          _state = PurchaseState.awaitingClaude;
          return await _runClaudeAndConsume(
            purchase: purchase,
            geminiResult: geminiResult,
            pet: pet,
            scanId: scanId,
          );
        case PurchaseStatus.pending:
          // Filtered above; reaching here would be a platform contract
          // violation rather than a real flow.
          _state = PurchaseState.idle;
          return UnknownError(
            cause: StateError('unexpected pending status'),
          );
      }
    } catch (e) {
      _state = PurchaseState.idle;
      return UnknownError(cause: e);
    } finally {
      await sub.cancel();
    }
  }

  Future<ReportPurchaseResult> _runClaudeAndConsume({
    required PurchaseDetails purchase,
    required PetcutAnalysisResult geminiResult,
    required PetProfile pet,
    required String scanId,
  }) async {
    try {
      final report = await _claude.generateReport(
        geminiResult: geminiResult,
        pet: pet,
      );

      // ★ Pattern D consume gate: only Claude success reaches consume().
      await _scanHistory.markAsPaid(scanId);
      await _billing.consume(purchase);
      _state = PurchaseState.consumed;

      return ReportPurchaseSuccess(report: report);
    } catch (_) {
      // Claude failed. Do NOT consume — leaving the purchase pending
      // is what triggers Google's auto-refund after ~3 days. Persist a
      // free-retry receipt so the user can re-run Claude later without
      // paying twice.
      final purchaseToken = purchase.purchaseID ?? '';
      await _entitlement.grantFreeRetry(
        purchaseToken: purchaseToken,
        productId: purchase.productID,
      );
      _state = PurchaseState.claudeFailedPendingRefund;

      return ReportPurchaseFreeRetryGranted(purchaseToken: purchaseToken);
    }
  }

  /// Free-retry path: regenerates the Claude report using an existing
  /// entitlement receipt. No Play Billing buy is initiated and no
  /// `IapBillingService.consume` is called — the original purchase was
  /// already auto-refunded. On success the entitlement token is
  /// consumed; on failure the token is left intact so the user can
  /// retry again.
  Future<ReportPurchaseResult> retryWithFreeToken({
    required PetcutAnalysisResult geminiResult,
    required PetProfile pet,
    required String scanId,
  }) async {
    final token = await _entitlement.getActiveToken();
    if (token == null) {
      return UnknownError(
        cause: StateError('No active retry token'),
      );
    }

    _state = PurchaseState.awaitingClaude;

    try {
      final report = await _claude.generateReport(
        geminiResult: geminiResult,
        pet: pet,
      );

      await _scanHistory.markAsPaid(scanId);
      await _entitlement.consumeToken();
      _state = PurchaseState.consumed;

      return ReportPurchaseSuccess(report: report);
    } catch (e) {
      // Token stays in storage so the user can retry yet again.
      _state = PurchaseState.claudeFailedPendingRefund;
      return ClaudeApiError(
        purchaseToken: token.purchaseToken,
        message: e.toString(),
      );
    }
  }
}
