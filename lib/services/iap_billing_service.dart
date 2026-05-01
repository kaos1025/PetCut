// PetCut — Play Billing wrapper enforcing Pattern D deferred consume.
// ----------------------------------------------------------------------------
// Sprint 2 Chunk 3. A thin, stateless wrapper over [InAppPurchase] whose
// only job is to make the Pattern D safety net unmistakable in the API
// surface:
//
//   * `buyConsumable` always passes `autoConsume: false` — there is no
//     overload that lets a caller opt back in.
//   * `purchaseStream` is a pass-through. The service never subscribes
//     internally, so a `PurchaseStatus.purchased` event cannot trigger
//     an automatic acknowledgement.
//   * `consume` is the **only** path that calls
//     `InAppPurchase.completePurchase`. Callers (the Chunk 5
//     orchestrator) must invoke it explicitly, and only after the
//     Claude detailed report has been persisted.
//
// Anything richer than that — state machine, retry policy, entitlement
// persistence — lives in higher-level services and is intentionally
// out of scope here.
// ----------------------------------------------------------------------------

import 'package:in_app_purchase/in_app_purchase.dart';

import '../constants/iap_product_ids.dart';

/// Pattern D-safe wrapper over [InAppPurchase].
class IapBillingService {
  /// Wraps the supplied [InAppPurchase] instance. Tests inject a
  /// mocktail double; production resolves the platform singleton.
  IapBillingService({InAppPurchase? iap})
      : _iap = iap ?? InAppPurchase.instance;

  final InAppPurchase _iap;

  /// Queries Play Billing for every SKU in [kPetcutIapProductIds].
  ///
  /// Pricing is rendered downstream from
  /// [ProductDetails.price] (Play Billing's `formattedPrice`) — the
  /// service never derives or hardcodes a price string.
  Future<ProductDetailsResponse> queryProductDetails() {
    return _iap.queryProductDetails(kPetcutIapProductIds);
  }

  /// Initiates a buy flow for [productDetails].
  ///
  /// `autoConsume: false` is the load-bearing Pattern D guarantee: even
  /// if the user completes payment, the purchase remains pending in
  /// Google Play until [consume] is explicitly invoked. If the Claude
  /// step never succeeds, the purchase stays unconsumed and Google
  /// auto-refunds it after ~3 days.
  Future<bool> buyConsumable(ProductDetails productDetails) {
    return _iap.buyConsumable(
      purchaseParam: PurchaseParam(productDetails: productDetails),
      autoConsume: false,
    );
  }

  /// Pass-through to the platform purchase stream.
  ///
  /// The service deliberately does **not** subscribe to this stream.
  /// All branching on [PurchaseStatus] happens in the Chunk 5
  /// orchestrator, which is the single consumer.
  Stream<List<PurchaseDetails>> get purchaseStream => _iap.purchaseStream;

  /// Acknowledges [purchase] to Play Billing, transitioning it from
  /// `pendingCompletePurchase: true` to consumed.
  ///
  /// Must be called **only** after the paid Claude report has been
  /// generated and persisted. Calling earlier — or relying on the
  /// `autoConsume` opt-in — breaks the Pattern D refund safety net
  /// and may charge users for a report they never received.
  Future<void> consume(PurchaseDetails purchase) {
    return _iap.completePurchase(purchase);
  }

  /// Asks Play Billing to replay any unconsumed purchases through
  /// [purchaseStream].
  ///
  /// Sprint 2 Chunk 6.5 — supports cross-session Pattern D-1 recovery:
  /// if the previous session terminated mid-flow (process kill, app
  /// crash) the purchase still exists, unconsumed, on the user's
  /// account. Calling this on app start gives the orchestrator a
  /// chance to grant a free-retry token before the user can interact.
  ///
  /// ★ Pattern D invariant unchanged: restored purchases arrive in
  /// the stream with `PurchaseStatus.restored` and remain
  /// **unconsumed** until [consume] is explicitly called. The service
  /// never subscribes to its own stream, so there is no path by which
  /// a restored purchased event can trigger an automatic
  /// `completePurchase`.
  Future<void> restorePurchases() {
    return _iap.restorePurchases();
  }
}
