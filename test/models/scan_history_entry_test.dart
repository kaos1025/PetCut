// test/models/scan_history_entry_test.dart
//
// PetCut — ScanHistoryEntry isPaidReport flag tests
// ----------------------------------------------------------------------------
// Sprint 2 Chunk 2a — verifies the new isPaidReport field round-trips
// through toJson/fromJson and that pre-Sprint-2 SharedPreferences entries
// (scan_history_v1) hydrate to false without migration.
// ----------------------------------------------------------------------------

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:petcut/models/scan_history_entry.dart';

void main() {
  group('ScanHistoryEntry constructor', () {
    test('defaults isPaidReport to false when not provided', () {
      final entry = ScanHistoryEntry(
        id: 'scan_1',
        scannedAt: DateTime.utc(2026, 5, 1, 12),
        productNames: const ['Kibble A'],
        overallStatus: 'perfect',
        conflictCount: 0,
        cautionCount: 0,
        petId: 'pet_1',
      );

      expect(entry.isPaidReport, isFalse);
    });

    test('accepts isPaidReport=true when explicitly set', () {
      final entry = ScanHistoryEntry(
        id: 'scan_2',
        scannedAt: DateTime.utc(2026, 5, 1, 12),
        productNames: const ['Kibble A'],
        overallStatus: 'caution',
        conflictCount: 1,
        cautionCount: 2,
        petId: 'pet_1',
        isPaidReport: true,
      );

      expect(entry.isPaidReport, isTrue);
    });
  });

  group('ScanHistoryEntry.toJson / fromJson round-trip', () {
    test('round-trips isPaidReport=false', () {
      final original = ScanHistoryEntry(
        id: 'scan_3',
        scannedAt: DateTime.utc(2026, 5, 1, 9, 30),
        productNames: const ['Kibble A', 'Supplement B'],
        overallStatus: 'caution',
        conflictCount: 1,
        cautionCount: 2,
        petId: 'pet_1',
      );

      final restored = ScanHistoryEntry.fromJson(original.toJson());

      expect(restored.isPaidReport, isFalse);
      expect(restored.id, original.id);
      expect(restored.scannedAt, original.scannedAt);
      expect(restored.productNames, original.productNames);
      expect(restored.overallStatus, original.overallStatus);
      expect(restored.conflictCount, original.conflictCount);
      expect(restored.cautionCount, original.cautionCount);
      expect(restored.petId, original.petId);
    });

    test('round-trips isPaidReport=true', () {
      final original = ScanHistoryEntry(
        id: 'scan_4',
        scannedAt: DateTime.utc(2026, 5, 1, 9, 30),
        productNames: const ['Kibble A'],
        overallStatus: 'warning',
        conflictCount: 0,
        cautionCount: 0,
        petId: 'pet_2',
        isPaidReport: true,
      );

      final restored = ScanHistoryEntry.fromJson(original.toJson());

      expect(restored.isPaidReport, isTrue);
    });

    test('toJson emits isPaidReport key', () {
      final entry = ScanHistoryEntry(
        id: 'scan_5',
        scannedAt: DateTime.utc(2026, 5, 1),
        productNames: const ['X'],
        overallStatus: 'perfect',
        conflictCount: 0,
        cautionCount: 0,
        petId: 'pet_1',
        isPaidReport: true,
      );

      final json = entry.toJson();

      expect(json.containsKey('isPaidReport'), isTrue);
      expect(json['isPaidReport'], isTrue);
    });
  });

  group('ScanHistoryEntry backward compatibility', () {
    test('hydrates legacy entry (no isPaidReport key) as false', () {
      // Pre-Sprint-2 SharedPreferences `scan_history_v1` entry shape —
      // isPaidReport key intentionally absent.
      final legacyJson = <String, dynamic>{
        'id': 'scan_legacy',
        'scannedAt': '2026-04-15T10:30:00.000Z',
        'productNames': ['Kibble A', 'Supplement B'],
        'overallStatus': 'caution',
        'conflictCount': 1,
        'cautionCount': 2,
        'petId': 'pet_1',
      };

      final entry = ScanHistoryEntry.fromJson(legacyJson);

      expect(entry.isPaidReport, isFalse);
      expect(entry.id, 'scan_legacy');
      expect(entry.overallStatus, 'caution');
    });

    test('hydrates legacy list payload (jsonDecode → fromJson) as false',
        () {
      // Simulates the exact ScanHistoryService.getAll() decode path:
      // SharedPreferences stores a JSON-encoded array of entry maps.
      const legacyRaw = '['
          '{"id":"scan_a","scannedAt":"2026-04-01T08:00:00.000Z",'
          '"productNames":["Old Kibble"],"overallStatus":"perfect",'
          '"conflictCount":0,"cautionCount":0,"petId":"pet_1"},'
          '{"id":"scan_b","scannedAt":"2026-04-10T08:00:00.000Z",'
          '"productNames":["Old Supplement"],"overallStatus":"warning",'
          '"conflictCount":2,"cautionCount":1,"petId":"pet_2"}'
          ']';

      final list = jsonDecode(legacyRaw) as List<dynamic>;
      final entries = list
          .map((e) => ScanHistoryEntry.fromJson(e as Map<String, dynamic>))
          .toList();

      expect(entries, hasLength(2));
      expect(entries.every((e) => e.isPaidReport == false), isTrue);
    });

    test('hydrates entry with explicit isPaidReport=null as false', () {
      // Defensive: a corrupted write could surface a literal null.
      final json = <String, dynamic>{
        'id': 'scan_null',
        'scannedAt': '2026-04-20T00:00:00.000Z',
        'productNames': <String>[],
        'overallStatus': 'perfect',
        'conflictCount': 0,
        'cautionCount': 0,
        'petId': 'pet_1',
        'isPaidReport': null,
      };

      final entry = ScanHistoryEntry.fromJson(json);

      expect(entry.isPaidReport, isFalse);
    });
  });
}
