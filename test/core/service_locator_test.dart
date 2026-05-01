// test/core/service_locator_test.dart
//
// PetCut — service_locator boot-time sanity checks
// ----------------------------------------------------------------------------
// Sprint 2 Chunk 6 — verifies that setupServiceLocator() registers every
// IAP-related service plus the FlutterSecureStorage dependency, in the order
// implied by the lazy resolution chain.
//
// The tests deliberately stop at `isRegistered` rather than resolving the
// services. Resolving IapBillingService would touch InAppPurchase.instance,
// which sets up a platform channel listener and is not appropriate in a
// pure unit test environment.
// ----------------------------------------------------------------------------

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petcut/core/service_locator.dart';
import 'package:petcut/services/iap_billing_service.dart';
import 'package:petcut/services/iap_entitlement_service.dart';
import 'package:petcut/services/report_purchase_orchestrator.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  tearDown(() async {
    await getIt.reset();
  });

  group('setupServiceLocator — Sprint 2 IAP wiring', () {
    test('registers FlutterSecureStorage and the three IAP services',
        () async {
      await setupServiceLocator();

      expect(getIt.isRegistered<FlutterSecureStorage>(), isTrue);
      expect(getIt.isRegistered<IapBillingService>(), isTrue);
      expect(getIt.isRegistered<IapEntitlementService>(), isTrue);
      expect(getIt.isRegistered<ReportPurchaseOrchestrator>(), isTrue);
    });

    test('is idempotent across repeated calls (hot-restart support)',
        () async {
      await setupServiceLocator();
      await setupServiceLocator();

      expect(getIt.isRegistered<FlutterSecureStorage>(), isTrue);
      expect(getIt.isRegistered<IapBillingService>(), isTrue);
      expect(getIt.isRegistered<IapEntitlementService>(), isTrue);
      expect(getIt.isRegistered<ReportPurchaseOrchestrator>(), isTrue);
    });
  });
}
