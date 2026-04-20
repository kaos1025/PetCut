// lib/services/section4_input_builder.dart
//
// PetCut — §4 Observable Warning Signs Input Builder
// ----------------------------------------------------------------------------
// Assembles the Claude Sonnet prompt input JSON for §4 of the paid report.
//
// RESPONSIBILITY
// This builder orchestrates three lower layers:
//   - RiskDetector         (which risks are present?)
//   - ObservableWarningSigns  (what clinical data applies?)
//   - ObservationExpression   (how do we phrase the window?)
//
// The builder does NO new clinical reasoning. It only:
//   1. Calls each layer in order
//   2. Filters speciesSpecificNote by species (cat-only for now)
//   3. Serializes to a Map ready for jsonEncode
//
// The returned Map is injected into the Claude Sonnet prompt as §4's
// input block. See docs/prompts/section_4_observable_warning_signs.md
// for the downstream prompt structure.
//
// DESIGN NOTE — speciesSpecificNote filtering
// Currently only garlic_exposure has a non-null speciesSpecificNote, and
// that note is cat-specific. This builder hard-codes that assumption for
// MVP. When a second entry with speciesSpecificNote is added (whatever
// species it targets), revisit this filter — consider adding a
// speciesSpecificNoteScope field to WarningSignEntry at that time.
//
// Version: v0.1
// Last updated: 2026-04-21
// ----------------------------------------------------------------------------

import '../constants/observable_warning_signs.dart';
import '../models/pet_profile.dart';
import '../models/petcut_analysis_result.dart';
import '../utils/observation_expression.dart';
import 'risk_detector.dart';

class Section4InputBuilder {
  Section4InputBuilder._();

  /// Assembles the §4 input block for the Claude Sonnet prompt.
  ///
  /// The returned Map has this shape:
  /// ```
  /// {
  ///   "section": "observable_warning_signs",
  ///   "pet": { name, species, life_stage, weight_kg },
  ///   "detected_risks": [ { risk_key, display_name, default_tier,
  ///                         effective_tier, observation_hours,
  ///                         observation_expression, early_signs,
  ///                         escalate_signs, species_specific_note }, ... ],
  ///   "has_any_risks": bool
  /// }
  /// ```
  ///
  /// Callers should `jsonEncode()` the result before injecting into a
  /// prompt string.
  static Map<String, dynamic> build({
    required PetcutAnalysisResult geminiResult,
    required PetProfile pet,
  }) {
    // Step 1: Detect which risk keys are present in Gemini's output.
    final detectedKeys = RiskDetector.detectRiskKeys(
      geminiResult: geminiResult,
      pet: pet,
    );

    // Step 2: Resolve applicable entries for this specific pet
    // (species/lifestage filtering happens here).
    final applicableEntries = ObservableWarningSigns.resolveForPet(
      detectedRiskKeys: detectedKeys.toList(),
      petSpecies: pet.species,
      petLifeStage: pet.lifeStage,
      petWeightKg: pet.weightKg,
    );

    // Step 3: Per entry, compute derived fields and serialize.
    final detectedRisksJson = applicableEntries.map((entry) {
      final effectiveTier = RiskDetector.evaluateEffectiveTier(
        riskKey: entry.riskKey,
        geminiResult: geminiResult,
        pet: pet,
      );

      final observationExpression =
          ObservationExpression.fromHours(entry.observationHours);

      final speciesSpecificNote = _resolveSpeciesSpecificNote(
        entry: entry,
        pet: pet,
      );

      return <String, dynamic>{
        'risk_key': entry.riskKey,
        'display_name': entry.displayName,
        'default_tier': _tierToString(entry.defaultTier),
        'effective_tier': _tierToString(effectiveTier),
        'observation_hours': entry.observationHours,
        'observation_expression': observationExpression,
        'early_signs': List<String>.from(entry.earlySigns),
        'escalate_signs': List<String>.from(entry.escalateSigns),
        'species_specific_note': speciesSpecificNote,
      };
    }).toList();

    return <String, dynamic>{
      'section': 'observable_warning_signs',
      'pet': <String, dynamic>{
        'name': pet.name,
        'species': _speciesToString(pet.species),
        'life_stage': _lifeStageToString(pet.lifeStage),
        'weight_kg': pet.weightKg,
      },
      'detected_risks': detectedRisksJson,
      'has_any_risks': detectedRisksJson.isNotEmpty,
    };
  }

  // --------------------------------------------------------------------------
  // Helper: speciesSpecificNote filter
  //
  // MVP rule: Only render speciesSpecificNote when pet is a cat.
  // This is valid as long as the only entry with a non-null note is
  // garlic_exposure, and that note is cat-specific.
  // --------------------------------------------------------------------------
  static String? _resolveSpeciesSpecificNote({
    required WarningSignEntry entry,
    required PetProfile pet,
  }) {
    if (entry.speciesSpecificNote == null) return null;
    if (pet.species == Species.cat) return entry.speciesSpecificNote;
    return null;
  }

  // --------------------------------------------------------------------------
  // Enum → string serialization helpers
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

  static String _tierToString(SeverityTier tier) {
    switch (tier) {
      case SeverityTier.urgent:
        return 'urgent';
      case SeverityTier.monitor:
        return 'monitor';
      case SeverityTier.note:
        return 'note';
    }
  }
}
