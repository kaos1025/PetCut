// test/services/scan_history_service_test.dart
//
// PetCut — ScanHistoryService.markAsPaid tests
// ----------------------------------------------------------------------------
// Sprint 2 Chunk 6 (Chunk 5 note 2 followup). Backfills dedicated unit
// coverage for the markAsPaid method that ReportPurchaseOrchestrator depends
// on. Validates the read-mutate-persist pattern end-to-end against the
// shared_preferences mock.
// ----------------------------------------------------------------------------

import 'package:flutter_test/flutter_test.dart';
import 'package:petcut/models/scan_history_entry.dart';
import 'package:petcut/services/scan_history_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

ScanHistoryEntry _entry({
  required String id,
  DateTime? scannedAt,
  List<String> productNames = const ['Kibble'],
  String overallStatus = 'perfect',
  int conflictCount = 0,
  int cautionCount = 0,
  String petId = 'pet_1',
  bool isPaidReport = false,
}) {
  return ScanHistoryEntry(
    id: id,
    scannedAt: scannedAt ?? DateTime.utc(2026, 5, 1, 9),
    productNames: productNames,
    overallStatus: overallStatus,
    conflictCount: conflictCount,
    cautionCount: cautionCount,
    petId: petId,
    isPaidReport: isPaidReport,
  );
}

void main() {
  late ScanHistoryService service;

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    service = ScanHistoryService();
  });

  group('ScanHistoryService.markAsPaid', () {
    test('flips isPaidReport to true for the matching scanId', () async {
      await service.add(_entry(id: 'scan_X'));

      await service.markAsPaid('scan_X');

      final entries = await service.getAll();
      expect(entries, hasLength(1));
      expect(entries.single.id, 'scan_X');
      expect(entries.single.isPaidReport, isTrue);
    });

    test('is a no-op when scanId is not found (best-effort)', () async {
      await service.add(_entry(id: 'scan_X'));

      // Different id — should silently no-op, not throw.
      await service.markAsPaid('scan_other');

      final entries = await service.getAll();
      expect(entries.single.isPaidReport, isFalse);
    });

    test(
      'updates only the matching entry; siblings keep their fields',
      () async {
        await service.add(_entry(
          id: 'scan_A',
          scannedAt: DateTime.utc(2026, 5, 1, 9),
          productNames: ['Food A'],
          overallStatus: 'perfect',
        ));
        await service.add(_entry(
          id: 'scan_B',
          scannedAt: DateTime.utc(2026, 5, 1, 10),
          productNames: ['Food B', 'Supp B'],
          overallStatus: 'caution',
          conflictCount: 1,
          cautionCount: 2,
        ));

        await service.markAsPaid('scan_A');

        final entries = await service.getAll();
        final a = entries.firstWhere((e) => e.id == 'scan_A');
        final b = entries.firstWhere((e) => e.id == 'scan_B');

        expect(a.isPaidReport, isTrue);
        expect(a.productNames, ['Food A']);
        expect(a.overallStatus, 'perfect');

        expect(b.isPaidReport, isFalse);
        expect(b.productNames, ['Food B', 'Supp B']);
        expect(b.overallStatus, 'caution');
        expect(b.conflictCount, 1);
        expect(b.cautionCount, 2);
      },
    );
  });
}
