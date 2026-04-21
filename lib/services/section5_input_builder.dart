// lib/services/section5_input_builder.dart
//
// PetCut — §5 Action Plan & Vet Escalation Input Builder
// ----------------------------------------------------------------------------
// Assembles the Claude Sonnet prompt input JSON for §5 of the paid report.
//
// RESPONSIBILITY
// §5 is the final section — it translates everything analyzed in §1-§4
// into concrete, owner-actionable recommendations, triaged into three
// tiers:
//   🔴 urgent          — contact vet today
//   🟡 next_vet_visit  — mention at routine appointment
//   🟢 self_adjust     — changes owner can make at home
//
// This builder:
//   1. Determines the overall triage tier based on Gemini's analysis
//      (severity of mechanisms, flags, nutrient totals, overall_status)
//   2. Converts Gemini's exclusion_recommendations into triage-classified
//      action cards
//   3. Maps exclusion.tier (1-4) + action type → triage tier + action_verb
//   4. Emits prescription_medication_note (MVP: always shown, Sprint 3+
//      will customize when currentMedications is implemented)
//
// TRIAGE DETERMINATION RULES (from All Hands consensus)
//   urgent:         overall_status == 'warning' AND
//                   (any critical mechanism OR critical flag OR
//                    critical nutrient)
//   next_vet_visit: mechanism_conflicts present OR
//                   any life_stage_mismatch flag
//   self_adjust:    caution-level issues only, no mechanism or mismatch
//   (no_action):    everything safe — but triage_banner still shown as
//                   self_adjust with empty actions
//
// Version: v0.1
// Last updated: 2026-04-21
// ----------------------------------------------------------------------------

import '../models/pet_profile.dart';
import '../models/petcut_analysis_result.dart';

class Section5InputBuilder {
  Section5InputBuilder._();

  // --------------------------------------------------------------------------
  // Prescription medication note — MVP constant
  //
  // MVP: shown for every paid report (graceful degradation while
  // currentMedications detection is not yet implemented).
  // Sprint 3+: will be customized when PetProfile.currentMedications is
  // populated (e.g. "Buddy is on tetracycline — calcium in this combo
  // may reduce its absorption").
  // --------------------------------------------------------------------------
  static const String _prescriptionNoteText =
      'If your pet is currently taking any prescription medication from '
      'a vet, please share this combo with them as well. Some '
      'supplements interact with common prescriptions.';

  // --------------------------------------------------------------------------
  // Triage tier constants
  // --------------------------------------------------------------------------
  static const String _tierUrgent = 'urgent';
  static const String _tierNextVetVisit = 'next_vet_visit';
  static const String _tierSelfAdjust = 'self_adjust';

  // --------------------------------------------------------------------------
  // Action verb mapping — Gemini action → owner-facing verb
  // --------------------------------------------------------------------------
  static const Map<String, String> _actionVerbMap = {
    'remove': 'stop',
    'reduce': 'reduce',
    'replace': 'switch',
    'monitor': 'watch',
  };

  static const String _actionVerbFallback = 'adjust';

  // --------------------------------------------------------------------------
  // Public API
  // --------------------------------------------------------------------------

  /// Assembles the §5 input block for the Claude Sonnet prompt.
  static Map<String, dynamic> build({
    required PetcutAnalysisResult geminiResult,
    required PetProfile pet,
  }) {
    // Step 1: Determine overall triage tier.
    final triageTier = _determineTriageTier(geminiResult);

    // Step 2: Build tier rationale (human-readable explanation).
    final tierRationale = _buildTierRationale(geminiResult);

    // Step 3: Convert exclusions to actions, classified into triage buckets.
    final urgentActions = <Map<String, dynamic>>[];
    final nextVisitActions = <Map<String, dynamic>>[];
    final selfAdjustActions = <Map<String, dynamic>>[];

    for (final exclusion
        in geminiResult.comboAnalysis.exclusionRecommendations) {
      final actionMap = _exclusionToAction(exclusion);
      final actionTier = _tierForExclusion(exclusion);

      switch (actionTier) {
        case _tierUrgent:
          urgentActions.add(actionMap);
          break;
        case _tierNextVetVisit:
          nextVisitActions.add(actionMap);
          break;
        case _tierSelfAdjust:
          selfAdjustActions.add(actionMap);
          break;
      }
    }

    // Step 4: Compile full input JSON.
    final hasAnyActions = urgentActions.isNotEmpty ||
        nextVisitActions.isNotEmpty ||
        selfAdjustActions.isNotEmpty;

    return <String, dynamic>{
      'section': 'action_plan_vet_escalation',
      'pet': <String, dynamic>{
        'name': pet.name,
        'species': _speciesToString(pet.species),
        'breed': pet.breed,
        'life_stage': _lifeStageToString(pet.lifeStage),
        'weight_kg': pet.weightKg,
      },
      'overall_status': geminiResult.overallStatus,
      'triage': <String, dynamic>{
        'final_tier': triageTier,
        'tier_emoji': _emojiForTier(triageTier),
        'tier_display': _displayForTier(triageTier),
        'tier_rationale': tierRationale,
      },
      'urgent_actions': urgentActions,
      'next_visit_actions': nextVisitActions,
      'self_adjust_actions': selfAdjustActions,
      'prescription_medication_note': <String, dynamic>{
        'show': true,
        'text': _prescriptionNoteText,
      },
      'has_any_actions': hasAnyActions,
    };
  }

  // --------------------------------------------------------------------------
  // Triage tier determination
  // --------------------------------------------------------------------------

  /// Determines the overall triage tier based on Gemini's analysis.
  ///
  /// Algorithm (in order):
  ///   1. URGENT: overall_status == 'warning' AND any critical severity
  ///      element (mechanism, flag, or nutrient total).
  ///   2. NEXT VET VISIT: mechanism_conflicts present OR any
  ///      life_stage_mismatch flag.
  ///   3. SELF-ADJUST: anything else (default).
  static String _determineTriageTier(PetcutAnalysisResult geminiResult) {
    final overallStatus = geminiResult.overallStatus;
    final mechanisms = geminiResult.comboAnalysis.mechanismConflicts;
    final nutrients = geminiResult.comboAnalysis.nutrientTotals;
    final allFlags =
        geminiResult.products.expand((p) => p.flaggedIngredients).toList();

    // Rule 1: Urgent
    if (overallStatus == 'warning') {
      final hasCriticalMechanism =
          mechanisms.any((m) => m.severity == 'critical');
      final hasCriticalFlag = allFlags.any((f) => f.severity == 'critical');
      final hasCriticalNutrient = nutrients.any((n) => n.status == 'critical');

      if (hasCriticalMechanism || hasCriticalFlag || hasCriticalNutrient) {
        return _tierUrgent;
      }
    }

    // Rule 2: Next Vet Visit
    final hasMechanism = mechanisms.isNotEmpty;
    final hasLifeStageMismatch =
        allFlags.any((f) => f.reason == 'life_stage_mismatch');

    if (hasMechanism || hasLifeStageMismatch) {
      return _tierNextVetVisit;
    }

    // Rule 3: Self-Adjust (default)
    return _tierSelfAdjust;
  }

  /// Builds human-readable rationale for the determined triage tier.
  /// Each entry in the returned list is a short phrase (<100 chars)
  /// suitable for bullet display.
  static List<String> _buildTierRationale(PetcutAnalysisResult geminiResult) {
    final rationale = <String>[];
    rationale.add('Overall status: ${geminiResult.overallStatus}');

    final mechanisms = geminiResult.comboAnalysis.mechanismConflicts;
    for (final mechanism in mechanisms) {
      rationale.add(
          'Mechanism conflict: ${mechanism.conflictType} (${mechanism.severity})');
    }

    final allFlags =
        geminiResult.products.expand((p) => p.flaggedIngredients).toList();

    final lifeStageFlags =
        allFlags.where((f) => f.reason == 'life_stage_mismatch');
    if (lifeStageFlags.isNotEmpty) {
      rationale.add('Life stage mismatch flagged');
    }

    final criticalFlags =
        allFlags.where((f) => f.severity == 'critical').toList();
    for (final flag in criticalFlags) {
      rationale.add('Critical flag: ${flag.ingredient}');
    }

    final criticalNutrients = geminiResult.comboAnalysis.nutrientTotals
        .where((n) => n.status == 'critical')
        .toList();
    for (final nutrient in criticalNutrients) {
      rationale.add('Critical nutrient: ${nutrient.nutrient}');
    }

    return rationale;
  }

  // --------------------------------------------------------------------------
  // Exclusion → Action conversion
  // --------------------------------------------------------------------------

  /// Converts a Gemini ExclusionRecommendation into a structured action card.
  static Map<String, dynamic> _exclusionToAction(
      ExclusionRecommendation exclusion) {
    final actionVerb = _actionVerbMap[exclusion.action] ?? _actionVerbFallback;

    String? monthlyCostNote;
    if (exclusion.monthlySavingsUsd != null) {
      monthlyCostNote =
          '\$${exclusion.monthlySavingsUsd!.toStringAsFixed(2)}/month savings';
    }

    return <String, dynamic>{
      'action_type': exclusion.action,
      'target_product': exclusion.targetProduct,
      'reason': exclusion.reason,
      'action_verb': actionVerb,
      'monthly_cost_note': monthlyCostNote,
    };
  }

  /// Determines the triage tier for an individual exclusion based on
  /// Gemini's tier (1-4).
  ///
  /// Mapping:
  ///   Tier 1 (CRITICAL) → urgent
  ///   Tier 2 (WARNING)  → urgent
  ///   Tier 3 (CAUTION)  → next_vet_visit
  ///   Tier 4 (MONITOR)  → self_adjust
  ///   Unknown           → self_adjust (defensive default)
  static String _tierForExclusion(ExclusionRecommendation exclusion) {
    switch (exclusion.tier) {
      case 1:
      case 2:
        return _tierUrgent;
      case 3:
        return _tierNextVetVisit;
      case 4:
        return _tierSelfAdjust;
      default:
        return _tierSelfAdjust;
    }
  }

  // --------------------------------------------------------------------------
  // Tier display helpers
  // --------------------------------------------------------------------------

  static String _emojiForTier(String tier) {
    switch (tier) {
      case _tierUrgent:
        return '🔴';
      case _tierNextVetVisit:
        return '🟡';
      case _tierSelfAdjust:
        return '🟢';
      default:
        return '🟢';
    }
  }

  static String _displayForTier(String tier) {
    switch (tier) {
      case _tierUrgent:
        return 'Contact Your Vet Today';
      case _tierNextVetVisit:
        return 'Mention at Next Vet Visit';
      case _tierSelfAdjust:
        return 'Safe to Adjust at Home';
      default:
        return 'Safe to Adjust at Home';
    }
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
