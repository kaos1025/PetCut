// PetCut — Pattern D-1 free-retry entitlement token.
// ----------------------------------------------------------------------------
// Sprint 2 Chunk 4. Persisted single-token receipt of a free retry the user
// is owed when Claude exhausted retries during the awaiting-Claude window.
//
// The token is the entire receipt: it carries the Play Billing purchase
// token (so the orchestrator can target the same purchase on the retry),
// the SKU, and a timestamp for grant freshness. There is one token at a
// time per E2 (`petcut_entitlement_token` single-key policy in
// IapEntitlementService).
//
// Tamper mitigation in v1 is the host-OS keystore underneath
// `flutter_secure_storage` — HMAC and server-side verification are v1.1
// backlog (E4).
// ----------------------------------------------------------------------------

class EntitlementToken {
  final String purchaseToken;
  final String productId;
  final DateTime grantedAt;
  final bool consumed;

  const EntitlementToken({
    required this.purchaseToken,
    required this.productId,
    required this.grantedAt,
    this.consumed = false,
  });

  factory EntitlementToken.fromJson(Map<String, dynamic> json) {
    return EntitlementToken(
      purchaseToken: json['purchaseToken'] as String? ?? '',
      productId: json['productId'] as String? ?? '',
      grantedAt: DateTime.tryParse(json['grantedAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      consumed: json['consumed'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'purchaseToken': purchaseToken,
        'productId': productId,
        'grantedAt': grantedAt.toIso8601String(),
        'consumed': consumed,
      };

  /// Returns a copy with [consumed] flipped to true.
  ///
  /// The default IapEntitlementService strategy deletes the storage key
  /// on consume rather than persisting `consumed: true`, so this helper
  /// exists primarily for in-memory transitions and forward-compatible
  /// callers that may want to preserve the audit trail.
  EntitlementToken markConsumed() {
    return EntitlementToken(
      purchaseToken: purchaseToken,
      productId: productId,
      grantedAt: grantedAt,
      consumed: true,
    );
  }
}
