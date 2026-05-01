// PetCut — IAP purchase state (Pattern D state machine).
// ----------------------------------------------------------------------------
// Sprint 2 Chunk 2b. Documents the five lifecycle states of a paid-report
// purchase under Pattern D, where the Google Play `consume()` call is
// deliberately deferred until the Claude detailed report has been generated.
//
// State machine (Pattern D):
//
//   idle
//     │ user taps "Get Detailed Report"
//     ▼
//   purchasing
//     │ Google Play stream emits PurchaseStatus.purchased
//     ▼
//   awaitingClaude  ◄────── consume() intentionally NOT called yet
//     │
//     ├── Claude API succeeds ─► consumed (entitlement granted)
//     │
//     └── Claude exhausts retries ─► claudeFailedPendingRefund
//                                    (purchase left unconsumed → Google
//                                     auto-refunds in ~3 days)
//
// User-cancellation and payment-stage errors are NOT modeled here — they
// resolve directly to a `ReportPurchaseFailure` subtype without entering
// `awaitingClaude`. See `report_purchase_result.dart`.
// ----------------------------------------------------------------------------

/// Lifecycle state of an in-flight paid-report purchase.
///
/// Used by the IAP service (Chunk 4) to drive the UI banner and to gate
/// `consume()` calls. UI-facing copy lives in the screen layer, not on
/// the enum.
enum PurchaseState {
  /// No purchase in flight. The "Get Detailed Report" CTA is enabled.
  idle,

  /// Google Play billing UI is on screen. Awaiting a `PurchaseStatus`
  /// notification from the platform stream.
  purchasing,

  /// **Pattern D core.** `PurchaseStatus.purchased` has been received,
  /// but `consume()` is intentionally deferred while the Claude detailed
  /// report is generated. The store still treats the purchase as pending
  /// acknowledgement, which is the safety net that triggers the auto
  /// refund if Claude ultimately fails.
  awaitingClaude,

  /// Claude succeeded and `consume()` has been acknowledged by the store.
  /// Entitlement is granted; the corresponding scan history entry's
  /// `isPaidReport` flag is flipped to true.
  consumed,

  /// Claude exhausted all retries. The purchase is intentionally left
  /// **unconsumed** so Google issues an automatic refund after ~3 days.
  /// The user is offered a free retry path against the same purchase
  /// token (see `ReportPurchaseFreeRetryGranted`).
  claudeFailedPendingRefund,
}
