// lib/constants/observable_warning_signs.dart
//
// PetCut — Observable Warning Signs Reference Table
// ----------------------------------------------------------------------------
// Static clinical reference table for §4 "Observable Warning Signs" section
// of the paid Claude Sonnet report.
//
// PRINCIPLE: These entries are clinically verified constants, NOT Claude-generated.
// Claude may reference these entries to adjust tone and ordering, but MUST NOT
// modify the signs themselves. This is a hard rule to prevent AI hallucination
// in life-critical guidance.
//
// Sources:
//   - Merck Veterinary Manual (MVM), online edition
//   - ASPCA Animal Poison Control Center (APCC)
//   - NRC 2006: Nutrient Requirements of Dogs and Cats
//   - Plumb's Veterinary Drug Handbook, 10th ed.
//
// Verification:
//   - Reviewed by @약사 (PetCut Veterinary Nutrition Advisor)
//   - Version: v0.2 (검토 5개 포인트 반영 완료)
//   - Last updated: 2026-04-21
//
// Pet species/lifestage resolution happens at runtime via
// ObservableWarningSigns.resolveForPet().
// ----------------------------------------------------------------------------

import '../models/pet_enums.dart';

/// Which pets this warning entry applies to.
enum SpeciesScope {
  /// Applies to dogs only.
  dog,

  /// Applies to cats only.
  cat,

  /// Applies to both dogs and cats.
  both,

  /// Applies only to large-breed puppies
  /// (expected adult weight >= 25 kg AND life stage == puppy).
  dogLargeBreedPuppy,
}

/// Triage severity tier shown in §5 (Action Plan & Vet Escalation).
/// §4 inherits its default tier from here and may escalate at runtime.
enum SeverityTier {
  /// 🔴 Contact vet today.
  urgent,

  /// 🟡 Observe; escalate to urgent if escalate_signs appear.
  monitor,

  /// 🟢 Mention at next routine visit; self-adjustment may be sufficient.
  note,
}

/// A single risk entry with early-warning signs and escalation signs.
class WarningSignEntry {
  /// Machine key used by risk_detector.dart to map from Gemini JSON.
  final String riskKey;

  /// Human-readable title for the report section.
  final String displayName;

  /// Which pets this entry applies to.
  final SpeciesScope speciesScope;

  /// Default triage tier when this risk is detected.
  final SeverityTier defaultTier;

  /// Optional escalated tier if [escalationCondition] evaluates true at runtime.
  /// Evaluation happens in risk_detector.dart, not in this constant table.
  final SeverityTier? escalatedTier;

  /// Human-readable description of when to escalate.
  /// Example: 'per_kg_intake >= chronic_toxic (0.01 mg/kg BW/day)'.
  final String? escalationCondition;

  /// Recommended owner observation window in hours.
  final int observationHours;

  /// Early warning signs the owner should watch for.
  /// Language: plain, owner-observable, minimal medical jargon.
  final List<String> earlySigns;

  /// Signs that mandate immediate vet contact.
  final List<String> escalateSigns;

  /// Internal clinical rationale. NOT rendered in the user-facing PDF.
  /// Used for QA, internal documentation, and future advisor review.
  final String clinicalRationale;

  /// Source citations for traceability.
  final List<String> sources;

  /// Optional species-specific clinical note to be prepended to the
  /// report body when the pet matches a specific species edge case.
  ///
  /// Currently used for garlic exposure in cats, where symptom onset is
  /// delayed 3–5 days and owners must extend the observation window.
  /// If non-null, Claude is instructed to render this note at the top of
  /// the entry's section for matching species only.
  final String? speciesSpecificNote;

  const WarningSignEntry({
    required this.riskKey,
    required this.displayName,
    required this.speciesScope,
    required this.defaultTier,
    this.escalatedTier,
    this.escalationCondition,
    required this.observationHours,
    required this.earlySigns,
    required this.escalateSigns,
    required this.clinicalRationale,
    required this.sources,
    this.speciesSpecificNote,
  });
}

/// Static registry of all warning sign entries.
///
/// Entries are looked up by [riskKey] from [risk_detector.dart], then filtered
/// by species and life stage via [resolveForPet].
class ObservableWarningSigns {
  ObservableWarningSigns._();

  static const Map<String, WarningSignEntry> _entries = {
    // -------------------------------------------------------------------------
    // 1. Vitamin D3 Excess
    // -------------------------------------------------------------------------
    'd3_excess': WarningSignEntry(
      riskKey: 'd3_excess',
      displayName: 'Vitamin D3 Excess',
      speciesScope: SpeciesScope.both,
      defaultTier: SeverityTier.monitor,
      escalatedTier: SeverityTier.urgent,
      escalationCondition:
          'per_kg_intake >= chronic_toxic threshold (0.01 mg/kg BW/day)',
      observationHours: 72,
      earlySigns: [
        'Drinking noticeably more water than usual',
        'Urinating more often or having accidents indoors',
        'Reduced appetite or leaving a favorite food',
        'Lethargy, reluctance to walk, or sleeping more than usual',
      ],
      escalateSigns: [
        'Vomiting more than twice within 24 hours',
        'Noticeable weight loss',
        'Constipation or bloody stool',
        'Muscle tremors or seizures',
        'Rapid or shallow breathing',
      ],
      clinicalRationale:
          'Hypercalcemia from chronic D3 excess produces polyuria and '
          'polydipsia as the earliest signs, progressing to renal tubular '
          'damage and eventually chronic kidney failure. Early detection '
          'allows reversal; late-stage renal damage is largely irreversible. '
          'Focus is on chronic daily intake (food + supplement stacking), '
          'not acute single-dose ingestion.',
      sources: ['Merck Vet Manual', 'NRC 2006'],
    ),

    // -------------------------------------------------------------------------
    // 2. Iron Excess (acute)
    // -------------------------------------------------------------------------
    'iron_excess': WarningSignEntry(
      riskKey: 'iron_excess',
      displayName: 'Iron Excess',
      speciesScope: SpeciesScope.both,
      defaultTier: SeverityTier.urgent,
      escalatedTier: null,
      escalationCondition: null,
      observationHours: 24,
      earlySigns: [
        'Vomiting (sometimes brown or dark-colored)',
        'Increased drooling',
        'Unusual tiredness or low energy',
        'Discomfort or hunching when the belly is touched',
      ],
      escalateSigns: [
        'Black, tarry stool or visible blood in stool',
        'Fresh red blood or dark coffee-ground material in vomit',
        'Pale or grayish gums',
        'Fast or irregular heartbeat',
        'Confusion, collapse, or loss of consciousness',
      ],
      clinicalRationale:
          'Acute iron toxicity progresses through four stages: GI phase '
          '(0–6h), latent phase (6–24h) with apparent recovery, systemic '
          'phase (12–48h), and hepatic phase (2–5d). The deceptive latent '
          'phase means owners may think the pet is fine when damage is '
          'actually progressing. Any early GI signs after supplement '
          'overdose warrant immediate vet contact. Threshold: 20 mg/kg BW '
          'for GI symptoms, 60 mg/kg BW for severe toxicity.',
      sources: ['ASPCA APCC', 'Plumb\'s Veterinary Drug Handbook'],
    ),

    // -------------------------------------------------------------------------
    // 3. Calcium Excess — Large-breed puppy specific
    // -------------------------------------------------------------------------
    'calcium_excess_large_breed_puppy': WarningSignEntry(
      riskKey: 'calcium_excess_large_breed_puppy',
      displayName: 'Calcium Excess (Large-Breed Puppy)',
      speciesScope: SpeciesScope.dogLargeBreedPuppy,
      defaultTier: SeverityTier.monitor,
      escalatedTier: null,
      escalationCondition: null,
      observationHours: 336, // 14 days — developmental issue, long window
      earlySigns: [
        'Unusual gait or limping during walks',
        'Visible swelling around front or hind leg joints',
        'Resting noticeably longer after exercise',
        'Sitting in odd positions or tucking legs awkwardly',
      ],
      escalateSigns: [
        'Persistent limping for 3 or more days',
        'Pain reaction when joints are touched',
        'Visibly bowed or misaligned leg shape',
        'Growth clearly slower than littermates or breed average',
      ],
      clinicalRationale:
          'Large-breed puppies (expected adult weight >= 25 kg) cannot '
          'down-regulate calcium absorption the way adult dogs can. '
          'Chronic excess during growth plate development is linked to '
          'Osteochondritis Dissecans (OCD), Hypertrophic Osteodystrophy '
          '(HOD), and angular limb deformities. Adult dogs self-regulate '
          'and are generally unaffected. AAFCO caps large-breed puppy '
          'calcium at 1.5% DM; >1.2% DM warrants caution per internal '
          'threshold (toxicity_thresholds v0.2).',
      sources: ['AAFCO 2024', 'NRC 2006', 'Merck Vet Manual'],
    ),

    // -------------------------------------------------------------------------
    // 4. Garlic / Allium Exposure
    // -------------------------------------------------------------------------
    'garlic_exposure': WarningSignEntry(
      riskKey: 'garlic_exposure',
      displayName: 'Garlic / Onion Exposure',
      speciesScope: SpeciesScope.both,
      defaultTier: SeverityTier.monitor, // dog default
      escalatedTier: SeverityTier.urgent, // cat → urgent automatically
      escalationCondition: 'species == cat (cats escalate to urgent)',
      observationHours: 72, // dogs 72h, cats 24h — handled at runtime
      earlySigns: [
        'Tiring more easily than usual or shortened walk distance',
        'Gums lighter in color than normal (compare by pressing gently)',
        'Breathing faster or more heavily than usual',
        'Reduced appetite',
      ],
      escalateSigns: [
        'Pale gums or yellow tint to gums, eyes, or skin (jaundice)',
        'Dark brown or red-tinged urine',
        'Collapse or inability to stand',
        'Very rapid heart rate',
        'Labored breathing',
      ],
      clinicalRationale:
          'Allium family ingredients (garlic, onion, chives, leek, shallot) '
          'contain n-propyl disulfide, which oxidizes hemoglobin and causes '
          'Heinz body formation on red blood cells, leading to hemolytic '
          'anemia. Dogs show clinical signs at 15–30 g/kg BW; cats are '
          'dramatically more sensitive (5 g/kg or less). Cat symptom onset '
          'can be delayed 3–5 days, so the observation window for cats '
          'should be extended. Cats should always escalate to urgent tier '
          'when any allium is detected.',
      sources: ['ASPCA APCC', 'Merck Vet Manual'],
      speciesSpecificNote:
          'For cats: signs may appear 3-5 days after exposure rather than '
          'immediately. Continue monitoring for a full week.',
    ),

    // -------------------------------------------------------------------------
    // 5. Xylitol Exposure — Dogs only (cats: insufficient data)
    // -------------------------------------------------------------------------
    'xylitol_exposure': WarningSignEntry(
      riskKey: 'xylitol_exposure',
      displayName: 'Xylitol Exposure',
      speciesScope: SpeciesScope.dog,
      defaultTier: SeverityTier.urgent,
      escalatedTier: null,
      escalationCondition: null,
      observationHours: 24,
      earlySigns: [
        'Sudden loss of energy',
        'Unsteady walking or stumbling',
        'Drooling more than usual, especially with other signs listed here',
        'Vomiting',
      ],
      escalateSigns: [
        'Seizures or convulsions',
        'Collapse or loss of consciousness',
        'Yellow tint to gums, eyes, or skin (jaundice — liver failure, '
            'onset 12–72h)',
        'Slow response, cannot be roused when called',
      ],
      clinicalRationale:
          'Xylitol triggers massive insulin release in dogs (but not in '
          'humans or cats), causing acute hypoglycemia within 15–60 minutes. '
          'Higher doses progress to acute hepatic failure within 12–72 '
          'hours. Dose thresholds: 0.1 g/kg BW for hypoglycemia, 0.5 g/kg '
          'BW for liver failure. This is a time-critical emergency — the '
          'window between exposure and irreversible damage is short. Cat '
          'data is insufficient to establish toxicity thresholds; cats are '
          'flagged as caution only and do not receive this entry.',
      sources: ['ASPCA APCC', 'Plumb\'s Veterinary Drug Handbook'],
    ),
  };

  /// Look up a single entry by risk key. Returns null if not found.
  static WarningSignEntry? byKey(String riskKey) => _entries[riskKey];

  /// Resolve the set of warning-sign entries relevant to a specific pet,
  /// given the risk keys detected by risk_detector.dart.
  ///
  /// Filters by species scope and, for the large-breed-puppy entry,
  /// by life stage and weight.
  ///
  /// Does NOT evaluate [escalationCondition] — that is computed in
  /// risk_detector.dart using Gemini's nutrient_totals output.
  static List<WarningSignEntry> resolveForPet({
    required List<String> detectedRiskKeys,
    required Species petSpecies,
    required LifeStage petLifeStage,
    required double petWeightKg,
  }) {
    final results = <WarningSignEntry>[];

    for (final key in detectedRiskKeys) {
      final entry = _entries[key];
      if (entry == null) continue;

      if (!_scopeApplies(
        scope: entry.speciesScope,
        petSpecies: petSpecies,
        petLifeStage: petLifeStage,
        petWeightKg: petWeightKg,
      )) {
        continue;
      }

      results.add(entry);
    }

    return results;
  }

  static bool _scopeApplies({
    required SpeciesScope scope,
    required Species petSpecies,
    required LifeStage petLifeStage,
    required double petWeightKg,
  }) {
    switch (scope) {
      case SpeciesScope.both:
        return true;
      case SpeciesScope.dog:
        return petSpecies == Species.dog;
      case SpeciesScope.cat:
        return petSpecies == Species.cat;
      case SpeciesScope.dogLargeBreedPuppy:
        return petSpecies == Species.dog &&
            petLifeStage == LifeStage.puppy &&
            petWeightKg >= 25.0;
    }
  }

  /// All registered risk keys, for testing and QA.
  static Iterable<String> get allRiskKeys => _entries.keys;
}
