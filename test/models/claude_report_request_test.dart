// test/models/claude_report_request_test.dart
//
// PetCut — ClaudeReportRequest envelope serialization tests
// ----------------------------------------------------------------------------
// Verifies that the request envelope serializes to the STATUS_0428 §4.2
// schema verbatim — version, pet_context, gemini_summary, and 5 sections
// in the canonical section_id order.
// ----------------------------------------------------------------------------

import 'package:flutter_test/flutter_test.dart';
import 'package:petcut/models/claude_report_request.dart';

void main() {
  group('ClaudeReportRequest constants', () {
    test('section_id constants follow STATUS schema verbatim', () {
      expect(
        ClaudeReportRequest.section1Id,
        'section_1_pet_risk_profile',
      );
      expect(
        ClaudeReportRequest.section2Id,
        'section_2_combo_load_report',
      );
      expect(
        ClaudeReportRequest.section3Id,
        'section_3_mechanism_interaction_alerts',
      );
      expect(
        ClaudeReportRequest.section4Id,
        'section_4_observable_warning_signs',
      );
      expect(
        ClaudeReportRequest.section5Id,
        'section_5_action_plan_vet_escalation',
      );
    });

    test('currentVersion is "v1"', () {
      expect(ClaudeReportRequest.currentVersion, 'v1');
    });
  });

  group('ClaudeReportRequest.toJson', () {
    test('serializes envelope with 5 sections in canonical order', () {
      final req = ClaudeReportRequest(
        petContext: const <String, dynamic>{
          'name': 'Buddy',
          'weight_display': '30 kg (66 lbs)',
        },
        geminiSummary: const <String, dynamic>{
          'overall_status': 'caution',
          'key_alerts': <Map<String, dynamic>>[],
        },
        sections: const <ClaudeSectionInput>[
          ClaudeSectionInput(
            sectionId: ClaudeReportRequest.section1Id,
            input: <String, dynamic>{'section': 'pet_risk_profile'},
          ),
          ClaudeSectionInput(
            sectionId: ClaudeReportRequest.section2Id,
            input: <String, dynamic>{'section': 'combo_load_report'},
          ),
          ClaudeSectionInput(
            sectionId: ClaudeReportRequest.section3Id,
            input: <String, dynamic>{
              'section': 'mechanism_interaction_alerts',
            },
          ),
          ClaudeSectionInput(
            sectionId: ClaudeReportRequest.section4Id,
            input: <String, dynamic>{'section': 'observable_warning_signs'},
          ),
          ClaudeSectionInput(
            sectionId: ClaudeReportRequest.section5Id,
            input: <String, dynamic>{
              'section': 'action_plan_vet_escalation',
            },
          ),
        ],
      );

      final json = req.toJson();

      expect(json['report_request_version'], 'v1');
      expect(json['pet_context'], <String, dynamic>{
        'name': 'Buddy',
        'weight_display': '30 kg (66 lbs)',
      });
      expect(json['gemini_summary'], <String, dynamic>{
        'overall_status': 'caution',
        'key_alerts': <Map<String, dynamic>>[],
      });

      final sections = json['sections'] as List<dynamic>;
      expect(sections.length, 5);

      expect(
        sections[0],
        <String, dynamic>{
          'section_id': 'section_1_pet_risk_profile',
          'input': <String, dynamic>{'section': 'pet_risk_profile'},
        },
      );
      expect(
        sections[4],
        <String, dynamic>{
          'section_id': 'section_5_action_plan_vet_escalation',
          'input': <String, dynamic>{
            'section': 'action_plan_vet_escalation',
          },
        },
      );
    });

    test('default reportRequestVersion is "v1"', () {
      const req = ClaudeReportRequest(
        petContext: <String, dynamic>{},
        geminiSummary: <String, dynamic>{},
        sections: <ClaudeSectionInput>[],
      );
      expect(req.toJson()['report_request_version'], 'v1');
    });

    test('top-level keys serialize in expected order/set', () {
      const req = ClaudeReportRequest(
        petContext: <String, dynamic>{},
        geminiSummary: <String, dynamic>{},
        sections: <ClaudeSectionInput>[],
      );
      expect(req.toJson().keys.toSet(), {
        'report_request_version',
        'pet_context',
        'gemini_summary',
        'sections',
      });
    });
  });

  group('ClaudeSectionInput.toJson', () {
    test('emits section_id and input keys verbatim', () {
      const input = ClaudeSectionInput(
        sectionId: 'section_1_pet_risk_profile',
        input: <String, dynamic>{'foo': 'bar', 'count': 3},
      );
      expect(input.toJson(), <String, dynamic>{
        'section_id': 'section_1_pet_risk_profile',
        'input': <String, dynamic>{'foo': 'bar', 'count': 3},
      });
    });
  });
}
