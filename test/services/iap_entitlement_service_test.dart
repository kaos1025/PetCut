// test/services/iap_entitlement_service_test.dart
//
// PetCut — IapEntitlementService + EntitlementToken tests
// ----------------------------------------------------------------------------
// Sprint 2 Chunk 4 — verifies the single-key + delete-on-consume + fail-soft
// contract of the entitlement service, and the JSON round-trip of the token
// model.
// ----------------------------------------------------------------------------

import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:petcut/models/entitlement_token.dart';
import 'package:petcut/services/iap_entitlement_service.dart';

class _MockSecureStorage extends Mock implements FlutterSecureStorage {}

void main() {
  group('EntitlementToken model', () {
    test('constructor defaults consumed to false', () {
      final token = EntitlementToken(
        purchaseToken: 'GPA.token',
        productId: 'petcut_report_standard_v1',
        grantedAt: DateTime.utc(2026, 5, 1, 12),
      );

      expect(token.consumed, isFalse);
    });

    test('toJson / fromJson round-trip preserves all four fields', () {
      final original = EntitlementToken(
        purchaseToken: 'GPA.1234-5678',
        productId: 'petcut_report_standard_v1',
        grantedAt: DateTime.utc(2026, 5, 1, 9, 30, 15),
        consumed: true,
      );

      final restored = EntitlementToken.fromJson(original.toJson());

      expect(restored.purchaseToken, original.purchaseToken);
      expect(restored.productId, original.productId);
      expect(restored.grantedAt, original.grantedAt);
      expect(restored.consumed, original.consumed);
    });

    test('fromJson tolerates missing keys with safe defaults', () {
      final token = EntitlementToken.fromJson(const <String, dynamic>{});

      expect(token.purchaseToken, '');
      expect(token.productId, '');
      expect(token.grantedAt, DateTime.fromMillisecondsSinceEpoch(0));
      expect(token.consumed, isFalse);
    });

    test('markConsumed flips the flag and preserves other fields', () {
      final original = EntitlementToken(
        purchaseToken: 'GPA.token',
        productId: 'petcut_report_standard_v1',
        grantedAt: DateTime.utc(2026, 5, 1, 12),
      );

      final consumed = original.markConsumed();

      expect(consumed.consumed, isTrue);
      expect(consumed.purchaseToken, original.purchaseToken);
      expect(consumed.productId, original.productId);
      expect(consumed.grantedAt, original.grantedAt);
      // Original is unchanged (immutable semantics).
      expect(original.consumed, isFalse);
    });
  });

  group('IapEntitlementService', () {
    late _MockSecureStorage storage;
    late IapEntitlementService service;

    setUp(() {
      storage = _MockSecureStorage();
      service = IapEntitlementService(storage: storage);

      // Default permissive stubs — individual tests override as needed.
      when(() => storage.read(key: any(named: 'key')))
          .thenAnswer((_) async => null);
      when(() => storage.write(
            key: any(named: 'key'),
            value: any(named: 'value'),
          )).thenAnswer((_) async {});
      when(() => storage.delete(key: any(named: 'key')))
          .thenAnswer((_) async {});
    });

    test('storage key constant is the locked-in single-key value', () {
      expect(
        IapEntitlementService.entitlementStorageKey,
        'petcut_entitlement_token',
      );
    });

    test('grantFreeRetry writes JSON to the canonical key', () async {
      await service.grantFreeRetry(
        purchaseToken: 'GPA.token-A',
        productId: 'petcut_report_standard_v1',
      );

      final captured = verify(() => storage.write(
            key: IapEntitlementService.entitlementStorageKey,
            value: captureAny(named: 'value'),
          )).captured.single as String;

      final json = jsonDecode(captured) as Map<String, dynamic>;
      expect(json['purchaseToken'], 'GPA.token-A');
      expect(json['productId'], 'petcut_report_standard_v1');
      expect(json['consumed'], isFalse);
      // grantedAt should be a parseable ISO-8601 timestamp close to now.
      final grantedAt = DateTime.parse(json['grantedAt'] as String);
      expect(
        DateTime.now().difference(grantedAt).inSeconds.abs() <= 5,
        isTrue,
      );
    });

    test('grantFreeRetry returns the token it wrote', () async {
      final token = await service.grantFreeRetry(
        purchaseToken: 'GPA.token-B',
        productId: 'petcut_report_standard_v1',
      );

      expect(token.purchaseToken, 'GPA.token-B');
      expect(token.productId, 'petcut_report_standard_v1');
      expect(token.consumed, isFalse);
    });

    test('grantFreeRetry overwrites a prior token (E2 single-key policy)',
        () async {
      await service.grantFreeRetry(
        purchaseToken: 'GPA.first',
        productId: 'petcut_report_standard_v1',
      );
      await service.grantFreeRetry(
        purchaseToken: 'GPA.second',
        productId: 'petcut_report_standard_v1',
      );

      // Two writes to the same canonical key — no DELETE between them
      // (overwrite semantics, not delete-then-write).
      verify(() => storage.write(
            key: IapEntitlementService.entitlementStorageKey,
            value: any(named: 'value'),
          )).called(2);
      verifyNever(() => storage.delete(key: any(named: 'key')));
    });

    test('getActiveToken returns null when storage is empty', () async {
      when(() => storage.read(key: any(named: 'key')))
          .thenAnswer((_) async => null);

      expect(await service.getActiveToken(), isNull);
    });

    test('getActiveToken returns null on empty-string payload', () async {
      when(() => storage.read(key: any(named: 'key')))
          .thenAnswer((_) async => '');

      expect(await service.getActiveToken(), isNull);
    });

    test('getActiveToken parses and returns a valid stored token',
        () async {
      final stored = EntitlementToken(
        purchaseToken: 'GPA.token-X',
        productId: 'petcut_report_standard_v1',
        grantedAt: DateTime.utc(2026, 5, 1, 9, 30),
      );
      when(() => storage.read(key: any(named: 'key')))
          .thenAnswer((_) async => jsonEncode(stored.toJson()));

      final token = await service.getActiveToken();

      expect(token, isNotNull);
      expect(token!.purchaseToken, stored.purchaseToken);
      expect(token.productId, stored.productId);
      expect(token.grantedAt, stored.grantedAt);
      expect(token.consumed, isFalse);
    });

    test('getActiveToken self-heals on malformed JSON', () async {
      when(() => storage.read(key: any(named: 'key')))
          .thenAnswer((_) async => '{not valid json');

      final token = await service.getActiveToken();

      expect(token, isNull);
      // Self-heal: corrupt entry deleted so a future grant lands clean.
      verify(() => storage.delete(
            key: IapEntitlementService.entitlementStorageKey,
          )).called(1);
    });

    test('getActiveToken filters out tokens with consumed=true', () async {
      final consumed = EntitlementToken(
        purchaseToken: 'GPA.token',
        productId: 'petcut_report_standard_v1',
        grantedAt: DateTime.utc(2026, 5, 1, 9, 30),
        consumed: true,
      );
      when(() => storage.read(key: any(named: 'key')))
          .thenAnswer((_) async => jsonEncode(consumed.toJson()));

      expect(await service.getActiveToken(), isNull);
      // Filtering does NOT auto-delete a consumed=true entry — that's
      // a forward-compat surface, not corruption. Only malformed JSON
      // triggers self-heal.
      verifyNever(() => storage.delete(key: any(named: 'key')));
    });

    test('consumeToken deletes the canonical key', () async {
      await service.consumeToken();

      verify(() => storage.delete(
            key: IapEntitlementService.entitlementStorageKey,
          )).called(1);
    });

    test('clearAll deletes the canonical key', () async {
      await service.clearAll();

      verify(() => storage.delete(
            key: IapEntitlementService.entitlementStorageKey,
          )).called(1);
    });
  });
}
