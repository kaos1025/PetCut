// PetCut — Claude Report Response typed model
// ----------------------------------------------------------------------------
// Typed response model for the Claude Sonnet 5-section paid report.
//
// Each section's field set is sourced verbatim from the corresponding
// `docs/prompts/section_*.md` "## Output Schema" specification:
//   §1 → docs/prompts/section_1_pet_risk_profile.md
//   §2 → docs/prompts/section_2_combo_load_report.md
//   §3 → docs/prompts/section_3_mechanism_interaction_alerts.md
//   §4 → docs/prompts/section_4_observable_warning_signs.md
//   §5 → docs/prompts/section_5_action_plan_vet_escalation.md
//
// Top-level shape (system-prompt enforced):
// {
//   "report_version": "v1",
//   "sections": [ {section: "...", ...}, × 5 ]
// }
//
// Schema policy: every fromJson is STRICT. Any missing required field,
// type mismatch, missing section, or unknown discriminator throws
// FormatException. The service layer catches and applies the fail-closed
// retry policy (STATUS_0428 §4.4).
// ----------------------------------------------------------------------------

class ClaudeReportResponse {
  static const String currentVersion = 'v1';

  final String reportVersion;
  final Section1Output section1;
  final Section2Output section2;
  final Section3Output section3;
  final Section4Output section4;
  final Section5Output section5;

  const ClaudeReportResponse({
    required this.reportVersion,
    required this.section1,
    required this.section2,
    required this.section3,
    required this.section4,
    required this.section5,
  });

  factory ClaudeReportResponse.fromJson(Map<String, dynamic> json) {
    final reportVersion = _requireString(json, 'report_version');
    final sectionsList = _requireList(json, 'sections');
    if (sectionsList.length != 5) {
      throw FormatException(
        'Claude response: expected 5 sections, got ${sectionsList.length}',
      );
    }

    Section1Output? s1;
    Section2Output? s2;
    Section3Output? s3;
    Section4Output? s4;
    Section5Output? s5;

    for (final item in sectionsList) {
      if (item is! Map<String, dynamic>) {
        throw const FormatException(
          'Claude response: section item is not an object',
        );
      }
      final discriminator = _requireString(item, 'section');
      switch (discriminator) {
        case 'pet_risk_profile':
          s1 = Section1Output.fromJson(item);
          break;
        case 'combo_load_report':
          s2 = Section2Output.fromJson(item);
          break;
        case 'mechanism_interaction_alerts':
          s3 = Section3Output.fromJson(item);
          break;
        case 'observable_warning_signs':
          s4 = Section4Output.fromJson(item);
          break;
        case 'action_plan_vet_escalation':
          s5 = Section5Output.fromJson(item);
          break;
        default:
          throw FormatException(
            'Claude response: unknown section discriminator '
            '"$discriminator"',
          );
      }
    }

    if (s1 == null || s2 == null || s3 == null || s4 == null || s5 == null) {
      final missing = <String>[
        if (s1 == null) ClaudeReportResponseSectionId.section1,
        if (s2 == null) ClaudeReportResponseSectionId.section2,
        if (s3 == null) ClaudeReportResponseSectionId.section3,
        if (s4 == null) ClaudeReportResponseSectionId.section4,
        if (s5 == null) ClaudeReportResponseSectionId.section5,
      ];
      throw FormatException(
        'Claude response: missing required sections [${missing.join(', ')}]',
      );
    }

    return ClaudeReportResponse(
      reportVersion: reportVersion,
      section1: s1,
      section2: s2,
      section3: s3,
      section4: s4,
      section5: s5,
    );
  }
}

class ClaudeReportResponseSectionId {
  ClaudeReportResponseSectionId._();
  static const String section1 = 'pet_risk_profile';
  static const String section2 = 'combo_load_report';
  static const String section3 = 'mechanism_interaction_alerts';
  static const String section4 = 'observable_warning_signs';
  static const String section5 = 'action_plan_vet_escalation';
}

// ---------------------------------------------------------------------------
// §1 — Pet Risk Profile
// ---------------------------------------------------------------------------

class Section1Output {
  final String section;
  final String title;
  final String petSummaryLine;
  final String body;
  final List<SensitivityNote> sensitivityNotes;
  final String transition;

  const Section1Output({
    required this.section,
    required this.title,
    required this.petSummaryLine,
    required this.body,
    required this.sensitivityNotes,
    required this.transition,
  });

  factory Section1Output.fromJson(Map<String, dynamic> json) {
    _requireSectionDiscriminator(json, 'pet_risk_profile');
    return Section1Output(
      section: _requireString(json, 'section'),
      title: _requireString(json, 'title'),
      petSummaryLine: _requireString(json, 'pet_summary_line'),
      body: _requireString(json, 'body'),
      sensitivityNotes: _mapObjectList(
        json,
        'sensitivity_notes',
        SensitivityNote.fromJson,
      ),
      transition: _requireString(json, 'transition'),
    );
  }
}

class SensitivityNote {
  final String flagKey;
  final String displayLabel;
  final String note;

  const SensitivityNote({
    required this.flagKey,
    required this.displayLabel,
    required this.note,
  });

  factory SensitivityNote.fromJson(Map<String, dynamic> json) =>
      SensitivityNote(
        flagKey: _requireString(json, 'flag_key'),
        displayLabel: _requireString(json, 'display_label'),
        note: _requireString(json, 'note'),
      );
}

// ---------------------------------------------------------------------------
// §2 — Combo Load Report
// ---------------------------------------------------------------------------

class Section2Output {
  final String section;
  final String title;
  final String intro;
  final HeadlineBlock headline;
  final List<NutrientCard> nutrientCards;
  final String safeNutrientsSummary;
  final String closing;

  const Section2Output({
    required this.section,
    required this.title,
    required this.intro,
    required this.headline,
    required this.nutrientCards,
    required this.safeNutrientsSummary,
    required this.closing,
  });

  factory Section2Output.fromJson(Map<String, dynamic> json) {
    _requireSectionDiscriminator(json, 'combo_load_report');
    return Section2Output(
      section: _requireString(json, 'section'),
      title: _requireString(json, 'title'),
      intro: _requireString(json, 'intro'),
      headline: HeadlineBlock.fromJson(_requireMap(json, 'headline')),
      nutrientCards: _mapObjectList(
        json,
        'nutrient_cards',
        NutrientCard.fromJson,
      ),
      safeNutrientsSummary: _requireString(json, 'safe_nutrients_summary'),
      closing: _requireString(json, 'closing'),
    );
  }
}

class HeadlineBlock {
  final String statement;
  final String detail;

  const HeadlineBlock({
    required this.statement,
    required this.detail,
  });

  factory HeadlineBlock.fromJson(Map<String, dynamic> json) => HeadlineBlock(
        statement: _requireString(json, 'statement'),
        detail: _requireString(json, 'detail'),
      );
}

class NutrientCard {
  final String nutrient;
  final String displayName;
  final String statusBadge;
  final HeadlineNumber headlineNumber;
  final String sourceLine;
  final String body;
  final String limitSourceNote;

  const NutrientCard({
    required this.nutrient,
    required this.displayName,
    required this.statusBadge,
    required this.headlineNumber,
    required this.sourceLine,
    required this.body,
    required this.limitSourceNote,
  });

  factory NutrientCard.fromJson(Map<String, dynamic> json) => NutrientCard(
        nutrient: _requireString(json, 'nutrient'),
        displayName: _requireString(json, 'display_name'),
        statusBadge: _requireString(json, 'status_badge'),
        headlineNumber: HeadlineNumber.fromJson(
          _requireMap(json, 'headline_number'),
        ),
        sourceLine: _requireString(json, 'source_line'),
        body: _requireString(json, 'body'),
        limitSourceNote: _requireString(json, 'limit_source_note'),
      );
}

class HeadlineNumber {
  final String primary;
  final String secondary;

  const HeadlineNumber({
    required this.primary,
    required this.secondary,
  });

  factory HeadlineNumber.fromJson(Map<String, dynamic> json) => HeadlineNumber(
        primary: _requireString(json, 'primary'),
        secondary: _requireString(json, 'secondary'),
      );
}

// ---------------------------------------------------------------------------
// §3 — Mechanism & Interaction Alerts
// ---------------------------------------------------------------------------

class Section3Output {
  final String section;
  final String title;
  final String intro;
  final HeadlineBlock headline;
  final List<AlertCard> alertCards;
  final StandaloneFlagsSummary standaloneFlagsSummary;
  final String closing;

  const Section3Output({
    required this.section,
    required this.title,
    required this.intro,
    required this.headline,
    required this.alertCards,
    required this.standaloneFlagsSummary,
    required this.closing,
  });

  factory Section3Output.fromJson(Map<String, dynamic> json) {
    _requireSectionDiscriminator(json, 'mechanism_interaction_alerts');
    return Section3Output(
      section: _requireString(json, 'section'),
      title: _requireString(json, 'title'),
      intro: _requireString(json, 'intro'),
      headline: HeadlineBlock.fromJson(_requireMap(json, 'headline')),
      alertCards: _mapObjectList(json, 'alert_cards', AlertCard.fromJson),
      standaloneFlagsSummary: StandaloneFlagsSummary.fromJson(
        _requireMap(json, 'standalone_flags_summary'),
      ),
      closing: _requireString(json, 'closing'),
    );
  }
}

class AlertCard {
  final String primaryConflictType;
  final String displayName;
  final String severityBadge;
  final String involvedSummary;
  final String body;
  final String? relatedFlagsNote;

  const AlertCard({
    required this.primaryConflictType,
    required this.displayName,
    required this.severityBadge,
    required this.involvedSummary,
    required this.body,
    required this.relatedFlagsNote,
  });

  factory AlertCard.fromJson(Map<String, dynamic> json) => AlertCard(
        primaryConflictType: _requireString(json, 'primary_conflict_type'),
        displayName: _requireString(json, 'display_name'),
        severityBadge: _requireString(json, 'severity_badge'),
        involvedSummary: _requireString(json, 'involved_summary'),
        body: _requireString(json, 'body'),
        relatedFlagsNote: _optionalString(json, 'related_flags_note'),
      );
}

class StandaloneFlagsSummary {
  final bool present;
  final List<StandaloneFlagCard> cards;

  const StandaloneFlagsSummary({
    required this.present,
    required this.cards,
  });

  factory StandaloneFlagsSummary.fromJson(Map<String, dynamic> json) =>
      StandaloneFlagsSummary(
        present: _requireBool(json, 'present'),
        cards: _mapObjectList(json, 'cards', StandaloneFlagCard.fromJson),
      );
}

class StandaloneFlagCard {
  final String ingredient;
  final String flagType;
  final String severityBadge;
  final String body;

  const StandaloneFlagCard({
    required this.ingredient,
    required this.flagType,
    required this.severityBadge,
    required this.body,
  });

  factory StandaloneFlagCard.fromJson(Map<String, dynamic> json) =>
      StandaloneFlagCard(
        ingredient: _requireString(json, 'ingredient'),
        flagType: _requireString(json, 'flag_type'),
        severityBadge: _requireString(json, 'severity_badge'),
        body: _requireString(json, 'body'),
      );
}

// ---------------------------------------------------------------------------
// §4 — Observable Warning Signs
// ---------------------------------------------------------------------------

class Section4Output {
  final String section;
  final String title;
  final String intro;
  final List<RiskSection> riskSections;
  final String closing;

  const Section4Output({
    required this.section,
    required this.title,
    required this.intro,
    required this.riskSections,
    required this.closing,
  });

  factory Section4Output.fromJson(Map<String, dynamic> json) {
    _requireSectionDiscriminator(json, 'observable_warning_signs');
    return Section4Output(
      section: _requireString(json, 'section'),
      title: _requireString(json, 'title'),
      intro: _requireString(json, 'intro'),
      riskSections: _mapObjectList(
        json,
        'risk_sections',
        RiskSection.fromJson,
      ),
      closing: _requireString(json, 'closing'),
    );
  }
}

class RiskSection {
  final String riskKey;
  final String displayName;
  final String tierBadge;
  final String? speciesNote;
  final String body;
  final String earlySignsHeader;
  final List<String> earlySigns;
  final String escalateSignsHeader;
  final List<String> escalateSigns;

  const RiskSection({
    required this.riskKey,
    required this.displayName,
    required this.tierBadge,
    required this.speciesNote,
    required this.body,
    required this.earlySignsHeader,
    required this.earlySigns,
    required this.escalateSignsHeader,
    required this.escalateSigns,
  });

  factory RiskSection.fromJson(Map<String, dynamic> json) => RiskSection(
        riskKey: _requireString(json, 'risk_key'),
        displayName: _requireString(json, 'display_name'),
        tierBadge: _requireString(json, 'tier_badge'),
        speciesNote: _optionalString(json, 'species_note'),
        body: _requireString(json, 'body'),
        earlySignsHeader: _requireString(json, 'early_signs_header'),
        earlySigns: _requireStringList(json, 'early_signs'),
        escalateSignsHeader: _requireString(json, 'escalate_signs_header'),
        escalateSigns: _requireStringList(json, 'escalate_signs'),
      );
}

// ---------------------------------------------------------------------------
// §5 — Action Plan & Vet Escalation
// ---------------------------------------------------------------------------

class Section5Output {
  final String section;
  final String title;
  final String intro;
  final TriageBanner triageBanner;
  final ActionSection urgentSection;
  final ActionSection nextVisitSection;
  final ActionSection selfAdjustSection;
  final String? prescriptionNote;
  final String closing;

  const Section5Output({
    required this.section,
    required this.title,
    required this.intro,
    required this.triageBanner,
    required this.urgentSection,
    required this.nextVisitSection,
    required this.selfAdjustSection,
    required this.prescriptionNote,
    required this.closing,
  });

  factory Section5Output.fromJson(Map<String, dynamic> json) {
    _requireSectionDiscriminator(json, 'action_plan_vet_escalation');
    return Section5Output(
      section: _requireString(json, 'section'),
      title: _requireString(json, 'title'),
      intro: _requireString(json, 'intro'),
      triageBanner:
          TriageBanner.fromJson(_requireMap(json, 'triage_banner')),
      urgentSection: ActionSection.fromJson(
        _requireMap(json, 'urgent_section'),
      ),
      nextVisitSection: ActionSection.fromJson(
        _requireMap(json, 'next_visit_section'),
      ),
      selfAdjustSection: ActionSection.fromJson(
        _requireMap(json, 'self_adjust_section'),
      ),
      prescriptionNote: _optionalString(json, 'prescription_note'),
      closing: _requireString(json, 'closing'),
    );
  }
}

class TriageBanner {
  final String tierEmoji;
  final String tierDisplay;
  final String statement;

  const TriageBanner({
    required this.tierEmoji,
    required this.tierDisplay,
    required this.statement,
  });

  factory TriageBanner.fromJson(Map<String, dynamic> json) => TriageBanner(
        tierEmoji: _requireString(json, 'tier_emoji'),
        tierDisplay: _requireString(json, 'tier_display'),
        statement: _requireString(json, 'statement'),
      );
}

class ActionSection {
  final bool present;
  final String heading;
  final String? body;
  final List<ActionCard> actionCards;

  const ActionSection({
    required this.present,
    required this.heading,
    required this.body,
    required this.actionCards,
  });

  factory ActionSection.fromJson(Map<String, dynamic> json) => ActionSection(
        present: _requireBool(json, 'present'),
        heading: _requireString(json, 'heading'),
        body: _optionalString(json, 'body'),
        actionCards:
            _mapObjectList(json, 'action_cards', ActionCard.fromJson),
      );
}

class ActionCard {
  final String actionVerb;
  final String targetProduct;
  final String rationale;

  const ActionCard({
    required this.actionVerb,
    required this.targetProduct,
    required this.rationale,
  });

  factory ActionCard.fromJson(Map<String, dynamic> json) => ActionCard(
        actionVerb: _requireString(json, 'action_verb'),
        targetProduct: _requireString(json, 'target_product'),
        rationale: _requireString(json, 'rationale'),
      );
}

// ---------------------------------------------------------------------------
// JSON parsing helpers (file-private)
// ---------------------------------------------------------------------------

String _requireString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! String) {
    throw FormatException(
      'Claude response: expected String at "$key", got ${value.runtimeType}',
    );
  }
  return value;
}

String? _optionalString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value == null) return null;
  if (value is! String) {
    throw FormatException(
      'Claude response: expected String? at "$key", got ${value.runtimeType}',
    );
  }
  return value;
}

bool _requireBool(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! bool) {
    throw FormatException(
      'Claude response: expected bool at "$key", got ${value.runtimeType}',
    );
  }
  return value;
}

Map<String, dynamic> _requireMap(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! Map<String, dynamic>) {
    throw FormatException(
      'Claude response: expected object at "$key", got ${value.runtimeType}',
    );
  }
  return value;
}

List<dynamic> _requireList(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! List) {
    throw FormatException(
      'Claude response: expected array at "$key", got ${value.runtimeType}',
    );
  }
  return value;
}

List<String> _requireStringList(Map<String, dynamic> json, String key) {
  final list = _requireList(json, key);
  return list.map((e) {
    if (e is! String) {
      throw FormatException(
        'Claude response: expected String element in "$key", '
        'got ${e.runtimeType}',
      );
    }
    return e;
  }).toList();
}

List<T> _mapObjectList<T>(
  Map<String, dynamic> json,
  String key,
  T Function(Map<String, dynamic>) mapper,
) {
  final list = _requireList(json, key);
  return list.map((e) {
    if (e is! Map<String, dynamic>) {
      throw FormatException(
        'Claude response: expected object element in "$key", '
        'got ${e.runtimeType}',
      );
    }
    return mapper(e);
  }).toList();
}

void _requireSectionDiscriminator(
  Map<String, dynamic> json,
  String expected,
) {
  final actual = _requireString(json, 'section');
  if (actual != expected) {
    throw FormatException(
      'Claude response: expected section "$expected", got "$actual"',
    );
  }
}
