// test/services/iap_billing_service_test.dart
//
// PetCut — IapBillingService unit tests
// ----------------------------------------------------------------------------
// Sprint 2 Chunk 3 — verifies the Pattern D safety net at the service
// layer:
//   1. queryProductDetails delegates to the platform with the canonical
//      product-ID set.
//   2. buyConsumable always passes `autoConsume: false`.
//   3. purchaseStream is a pass-through and the service does NOT
//      subscribe internally — even a `purchased` event must not trigger
//      completePurchase implicitly.
//   4. consume() is the only path that calls completePurchase.
//
// Fixtures in `test/fixtures/iap/` document the four PurchaseStatus
// shapes a real Google Play stream would emit; we lift them through a
// loader helper so the tests stay readable and the JSON keeps living
// next to the test that consumes it.
// ----------------------------------------------------------------------------

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:mocktail/mocktail.dart';
import 'package:petcut/constants/iap_product_ids.dart';
import 'package:petcut/services/iap_billing_service.dart';

class _MockInAppPurchase extends Mock implements InAppPurchase {}

class _MockProductDetails extends Mock implements ProductDetails {}

class _FakePurchaseParam extends Fake implements PurchaseParam {}

class _FakePurchaseDetails extends Fake implements PurchaseDetails {}

PurchaseDetails _purchaseFromFixture(Map<String, dynamic> j) {
  final statusName = j['status'] as String;
  final status = PurchaseStatus.values.firstWhere(
    (s) => s.name == statusName,
    orElse: () =>
        throw ArgumentError('unknown PurchaseStatus in fixture: $statusName'),
  );
  final verification = j['verificationData'] as Map<String, dynamic>;

  final details = PurchaseDetails(
    purchaseID: j['purchaseID'] as String?,
    productID: j['productID'] as String,
    verificationData: PurchaseVerificationData(
      localVerificationData: verification['localVerificationData'] as String,
      serverVerificationData: verification['serverVerificationData'] as String,
      source: verification['source'] as String,
    ),
    transactionDate: j['transactionDate'] as String?,
    status: status,
  )..pendingCompletePurchase = j['pendingCompletePurchase'] as bool? ?? false;

  final errorJson = j['error'];
  if (errorJson is Map<String, dynamic>) {
    details.error = IAPError(
      source: errorJson['source'] as String,
      code: errorJson['code'] as String,
      message: errorJson['message'] as String,
      details: errorJson['details'],
    );
  }
  return details;
}

Map<String, dynamic> _loadFixture(String name) {
  final raw = File('test/fixtures/iap/$name').readAsStringSync();
  return jsonDecode(raw) as Map<String, dynamic>;
}

void main() {
  setUpAll(() {
    registerFallbackValue(_FakePurchaseParam());
    registerFallbackValue(_FakePurchaseDetails());
    registerFallbackValue(<String>{});
  });

  late _MockInAppPurchase mockIap;
  late IapBillingService service;

  setUp(() {
    mockIap = _MockInAppPurchase();
    service = IapBillingService(iap: mockIap);
  });

  group('product ID constants', () {
    test('petcutReportStandardV1 matches Google Play SKU exactly', () {
      // Outstanding purchases reference this string verbatim — any
      // edit must be coordinated with a Console-side rename.
      expect(petcutReportStandardV1, 'petcut_report_standard_v1');
    });

    test('kPetcutIapProductIds contains the standard SKU', () {
      expect(kPetcutIapProductIds, contains(petcutReportStandardV1));
      expect(kPetcutIapProductIds, hasLength(1));
    });
  });

  group('queryProductDetails', () {
    test('delegates to InAppPurchase with kPetcutIapProductIds', () async {
      when(() => mockIap.queryProductDetails(any())).thenAnswer(
        (_) async => ProductDetailsResponse(
          productDetails: const <ProductDetails>[],
          notFoundIDs: const <String>[],
        ),
      );

      await service.queryProductDetails();

      verify(() => mockIap.queryProductDetails(kPetcutIapProductIds))
          .called(1);
    });

    test('returns the platform response verbatim on success', () async {
      final product = _MockProductDetails();
      final response = ProductDetailsResponse(
        productDetails: <ProductDetails>[product],
        notFoundIDs: const <String>[],
      );
      when(() => mockIap.queryProductDetails(any()))
          .thenAnswer((_) async => response);

      final result = await service.queryProductDetails();

      expect(result, same(response));
      expect(result.productDetails, hasLength(1));
      expect(result.notFoundIDs, isEmpty);
    });

    test('preserves notFoundIDs from the platform response', () async {
      when(() => mockIap.queryProductDetails(any())).thenAnswer(
        (_) async => ProductDetailsResponse(
          productDetails: const <ProductDetails>[],
          notFoundIDs: const <String>[petcutReportStandardV1],
        ),
      );

      final result = await service.queryProductDetails();

      expect(result.notFoundIDs, [petcutReportStandardV1]);
      expect(result.productDetails, isEmpty);
    });

    test('returns an empty productDetails list when nothing is found',
        () async {
      when(() => mockIap.queryProductDetails(any())).thenAnswer(
        (_) async => ProductDetailsResponse(
          productDetails: const <ProductDetails>[],
          notFoundIDs: const <String>[],
        ),
      );

      final result = await service.queryProductDetails();

      expect(result.productDetails, isEmpty);
    });
  });

  group('buyConsumable', () {
    late ProductDetails product;

    setUp(() {
      product = _MockProductDetails();
      when(() => mockIap.buyConsumable(
            purchaseParam: any(named: 'purchaseParam'),
            autoConsume: any(named: 'autoConsume'),
          )).thenAnswer((_) async => true);
    });

    test('wraps the supplied ProductDetails into a PurchaseParam',
        () async {
      await service.buyConsumable(product);

      final captured = verify(() => mockIap.buyConsumable(
            purchaseParam: captureAny(named: 'purchaseParam'),
            autoConsume: any(named: 'autoConsume'),
          )).captured.single as PurchaseParam;

      expect(captured.productDetails, same(product));
      expect(captured.applicationUserName, isNull);
    });

    test('★ Pattern D: always passes autoConsume: false', () async {
      await service.buyConsumable(product);

      verify(() => mockIap.buyConsumable(
            purchaseParam: any(named: 'purchaseParam'),
            autoConsume: false,
          )).called(1);
      verifyNever(() => mockIap.buyConsumable(
            purchaseParam: any(named: 'purchaseParam'),
            autoConsume: true,
          ));
    });

    test('returns the bool reported by the platform', () async {
      when(() => mockIap.buyConsumable(
            purchaseParam: any(named: 'purchaseParam'),
            autoConsume: any(named: 'autoConsume'),
          )).thenAnswer((_) async => false);

      final ok = await service.buyConsumable(product);

      expect(ok, isFalse);
    });
  });

  group('purchaseStream pass-through', () {
    test('delegates to InAppPurchase.purchaseStream', () {
      // Stream identity is implementation-defined for broadcast streams
      // (Dart wraps `controller.stream` into a fresh _ControllerStream
      // on each access). What matters here is that the service forwards
      // the getter — observable equivalence is covered by the
      // emit-and-verify tests below.
      final controller = StreamController<List<PurchaseDetails>>.broadcast();
      addTearDown(controller.close);
      when(() => mockIap.purchaseStream).thenAnswer((_) => controller.stream);

      final exposed = service.purchaseStream;

      expect(exposed, isA<Stream<List<PurchaseDetails>>>());
      verify(() => mockIap.purchaseStream).called(1);
    });

    test(
      '★ Pattern D: a "purchased" event does NOT trigger completePurchase',
      () async {
        // The service must never subscribe internally. We assert this
        // by emitting the success fixture through the stream and
        // verifying completePurchase was never reached, even when the
        // service was wired up and its purchaseStream getter accessed.
        final controller =
            StreamController<List<PurchaseDetails>>.broadcast();
        addTearDown(controller.close);
        when(() => mockIap.purchaseStream)
            .thenAnswer((_) => controller.stream);
        when(() => mockIap.completePurchase(any()))
            .thenAnswer((_) async {});

        // Touch the getter — this is what main() would do at app boot.
        final stream = service.purchaseStream;
        expect(stream, isNotNull);

        final purchase =
            _purchaseFromFixture(_loadFixture('purchase_success.json'));
        controller.add([purchase]);

        // Give the stream a tick to deliver — there should be no
        // listener inside the service, but we wait to be sure.
        await Future<void>.delayed(Duration.zero);

        verifyNever(() => mockIap.completePurchase(any()));
      },
    );

    test('exposes every PurchaseStatus shape unchanged through the stream',
        () async {
      final controller = StreamController<List<PurchaseDetails>>.broadcast();
      addTearDown(controller.close);
      when(() => mockIap.purchaseStream).thenAnswer((_) => controller.stream);
      when(() => mockIap.completePurchase(any()))
          .thenAnswer((_) async {});

      final received = <PurchaseStatus>[];
      final sub = service.purchaseStream.listen((events) {
        for (final e in events) {
          received.add(e.status);
        }
      });
      addTearDown(sub.cancel);

      controller.add(<PurchaseDetails>[
        _purchaseFromFixture(_loadFixture('purchase_pending.json')),
        _purchaseFromFixture(_loadFixture('purchase_success.json')),
        _purchaseFromFixture(_loadFixture('purchase_canceled.json')),
        _purchaseFromFixture(_loadFixture('purchase_error.json')),
      ]);

      await Future<void>.delayed(Duration.zero);

      expect(received, <PurchaseStatus>[
        PurchaseStatus.pending,
        PurchaseStatus.purchased,
        PurchaseStatus.canceled,
        PurchaseStatus.error,
      ]);

      // The error fixture also surfaces an IAPError untouched.
      final errorPurchase = _purchaseFromFixture(
        _loadFixture('purchase_error.json'),
      );
      expect(errorPurchase.error?.source, 'google_play');
      expect(errorPurchase.error?.code, 'BillingResponse.serviceUnavailable');

      // ★ Pattern D — even after surfacing four events including
      // PurchaseStatus.purchased, the service still never auto-consumed.
      verifyNever(() => mockIap.completePurchase(any()));
    });
  });

  group('consume', () {
    test('forwards the purchase to InAppPurchase.completePurchase',
        () async {
      when(() => mockIap.completePurchase(any()))
          .thenAnswer((_) async {});

      final purchase =
          _purchaseFromFixture(_loadFixture('purchase_success.json'));
      await service.consume(purchase);

      verify(() => mockIap.completePurchase(purchase)).called(1);
    });

    test('forwards every call (no in-memory dedup state)', () async {
      // Pattern D semantics: the service is stateless. The platform is
      // already idempotent at the SKU level, so we deliberately do not
      // add an in-memory cache that would break across app restarts.
      // Calling consume twice must reach the platform twice.
      when(() => mockIap.completePurchase(any()))
          .thenAnswer((_) async {});

      final purchase =
          _purchaseFromFixture(_loadFixture('purchase_success.json'));
      await service.consume(purchase);
      await service.consume(purchase);

      verify(() => mockIap.completePurchase(purchase)).called(2);
    });

    test('propagates platform exceptions verbatim', () async {
      final boom = Exception('billing client disconnected');
      when(() => mockIap.completePurchase(any())).thenThrow(boom);

      final purchase =
          _purchaseFromFixture(_loadFixture('purchase_success.json'));

      await expectLater(
        () => service.consume(purchase),
        throwsA(same(boom)),
      );
    });
  });

  group('fixtures', () {
    test('purchase_success carries pendingCompletePurchase=true', () {
      final p = _purchaseFromFixture(_loadFixture('purchase_success.json'));
      expect(p.status, PurchaseStatus.purchased);
      expect(p.pendingCompletePurchase, isTrue);
      expect(p.productID, petcutReportStandardV1);
    });

    test('purchase_error carries an IAPError payload', () {
      final p = _purchaseFromFixture(_loadFixture('purchase_error.json'));
      expect(p.status, PurchaseStatus.error);
      expect(p.error, isNotNull);
      expect(p.error!.message,
          'Unable to connect to the billing service');
    });
  });

  group('restorePurchases (Sprint 2 Chunk 6.5)', () {
    test('delegates to InAppPurchase.restorePurchases', () async {
      when(() => mockIap.restorePurchases())
          .thenAnswer((_) async {});

      await service.restorePurchases();

      verify(() => mockIap.restorePurchases()).called(1);
    });

    test(
      '★ Pattern D: a "restored" event does NOT trigger completePurchase',
      () async {
        // The same invariant proven for "purchased" events also holds
        // for "restored": the service has no internal subscriber, so
        // replaying an unconsumed purchase from a prior session cannot
        // implicitly call completePurchase.
        final controller =
            StreamController<List<PurchaseDetails>>.broadcast();
        addTearDown(controller.close);
        when(() => mockIap.purchaseStream)
            .thenAnswer((_) => controller.stream);
        when(() => mockIap.restorePurchases())
            .thenAnswer((_) async {});
        when(() => mockIap.completePurchase(any()))
            .thenAnswer((_) async {});

        // Touch the getter as an external listener would.
        final stream = service.purchaseStream;
        expect(stream, isNotNull);

        await service.restorePurchases();

        // Simulate the platform replaying a previously unconsumed
        // purchase as `restored`.
        final restored = PurchaseDetails(
          purchaseID: 'GPA.restored-token',
          productID: petcutReportStandardV1,
          verificationData: PurchaseVerificationData(
            localVerificationData: 'local',
            serverVerificationData: 'server',
            source: 'google_play',
          ),
          transactionDate: '1714000000000',
          status: PurchaseStatus.restored,
        )..pendingCompletePurchase = true;
        controller.add([restored]);

        await Future<void>.delayed(Duration.zero);

        verifyNever(() => mockIap.completePurchase(any()));
      },
    );

    test('completes gracefully when the platform replays nothing',
        () async {
      when(() => mockIap.restorePurchases()).thenAnswer((_) async {});

      // Method is Future<void>; success is "did not throw".
      await expectLater(service.restorePurchases(), completes);
    });
  });
}
