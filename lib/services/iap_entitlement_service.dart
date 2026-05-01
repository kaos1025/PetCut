// PetCut — Pattern D-1 entitlement persistence service.
// ----------------------------------------------------------------------------
// Sprint 2 Chunk 4. Backs the free-retry receipt with `flutter_secure_storage`
// using the host-OS keystore (Android Keystore / iOS Keychain / Win/macOS
// equivalents). The contract is intentionally narrow:
//
//   * One active token at a time (E2: single key
//     `petcut_entitlement_token`). Granting a new retry overwrites any
//     prior token unconditionally.
//   * Delete-on-consume (E2 simplification). `consumeToken()` removes
//     the storage entry; we do not persist `consumed: true` rows. The
//     model's `markConsumed()` helper is for in-memory transitions only.
//   * Read is fail-soft. Missing key → null. Malformed JSON → null AND
//     the corrupt entry is removed, so the service self-heals.
//
// Tamper mitigation in v1 = secure_storage only. HMAC/server verification
// is v1.1 backlog (E4).
// ----------------------------------------------------------------------------

import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../models/entitlement_token.dart';

class IapEntitlementService {
  /// Single-key storage convention (E2). Do not change without a
  /// migration path — outstanding retry receipts on user devices
  /// reference this exact key.
  static const String entitlementStorageKey = 'petcut_entitlement_token';

  IapEntitlementService({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  /// Persists a fresh free-retry receipt for [purchaseToken] / [productId].
  ///
  /// Any prior token at [entitlementStorageKey] is overwritten — there
  /// is exactly one active free-retry receipt at any time. Returns the
  /// token that was written so callers (the Chunk 5 orchestrator) can
  /// emit telemetry without re-reading from storage.
  Future<EntitlementToken> grantFreeRetry({
    required String purchaseToken,
    required String productId,
  }) async {
    final token = EntitlementToken(
      purchaseToken: purchaseToken,
      productId: productId,
      grantedAt: DateTime.now(),
    );
    await _storage.write(
      key: entitlementStorageKey,
      value: jsonEncode(token.toJson()),
    );
    return token;
  }

  /// Reads the active free-retry token, or returns null if there isn't
  /// one. Returns null for any of:
  ///   * No entry under [entitlementStorageKey]
  ///   * Empty string payload
  ///   * Malformed JSON (the corrupt entry is removed before returning)
  ///   * Stored token has `consumed: true`
  Future<EntitlementToken?> getActiveToken() async {
    final raw = await _storage.read(key: entitlementStorageKey);
    if (raw == null || raw.isEmpty) return null;

    final EntitlementToken token;
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      token = EntitlementToken.fromJson(json);
    } catch (_) {
      // Malformed payload: self-heal by clearing the entry, so a
      // future grant can write cleanly into the canonical slot.
      await _storage.delete(key: entitlementStorageKey);
      return null;
    }

    if (token.consumed) return null;
    return token;
  }

  /// Marks the active retry as spent by deleting the storage entry.
  /// Idempotent — calling on an empty store is a no-op at the platform
  /// level.
  Future<void> consumeToken() async {
    await _storage.delete(key: entitlementStorageKey);
  }

  /// Debug/test escape hatch. Same delete behavior as [consumeToken];
  /// kept distinct for callsite intent.
  Future<void> clearAll() async {
    await _storage.delete(key: entitlementStorageKey);
  }
}
