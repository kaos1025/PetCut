// lib/services/section3_input_builder.dart
//
// PetCut — §3 Mechanism & Interaction Alerts Input Builder
// ----------------------------------------------------------------------------
// Assembles the Claude Sonnet prompt input JSON for §3 of the paid report.
//
// RESPONSIBILITY
// §3 explains WHY specific ingredient combinations create risk — the
// biological mechanisms behind the alerts. It integrates two Gemini
// output sources:
//   1. combo_analysis.mechanism_conflicts (5 conflict types)
//   2. products[].flagged_ingredients (6 reasons)
//
// This builder:
//   1. Groups flagged_ingredients with their matching mechanism_conflicts
//      by conflict_type (via ingredient alias matching)
//   2. Separates "orphan" flagged_ingredients (life_stage_mismatch,
//      allergen, drug_interaction) into standalone_flags
//   3. Provides display_name mapping for each conflict_type
//   4. Preserves Gemini's severity and explanation verbatim
//
// The builder does NOT re-analyze mechanisms. It only translates Gemini's
// output structure into a form optimized for the §3 Claude prompt.
//
// Version: v0.1
// Last updated: 2026-04-21
// ----------------------------------------------------------------------------

import '../models/pet_profile.dart';
import '../models/petcut_analysis_result.dart';

class Section3InputBuilder {
  Section3InputBuilder._();

  // --------------------------------------------------------------------------
  // Conflict type → display name mapping
  // --------------------------------------------------------------------------
  static const Map<String, String> _conflictDisplayNames = {
    'hemolytic_risk': 'Hemolytic Risk from Allium Ingredients',
    'anticoagulant_stacking': 'Anticoagulant Stacking Risk',
    'thyroid_disruption': 'Thyroid Disruption from Multiple Iodine Sources',
    'hepatotoxic_combo': 'Hepatotoxic Combination',
    'calcium_phosphorus_imbalance': 'Calcium-Phosphorus Ratio Imbalance',
  };

  // --------------------------------------------------------------------------
  // Ingredient alias sets for mechanism matching
  // --------------------------------------------------------------------------
  static const List<String> _alliumAliases = [
    'garlic',
    'onion',
    'chives',
    'leek',
    'shallot',
    'allium',
  ];

  static const List<String> _hepatotoxicAliases = [
    'comfrey',
    'pennyroyal',
    'kava',
    'germander',
    'black cohosh',
    'chaparral',
    'greater celandine',
  ];

  static const List<String> _anticoagulantAliases = [
    'fish oil',
    'omega-3',
    'omega 3',
    'ginkgo',
    'ginseng',
    'turmeric',
    'curcumin',
    'vitamin e',
  ];

  // --------------------------------------------------------------------------
  // Orphan flag reasons — not tied to any mechanism_conflict
  // --------------------------------------------------------------------------
  static const Set<String> _orphanFlagReasons = {
    'life_stage_mismatch',
    'allergen',
    'drug_interaction',
  };

  // --------------------------------------------------------------------------
  // Public API
  // --------------------------------------------------------------------------

  /// Assembles the §3 input block for the Claude Sonnet prompt.
  static Map<String, dynamic> build({
    required PetcutAnalysisResult geminiResult,
    required PetProfile pet,
  }) {
    final mechanismConflicts = geminiResult.comboAnalysis.mechanismConflicts;
    final allFlags = <_FlagWithProduct>[];
    for (final product in geminiResult.products) {
      for (final flag in product.flaggedIngredients) {
        allFlags.add(
            _FlagWithProduct(flag: flag, productName: product.productName));
      }
    }

    // Step 1: Build alert_groups by integrating mechanism_conflicts with
    // their matching flagged_ingredients.
    final usedFlags = <_FlagWithProduct>{};
    final alertGroupsJson = mechanismConflicts.map((conflict) {
      final relatedFlags = _findRelatedFlags(
        conflictType: conflict.conflictType,
        allFlags: allFlags,
        usedFlags: usedFlags,
      );

      return <String, dynamic>{
        'primary_conflict_type': conflict.conflictType,
        'display_name': _resolveDisplayName(conflict.conflictType),
        'severity': conflict.severity,
        'involved_ingredients': List<String>.from(conflict.involvedIngredients),
        'involved_products': List<String>.from(conflict.involvedProducts),
        'gemini_explanation': conflict.explanation,
        'related_flags': relatedFlags
            .map((fwp) => <String, dynamic>{
                  'ingredient': fwp.flag.ingredient,
                  'product_name': fwp.productName,
                  'reason': fwp.flag.reason,
                  'gemini_detail': fwp.flag.detail,
                })
            .toList(),
      };
    }).toList();

    // Step 2: Collect standalone flags (orphan reasons + unused mechanism-
    // matching flags that didn't find a matching conflict).
    final standaloneFlags = <_FlagWithProduct>[];
    for (final fwp in allFlags) {
      if (usedFlags.contains(fwp)) continue;
      if (_orphanFlagReasons.contains(fwp.flag.reason)) {
        standaloneFlags.add(fwp);
      } else {
        // Flags with mechanism-related reasons that didn't match any
        // conflict_type. These become standalone too (Gemini may have
        // flagged them without the corresponding mechanism entry).
        standaloneFlags.add(fwp);
      }
    }

    final standaloneJson = standaloneFlags
        .map((fwp) => <String, dynamic>{
              'ingredient': fwp.flag.ingredient,
              'product_name': fwp.productName,
              'reason': fwp.flag.reason,
              'severity': fwp.flag.severity,
              'gemini_detail': fwp.flag.detail,
            })
        .toList();

    final hasAnyAlerts =
        alertGroupsJson.isNotEmpty || standaloneJson.isNotEmpty;

    return <String, dynamic>{
      'section': 'mechanism_interaction_alerts',
      'pet': <String, dynamic>{
        'name': pet.name,
        'species': _speciesToString(pet.species),
        'breed': pet.breed,
        'life_stage': _lifeStageToString(pet.lifeStage),
        'weight_kg': pet.weightKg,
      },
      'alert_groups': alertGroupsJson,
      'standalone_flags': standaloneJson,
      'has_any_alerts': hasAnyAlerts,
    };
  }

  // --------------------------------------------------------------------------
  // Related flag matching
  // --------------------------------------------------------------------------

  /// Finds flagged_ingredients matching the given conflict_type.
  /// Marks matched flags in `usedFlags` to prevent double-counting.
  static List<_FlagWithProduct> _findRelatedFlags({
    required String conflictType,
    required List<_FlagWithProduct> allFlags,
    required Set<_FlagWithProduct> usedFlags,
  }) {
    final matched = <_FlagWithProduct>[];

    for (final fwp in allFlags) {
      if (usedFlags.contains(fwp)) continue;
      if (_flagMatchesConflict(fwp.flag, conflictType)) {
        matched.add(fwp);
        usedFlags.add(fwp);
      }
    }

    return matched;
  }

  static bool _flagMatchesConflict(
    FlaggedIngredient flag,
    String conflictType,
  ) {
    final name = flag.ingredient.toLowerCase();
    final reason = flag.reason;

    switch (conflictType) {
      case 'hemolytic_risk':
        // Allium family ingredients flagged as species-toxic.
        return reason == 'toxic_to_species' &&
            _alliumAliases.any(name.contains);

      case 'thyroid_disruption':
        // Kelp, iodine-related flags.
        return reason == 'thyroid_risk';

      case 'hepatotoxic_combo':
        return reason == 'cumulative_risk' &&
            _hepatotoxicAliases.any(name.contains);

      case 'anticoagulant_stacking':
        return reason == 'cumulative_risk' &&
            _anticoagulantAliases.any(name.contains);

      case 'calcium_phosphorus_imbalance':
        // Ca:P imbalance is a structural/ratio alert, not an ingredient-level
        // flag. No individual flag typically maps here.
        return false;

      default:
        return false;
    }
  }

  // --------------------------------------------------------------------------
  // Display name resolution
  // --------------------------------------------------------------------------
  static String _resolveDisplayName(String conflictType) {
    final preset = _conflictDisplayNames[conflictType];
    if (preset != null) return preset;

    // Fallback: snake_case → Title Case.
    return conflictType
        .split('_')
        .map((word) => word.isEmpty
            ? word
            : '${word[0].toUpperCase()}${word.substring(1)}')
        .join(' ');
  }

  // --------------------------------------------------------------------------
  // Enum → string helpers
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
}

/// Internal helper pairing a flag with its source product name.
class _FlagWithProduct {
  final FlaggedIngredient flag;
  final String productName;

  const _FlagWithProduct({required this.flag, required this.productName});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _FlagWithProduct &&
          identical(flag, other.flag) &&
          productName == other.productName;

  @override
  int get hashCode => Object.hash(identityHashCode(flag), productName);
}
