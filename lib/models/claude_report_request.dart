// PetCut — Claude Report Request envelope model
// ----------------------------------------------------------------------------
// Typed envelope sent to Claude Sonnet for paid report generation.
//
// Schema (STATUS_0428 §4.2):
// {
//   "report_request_version": "v1",
//   "pet_context": { ... },
//   "gemini_summary": { "overall_status": "...", "key_alerts": [ ... ] },
//   "sections": [
//     { "section_id": "section_1_pet_risk_profile",         "input": { ... } },
//     { "section_id": "section_2_combo_load_report",        "input": { ... } },
//     { "section_id": "section_3_mechanism_interaction_alerts", "input": { ... } },
//     { "section_id": "section_4_observable_warning_signs", "input": { ... } },
//     { "section_id": "section_5_action_plan_vet_escalation",   "input": { ... } }
//   ]
// }
//
// fromJson is intentionally absent — this model is request-only.
// ----------------------------------------------------------------------------

class ClaudeReportRequest {
  static const String currentVersion = 'v1';

  static const String section1Id = 'section_1_pet_risk_profile';
  static const String section2Id = 'section_2_combo_load_report';
  static const String section3Id = 'section_3_mechanism_interaction_alerts';
  static const String section4Id = 'section_4_observable_warning_signs';
  static const String section5Id = 'section_5_action_plan_vet_escalation';

  final String reportRequestVersion;
  final Map<String, dynamic> petContext;
  final Map<String, dynamic> geminiSummary;
  final List<ClaudeSectionInput> sections;

  const ClaudeReportRequest({
    this.reportRequestVersion = currentVersion,
    required this.petContext,
    required this.geminiSummary,
    required this.sections,
  });

  Map<String, dynamic> toJson() => <String, dynamic>{
        'report_request_version': reportRequestVersion,
        'pet_context': petContext,
        'gemini_summary': geminiSummary,
        'sections': sections.map((s) => s.toJson()).toList(),
      };
}

class ClaudeSectionInput {
  final String sectionId;
  final Map<String, dynamic> input;

  const ClaudeSectionInput({
    required this.sectionId,
    required this.input,
  });

  Map<String, dynamic> toJson() => <String, dynamic>{
        'section_id': sectionId,
        'input': input,
      };
}
