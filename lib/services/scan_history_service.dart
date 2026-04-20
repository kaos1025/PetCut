import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/scan_history_entry.dart';

/// SharedPreferences 기반 스캔 히스토리 저장/조회.
///
/// 저장 포맷: `scan_history_v1` 키에 JSON 배열 문자열.
/// 최대 [_maxEntries]개까지 유지, 초과 시 오래된 엔트리부터 폐기.
class ScanHistoryService {
  static const _key = 'scan_history_v1';
  static const _maxEntries = 20;

  SharedPreferences? _prefs;

  Future<SharedPreferences> _getPrefs() async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }

  /// 저장된 모든 엔트리 조회 (scannedAt 내림차순, 최신 먼저).
  Future<List<ScanHistoryEntry>> getAll() async {
    final prefs = await _getPrefs();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      final entries = list
          .map((e) => ScanHistoryEntry.fromJson(e as Map<String, dynamic>))
          .toList();
      entries.sort((a, b) => b.scannedAt.compareTo(a.scannedAt));
      return entries;
    } catch (_) {
      return [];
    }
  }

  /// 새 엔트리를 리스트 앞에 추가 후 저장.
  /// 총 개수가 [_maxEntries] 초과 시 뒤쪽(가장 오래된) 엔트리 제거.
  Future<void> add(ScanHistoryEntry entry) async {
    final entries = await getAll();
    entries.insert(0, entry);
    if (entries.length > _maxEntries) {
      entries.removeRange(_maxEntries, entries.length);
    }
    await _persist(entries);
  }

  /// 전체 히스토리 삭제.
  Future<void> clear() async {
    final prefs = await _getPrefs();
    await prefs.remove(_key);
  }

  /// 최신순 상위 [limit]개 반환 (홈 화면은 3).
  Future<List<ScanHistoryEntry>> getRecent(int limit) async {
    if (limit <= 0) return const [];
    final entries = await getAll();
    if (limit >= entries.length) return entries;
    return entries.sublist(0, limit);
  }

  Future<void> _persist(List<ScanHistoryEntry> entries) async {
    final prefs = await _getPrefs();
    final json = jsonEncode(entries.map((e) => e.toJson()).toList());
    await prefs.setString(_key, json);
  }
}
