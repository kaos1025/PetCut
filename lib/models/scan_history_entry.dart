/// 홈 화면 Recent 섹션과 향후 히스토리 화면에서 사용할 최소 단위 스캔 기록.
///
/// Gemini 분석이 끝난 직후 호출부가 id를 생성해 넘긴다
/// (예: `'scan_${DateTime.now().millisecondsSinceEpoch}'`).
class ScanHistoryEntry {
  final String id;
  final DateTime scannedAt;
  final List<String> productNames;
  final String overallStatus;
  final int conflictCount;
  final int cautionCount;
  final String petId;

  /// Whether the user has unlocked the paid Claude detailed report for this
  /// scan. Defaults to false so legacy `scan_history_v1` entries hydrate
  /// without migration.
  final bool isPaidReport;

  const ScanHistoryEntry({
    required this.id,
    required this.scannedAt,
    required this.productNames,
    required this.overallStatus,
    required this.conflictCount,
    required this.cautionCount,
    required this.petId,
    this.isPaidReport = false,
  });

  factory ScanHistoryEntry.fromJson(Map<String, dynamic> json) {
    return ScanHistoryEntry(
      id: json['id'] as String? ?? '',
      scannedAt: DateTime.tryParse(json['scannedAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      productNames:
          (json['productNames'] as List?)?.cast<String>() ?? const <String>[],
      overallStatus: json['overallStatus'] as String? ?? 'perfect',
      conflictCount: (json['conflictCount'] as num?)?.toInt() ?? 0,
      cautionCount: (json['cautionCount'] as num?)?.toInt() ?? 0,
      petId: json['petId'] as String? ?? '',
      isPaidReport: json['isPaidReport'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'scannedAt': scannedAt.toIso8601String(),
        'productNames': productNames,
        'overallStatus': overallStatus,
        'conflictCount': conflictCount,
        'cautionCount': cautionCount,
        'petId': petId,
        'isPaidReport': isPaidReport,
      };
}
