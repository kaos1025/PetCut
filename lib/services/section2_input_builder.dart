// lib/services/section2_input_builder.dart
//
// PetCut — §2 Combo Load Report Input Builder
// ----------------------------------------------------------------------------
// Assembles the Claude Sonnet prompt input JSON for §2 of the paid report.
//
// RESPONSIBILITY
// §2 presents the nutrient-level load analysis: total daily intake per
// nutrient, body-weight-normalized rates, safety thresholds with source
// attribution, and food-vs-supplement contribution breakdown.
//
// This builder does NOT re-calculate Gemini's numbers. It only:
//   1. Splits nutrients by status (elevated → detailed, safe → summary list)
//   2. Parses Gemini's `sources` string array into structured breakdown
//      (best-effort, with raw fallback)
//   3. Computes per_kg_body_weight when Gemini doesn't provide it AND
//      the unit is convertible
//   4. Aggregates status counts for the summary block
//
// The returned Map is injected into the §2 Claude prompt. See
// docs/prompts/section_2_combo_load_report.md for the prompt structure.
//
// Version: v0.1
// Last updated: 2026-04-21
// ----------------------------------------------------------------------------

import '../models/pet_profile.dart';
import '../models/petcut_analysis_result.dart';

class Section2InputBuilder {
  Section2InputBuilder._();

  // --------------------------------------------------------------------------
  // Status classification
  // --------------------------------------------------------------------------
  static const Set<String> _elevatedStatuses = {
    'caution',
    'warning',
    'critical',
  };

  static const String _safeStatus = 'safe';

  // --------------------------------------------------------------------------
  // Public API
  // --------------------------------------------------------------------------

  /// Assembles the §2 input block for the Claude Sonnet prompt.
  static Map<String, dynamic> build({
    required PetcutAnalysisResult geminiResult,
    required PetProfile pet,
  }) {
    final allNutrients = geminiResult.comboAnalysis.nutrientTotals;

    // Step 1: Split by status.
    final detailedSource = <NutrientTotal>[];
    final safeSource = <NutrientTotal>[];
    final unknownSource = <NutrientTotal>[];

    for (final n in allNutrients) {
      if (_elevatedStatuses.contains(n.status)) {
        detailedSource.add(n);
      } else if (n.status == _safeStatus) {
        safeSource.add(n);
      } else {
        // Unknown status — treat conservatively as detailed.
        unknownSource.add(n);
      }
    }

    // Step 2: Build detailed nutrient entries.
    final detailedJson = [
      ...detailedSource.map((n) => _buildDetailedEntry(n, pet)),
      ...unknownSource.map((n) => _buildDetailedEntry(n, pet)),
    ];

    // Step 3: Build safe nutrient summary entries.
    final safeJson = safeSource
        .map((n) => <String, dynamic>{
              'nutrient': n.nutrient,
              'display_name': _humanizeNutrientName(n.nutrient),
            })
        .toList();

    // Step 4: Aggregate counts.
    final summary = _buildSummary(
      allNutrients: allNutrients,
      overallStatus: geminiResult.overallStatus,
    );

    return <String, dynamic>{
      'section': 'combo_load_report',
      'pet': <String, dynamic>{
        'name': pet.name,
        'species': _speciesToString(pet.species),
        'life_stage': _lifeStageToString(pet.lifeStage),
        'weight_kg': pet.weightKg,
      },
      'summary': summary,
      'detailed_nutrients': detailedJson,
      'safe_nutrients': safeJson,
      'has_any_concerns': detailedJson.isNotEmpty,
    };
  }

  // --------------------------------------------------------------------------
  // Detailed entry builder
  // --------------------------------------------------------------------------
  static Map<String, dynamic> _buildDetailedEntry(
    NutrientTotal nutrient,
    PetProfile pet,
  ) {
    // Parse source_breakdown from Gemini's string array.
    final parsed = _parseSourceBreakdown(
      sources: nutrient.sources,
      totalAmount: nutrient.totalDailyIntake,
      fallbackUnit: nutrient.unit,
    );

    // Compute per-kg body weight representation.
    final perKgBW = _computePerKgBodyWeight(
      totalAmount: nutrient.totalDailyIntake,
      totalUnit: nutrient.unit,
      petWeightKg: pet.weightKg,
    );

    return <String, dynamic>{
      'nutrient': nutrient.nutrient,
      'display_name': _humanizeNutrientName(nutrient.nutrient),
      'status': nutrient.status,
      'total_daily_intake': <String, dynamic>{
        'amount': nutrient.totalDailyIntake,
        'unit': nutrient.unit,
      },
      'per_kg_body_weight': perKgBW,
      'safe_upper_limit': <String, dynamic>{
        'amount': nutrient.safeUpperLimit,
        'unit': nutrient.unit,
        'source': nutrient.safeUpperLimitSource,
      },
      'percent_of_limit': nutrient.percentOfLimit,
      'source_breakdown': parsed['structured'],
      'raw_sources_string': parsed['raw'],
    };
  }

  // --------------------------------------------------------------------------
  // Source breakdown parser
  //
  // Gemini v0.4 provides `sources` as List<String> like:
  //   "Blue Buffalo Senior: 502.8 IU"
  //   "Zesty Paws 8-in-1 Multi: 500 IU"
  //
  // Returns { 'structured': List<Map>|[], 'raw': String|null }.
  // On full parse success: structured populated, raw is null.
  // On partial failure: structured contains only parsed entries; if no
  //   entries parsed, returns { structured: [], raw: joined-original }.
  // --------------------------------------------------------------------------
  static Map<String, dynamic> _parseSourceBreakdown({
    required List<String> sources,
    required double totalAmount,
    required String fallbackUnit,
  }) {
    if (sources.isEmpty) {
      return <String, dynamic>{
        'structured': <Map<String, dynamic>>[],
        'raw': null,
      };
    }

    final structured = <Map<String, dynamic>>[];
    final failedOriginals = <String>[];

    for (final raw in sources) {
      final entry = _parseSingleSource(raw, fallbackUnit);
      if (entry != null) {
        structured.add(entry);
      } else {
        failedOriginals.add(raw);
      }
    }

    // Compute percent_of_total for successfully-parsed entries.
    if (structured.isNotEmpty && totalAmount > 0) {
      for (final entry in structured) {
        final amount = entry['amount'] as double;
        entry['percent_of_total'] =
            _roundTo1Decimal((amount / totalAmount) * 100);
      }
    }

    // If nothing parsed, return raw joined string as fallback.
    if (structured.isEmpty) {
      return <String, dynamic>{
        'structured': <Map<String, dynamic>>[],
        'raw': sources.join(', '),
      };
    }

    return <String, dynamic>{
      'structured': structured,
      'raw': failedOriginals.isEmpty ? null : failedOriginals.join(', '),
    };
  }

  /// Parses a single source string into {product_name, amount, unit}.
  /// Returns null if parsing fails.
  static Map<String, dynamic>? _parseSingleSource(
    String source,
    String fallbackUnit,
  ) {
    // Find first ':' (product names may contain colons).
    final colonIdx = source.indexOf(':');
    if (colonIdx <= 0 || colonIdx == source.length - 1) return null;

    final productName = source.substring(0, colonIdx).trim();
    final remainder = source.substring(colonIdx + 1).trim();
    if (productName.isEmpty || remainder.isEmpty) return null;

    // Remove commas (e.g. "1,500" → "1500").
    final cleaned = remainder.replaceAll(',', '');

    // Split by whitespace: first token is amount, rest is unit.
    final tokens = cleaned.split(RegExp(r'\s+'));
    if (tokens.isEmpty) return null;

    final amount = double.tryParse(tokens.first);
    if (amount == null) return null;

    final unit = tokens.length > 1 ? tokens.sublist(1).join(' ') : fallbackUnit;

    return <String, dynamic>{
      'product_name': productName,
      'amount': amount,
      'unit': unit,
    };
  }

  // --------------------------------------------------------------------------
  // Per-kg body weight computation
  //
  // Returns null amount when unit is not convertible (percentage, per-kg-food,
  // etc.) or pet weight is invalid.
  // --------------------------------------------------------------------------
  static Map<String, dynamic> _computePerKgBodyWeight({
    required double totalAmount,
    required String totalUnit,
    required double petWeightKg,
  }) {
    final unitType = _classifyUnit(totalUnit);

    // Already per-kg BW — pass through.
    if (unitType == _UnitType.perKgBodyWeight) {
      return <String, dynamic>{
        'amount': totalAmount,
        'unit': totalUnit,
      };
    }

    // Convertible units: compute.
    if ((unitType == _UnitType.simpleMass || unitType == _UnitType.simpleIU) &&
        petWeightKg > 0) {
      final perKg = _roundTo1Decimal(totalAmount / petWeightKg);
      return <String, dynamic>{
        'amount': perKg,
        'unit': '$totalUnit/kg BW/day',
      };
    }

    // Non-convertible (percentage, per-kg-food, unknown) or invalid weight.
    return <String, dynamic>{
      'amount': null,
      'unit': 'unit not convertible to per-kg BW',
    };
  }

  static _UnitType _classifyUnit(String unit) {
    final normalized = unit.toLowerCase().trim();

    if (normalized.contains('/kg bw') || normalized.contains('kg body')) {
      return _UnitType.perKgBodyWeight;
    }
    if (normalized.contains('/kg food') ||
        normalized.contains('/kg dm') ||
        normalized.contains('kg dm')) {
      return _UnitType.perKgFood;
    }
    if (normalized == '%' || normalized.contains('percent')) {
      return _UnitType.percentage;
    }
    if (normalized == 'iu' || normalized.contains('iu ')) {
      return _UnitType.simpleIU;
    }
    const massUnits = {'mg', 'g', 'mcg', 'kg', 'µg', 'ug'};
    if (massUnits.contains(normalized)) {
      return _UnitType.simpleMass;
    }

    return _UnitType.unknown;
  }

  // --------------------------------------------------------------------------
  // Summary counts
  // --------------------------------------------------------------------------
  static Map<String, dynamic> _buildSummary({
    required List<NutrientTotal> allNutrients,
    required String overallStatus,
  }) {
    var safeCount = 0;
    var cautionCount = 0;
    var warningCount = 0;
    var criticalCount = 0;

    for (final n in allNutrients) {
      switch (n.status) {
        case 'safe':
          safeCount++;
          break;
        case 'caution':
          cautionCount++;
          break;
        case 'warning':
          warningCount++;
          break;
        case 'critical':
          criticalCount++;
          break;
        default:
          // Unknown statuses counted conservatively with caution.
          cautionCount++;
      }
    }

    return <String, dynamic>{
      'total_tracked': allNutrients.length,
      'safe_count': safeCount,
      'caution_count': cautionCount,
      'warning_count': warningCount,
      'critical_count': criticalCount,
      'overall_status': overallStatus,
    };
  }

  // --------------------------------------------------------------------------
  // Nutrient name humanization
  // --------------------------------------------------------------------------
  static const Map<String, String> _nutrientDisplayNames = {
    'vitamin_d3': 'Vitamin D3',
    'iron': 'Iron',
    'calcium': 'Calcium',
    'zinc': 'Zinc',
    'copper': 'Copper',
    'phosphorus': 'Phosphorus',
    'vitamin_a': 'Vitamin A',
    'vitamin_e': 'Vitamin E',
    'magnesium': 'Magnesium',
    'selenium': 'Selenium',
  };

  static String _humanizeNutrientName(String key) {
    final preset = _nutrientDisplayNames[key];
    if (preset != null) return preset;

    // Fallback: title-case underscores to spaces.
    return key
        .split('_')
        .map((word) => word.isEmpty
            ? word
            : '${word[0].toUpperCase()}${word.substring(1)}')
        .join(' ');
  }

  // --------------------------------------------------------------------------
  // Serialization helpers
  // --------------------------------------------------------------------------
  static String _speciesToString(Species species) {
    switch (species) {
      case Species.dog:
        return 'dog';
      case Species.cat:
        return 'cat';
    }
  }

  static String _lifeStageToString(LifeStage lifeStage) {
    switch (lifeStage) {
      case LifeStage.puppy:
        return 'puppy';
      case LifeStage.adult:
        return 'adult';
      case LifeStage.senior:
        return 'senior';
      case LifeStage.kitten:
        return 'kitten';
      case LifeStage.adultCat:
        return 'adult';
      case LifeStage.seniorCat:
        return 'senior';
    }
  }

  static double _roundTo1Decimal(double value) {
    return (value * 10).roundToDouble() / 10;
  }
}

/// Internal unit classification for per-kg-BW computability.
enum _UnitType {
  simpleMass,
  simpleIU,
  perKgFood,
  perKgBodyWeight,
  percentage,
  unknown,
}
