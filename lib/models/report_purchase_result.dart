// PetCut — Paid-report purchase result (sealed hierarchy).
// ----------------------------------------------------------------------------
// Sprint 2 Chunk 2b. Terminal result types for the IAP paid-report flow.
// Designed for exhaustive switch-pattern matching: every branch of the
// `PurchaseState` machine eventually resolves to exactly one subtype here.
//
// Sealed-class hierarchy (all subtypes live in this file by Dart rules):
//
//   ReportPurchaseResult                                 (sealed)
//     ├── ReportPurchaseSuccess                          (final)
//     ├── ReportPurchaseFreeRetryGranted                 (final)
//     └── ReportPurchaseFailure                          (sealed)
//           ├── PurchaseCanceledByUser                   (final)
//           ├── PaymentError                             (final)
//           ├── ClaudeApiError                           (final)
//           └── UnknownError                             (final)
//
// The nested sealed Failure umbrella keeps the success/refund/failure
// distinction at the top level (cheap to switch on in callers that only
// care about "did it work"), while the Failure subtypes are still
// exhaustively matchable for callers that render specific error copy.
// ----------------------------------------------------------------------------

import 'claude_report_response.dart';

/// Terminal result of a paid-report purchase flow.
sealed class ReportPurchaseResult {
  const ReportPurchaseResult();
}

/// Happy path: detailed report was generated and the purchase has been
/// consumed by Google Play. The caller persists the report and flips
/// `ScanHistoryEntry.isPaidReport` to true.
final class ReportPurchaseSuccess extends ReportPurchaseResult {
  final ClaudeReportResponse report;

  const ReportPurchaseSuccess({required this.report});
}

/// Pattern D refund branch. Claude exhausted retries while in
/// `PurchaseState.awaitingClaude`; the purchase was deliberately left
/// unconsumed so Google will auto-refund it. The user is granted a free
/// retry path that reuses the same [purchaseToken] so no double charge
/// occurs on the next attempt.
final class ReportPurchaseFreeRetryGranted extends ReportPurchaseResult {
  final String purchaseToken;

  const ReportPurchaseFreeRetryGranted({required this.purchaseToken});
}

/// Failure umbrella. Switch-exhaustive over the inner subtypes when the
/// UI needs to show specific error copy.
sealed class ReportPurchaseFailure extends ReportPurchaseResult {
  const ReportPurchaseFailure();
}

/// User dismissed the Google Play sheet. No charge occurred and no
/// further action is required.
final class PurchaseCanceledByUser extends ReportPurchaseFailure {
  const PurchaseCanceledByUser();
}

/// Google Play billing failed before reaching `awaitingClaude`
/// (network outage, store unavailable, item unavailable, signature
/// verification failure, etc.). [details] is plain English suitable for
/// rendering directly in the error banner.
final class PaymentError extends ReportPurchaseFailure {
  final String details;

  const PaymentError({required this.details});
}

/// Claude API failed during `PurchaseState.awaitingClaude` but the
/// caller has decided this is a recoverable failure (e.g. transient 5xx
/// before the retry budget is exhausted). The IAP service holds the
/// purchase in `awaitingClaude` and surfaces this for telemetry; if the
/// retry budget is exhausted the result escalates to
/// [ReportPurchaseFreeRetryGranted] instead.
final class ClaudeApiError extends ReportPurchaseFailure {
  final String purchaseToken;
  final String message;

  const ClaudeApiError({
    required this.purchaseToken,
    required this.message,
  });
}

/// Catch-all for unexpected failures (parsing bugs, plumbing errors,
/// unanticipated platform exceptions). Should be logged to Crashlytics
/// in production.
final class UnknownError extends ReportPurchaseFailure {
  final Object cause;

  const UnknownError({required this.cause});
}
