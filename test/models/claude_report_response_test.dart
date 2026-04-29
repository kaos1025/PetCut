// test/models/claude_report_response_test.dart
//
// PetCut — ClaudeReportResponse strict-fromJson tests
// ----------------------------------------------------------------------------
// Verifies that ClaudeReportResponse.fromJson:
//   1. Round-trips a fully populated 5-section response.
//   2. Preserves nullable fields verbatim (related_flags_note, species_note,
//      ActionSection.body, prescription_note).
//   3. Throws FormatException for every schema violation:
//      - missing top-level field
//      - wrong number of sections
//      - unknown section discriminator
//      - missing required field within a section
//      - wrong type within a section (string where list expected, etc.)
//      - missing one of the 5 required sections (e.g., §3 absent)
// ----------------------------------------------------------------------------

import 'package:flutter_test/flutter_test.dart';
import 'package:petcut/models/claude_report_response.dart';

// ---------------------------------------------------------------------------
// Section body factories (independent per-test fixtures)
// ---------------------------------------------------------------------------

Map<String, dynamic> _section1Body() => <String, dynamic>{
      'section': 'pet_risk_profile',
      'title': 'Pet Risk Profile',
      'pet_summary_line':
          'Buddy — Adult Doberman Pinscher, 30 kg (66 lbs). 2 products analyzed.',
      'body': 'This report is tailored to Buddy...',
      'sensitivity_notes': <Map<String, dynamic>>[
        <String, dynamic>{
          'flag_key': 'copper_sensitive_breed',
          'display_label': 'Copper-sensitive breed',
          'note': 'Dobermans are predisposed to copper accumulation...',
        },
      ],
      'transition': 'The next section breaks down nutrient load...',
    };

Map<String, dynamic> _section2Body() => <String, dynamic>{
      'section': 'combo_load_report',
      'title': 'Combo Load Report',
      'intro': 'This section breaks down nutrient intake...',
      'headline': <String, dynamic>{
        'statement': 'Vitamin D3 is elevated for Buddy.',
        'detail': 'Iron is also above typical for size.',
      },
      'nutrient_cards': <Map<String, dynamic>>[
        <String, dynamic>{
          'nutrient': 'vitamin_d3',
          'display_name': 'Vitamin D3',
          'status_badge': 'caution',
          'headline_number': <String, dynamic>{
            'primary': '16.7% of limit',
            'secondary': '33.4 IU/kg BW/day (limit: 200)',
          },
          'source_line':
              'From food: 502.8 IU (50%) + supplement: 500 IU (50%)',
          'body': 'Vitamin D3 regulates calcium absorption...',
          'limit_source_note': 'Based on NRC 2006 chronic intake threshold.',
        },
      ],
      'safe_nutrients_summary':
          'Calcium and zinc levels are within ideal ranges.',
      'closing': 'The next section explains why specific ingredients...',
    };

Map<String, dynamic> _section3Body() => <String, dynamic>{
      'section': 'mechanism_interaction_alerts',
      'title': 'Mechanism & Interaction Alerts',
      'intro': 'This section explains why specific combinations...',
      'headline': <String, dynamic>{
        'statement': 'Two mechanism interactions flagged.',
        'detail': 'One warning, one caution.',
      },
      'alert_cards': <Map<String, dynamic>>[
        <String, dynamic>{
          'primary_conflict_type': 'hemolytic_risk',
          'display_name': 'Hemolytic Risk from Allium Ingredients',
          'severity_badge': 'warning',
          'involved_summary': 'Garlic powder in Blue Buffalo Senior',
          'body': 'Allium family ingredients contain n-propyl disulfide...',
          'related_flags_note':
              'Garlic powder is specifically listed on the food label.',
        },
        <String, dynamic>{
          'primary_conflict_type': 'anticoagulant_stacking',
          'display_name': 'Anticoagulant Stacking Risk',
          'severity_badge': 'caution',
          'involved_summary':
              'Fish oil, turmeric, and vitamin E across food and supplement',
          'body': 'Several ingredients reduce clotting capacity...',
          'related_flags_note': null,
        },
      ],
      'standalone_flags_summary': <String, dynamic>{
        'present': true,
        'cards': <Map<String, dynamic>>[
          <String, dynamic>{
            'ingredient': 'Senior formula',
            'flag_type': 'life_stage_mismatch',
            'severity_badge': 'caution',
            'body': 'Senior-targeted food given to an adult dog...',
          },
        ],
      },
      'closing': 'The next section turns to observation...',
    };

Map<String, dynamic> _section4Body() => <String, dynamic>{
      'section': 'observable_warning_signs',
      'title': 'Observable Warning Signs',
      'intro': 'Because pets cannot tell us when something feels off...',
      'risk_sections': <Map<String, dynamic>>[
        <String, dynamic>{
          'risk_key': 'd3_excess',
          'display_name': 'Vitamin D3 Excess',
          'tier_badge': 'monitor',
          'species_note': null,
          'body': 'Over the next 3 days, pay attention to drinking...',
          'early_signs_header': 'Early signs to watch for:',
          'early_signs': <String>[
            'Drinking noticeably more water than usual',
            'Urinating more often or having accidents indoors',
          ],
          'escalate_signs_header': 'Contact your vet immediately if you see:',
          'escalate_signs': <String>[
            'Vomiting more than twice within 24 hours',
            'Muscle tremors or seizures',
          ],
        },
      ],
      'closing': 'If Buddy shows none of these signs...',
    };

Map<String, dynamic> _section5Body() => <String, dynamic>{
      'section': 'action_plan_vet_escalation',
      'title': 'Action Plan',
      'intro': 'This section translates everything above into action...',
      'triage_banner': <String, dynamic>{
        'tier_emoji': '🟡',
        'tier_display': 'Mention at Next Vet Visit',
        'statement': 'This combo is worth bringing up at next visit.',
      },
      'urgent_section': <String, dynamic>{
        'present': false,
        'heading': 'Contact Your Vet Today',
        'body': null,
        'action_cards': <Map<String, dynamic>>[],
      },
      'next_visit_section': <String, dynamic>{
        'present': true,
        'heading': 'Mention at Next Vet Visit',
        'body': 'Two items land in this tier...',
        'action_cards': <Map<String, dynamic>>[
          <String, dynamic>{
            'action_verb': 'stop',
            'target_product': 'Zesty Paws 8-in-1 Multi',
            'rationale':
                'The supplement contributes turmeric and vitamin E...',
          },
        ],
      },
      'self_adjust_section': <String, dynamic>{
        'present': false,
        'heading': 'Safe to Adjust at Home',
        'body': null,
        'action_cards': <Map<String, dynamic>>[],
      },
      'prescription_note':
          'If your pet is currently taking any prescription medication...',
      'closing':
          'You now have a clear picture of Buddy\'s current combo...',
    };

Map<String, dynamic> _fullSuccessJson() => <String, dynamic>{
      'report_version': 'v1',
      // List<dynamic> mirrors how jsonDecode emits arrays in production —
      // also lets per-test mutation insert non-Map sentinels for negative tests.
      'sections': <dynamic>[
        _section1Body(),
        _section2Body(),
        _section3Body(),
        _section4Body(),
        _section5Body(),
      ],
    };

void main() {
  group('ClaudeReportResponse.fromJson — success path', () {
    test('fully populated 5-section response parses without throwing', () {
      final response = ClaudeReportResponse.fromJson(_fullSuccessJson());

      expect(response.reportVersion, 'v1');

      // §1
      expect(response.section1.section, 'pet_risk_profile');
      expect(
        response.section1.petSummaryLine,
        startsWith('Buddy — Adult Doberman Pinscher'),
      );
      expect(response.section1.sensitivityNotes.length, 1);
      expect(
        response.section1.sensitivityNotes.first.flagKey,
        'copper_sensitive_breed',
      );

      // §2
      expect(response.section2.section, 'combo_load_report');
      expect(response.section2.headline.statement,
          'Vitamin D3 is elevated for Buddy.');
      expect(response.section2.nutrientCards.length, 1);
      expect(
        response.section2.nutrientCards.first.headlineNumber.primary,
        '16.7% of limit',
      );

      // §3
      expect(response.section3.section, 'mechanism_interaction_alerts');
      expect(response.section3.alertCards.length, 2);
      expect(
        response.section3.alertCards[0].relatedFlagsNote,
        startsWith('Garlic powder is specifically listed'),
      );
      expect(response.section3.alertCards[1].relatedFlagsNote, isNull);
      expect(response.section3.standaloneFlagsSummary.present, isTrue);
      expect(response.section3.standaloneFlagsSummary.cards.length, 1);

      // §4
      expect(response.section4.section, 'observable_warning_signs');
      expect(response.section4.riskSections.length, 1);
      expect(response.section4.riskSections.first.tierBadge, 'monitor');
      expect(response.section4.riskSections.first.speciesNote, isNull);
      expect(
        response.section4.riskSections.first.earlySigns.length,
        2,
      );

      // §5
      expect(response.section5.section, 'action_plan_vet_escalation');
      expect(response.section5.triageBanner.tierEmoji, '🟡');
      expect(response.section5.urgentSection.present, isFalse);
      expect(response.section5.urgentSection.body, isNull);
      expect(response.section5.urgentSection.actionCards, isEmpty);
      expect(response.section5.nextVisitSection.present, isTrue);
      expect(response.section5.nextVisitSection.actionCards.length, 1);
      expect(
        response.section5.prescriptionNote,
        startsWith('If your pet is currently taking'),
      );
    });

    test('§4 species_note non-null is preserved (cat case)', () {
      final json = _fullSuccessJson();
      final risk = (json['sections'] as List)[3] as Map<String, dynamic>;
      ((risk['risk_sections'] as List).first as Map<String, dynamic>)
          ['species_note'] = 'For cats: signs may appear 3-5 days after exposure.';

      final response = ClaudeReportResponse.fromJson(json);
      expect(
        response.section4.riskSections.first.speciesNote,
        'For cats: signs may appear 3-5 days after exposure.',
      );
    });

    test('§5 prescription_note=null is preserved', () {
      final json = _fullSuccessJson();
      (json['sections'] as List)[4]['prescription_note'] = null;

      final response = ClaudeReportResponse.fromJson(json);
      expect(response.section5.prescriptionNote, isNull);
    });
  });

  group('ClaudeReportResponse.fromJson — top-level violations', () {
    test('missing report_version throws FormatException', () {
      final json = _fullSuccessJson()..remove('report_version');
      expect(
        () => ClaudeReportResponse.fromJson(json),
        throwsA(isA<FormatException>()),
      );
    });

    test('report_version wrong type throws FormatException', () {
      final json = _fullSuccessJson()..['report_version'] = 1;
      expect(
        () => ClaudeReportResponse.fromJson(json),
        throwsA(isA<FormatException>()),
      );
    });

    test('sections not a list throws FormatException', () {
      final json = _fullSuccessJson()..['sections'] = 'not a list';
      expect(
        () => ClaudeReportResponse.fromJson(json),
        throwsA(isA<FormatException>()),
      );
    });

    test('sections length != 5 throws FormatException', () {
      final json = _fullSuccessJson();
      (json['sections'] as List).removeLast();
      expect(
        () => ClaudeReportResponse.fromJson(json),
        throwsA(isA<FormatException>()),
      );
    });

    test('section item not an object throws FormatException', () {
      final json = _fullSuccessJson();
      (json['sections'] as List)[0] = 'not an object';
      expect(
        () => ClaudeReportResponse.fromJson(json),
        throwsA(isA<FormatException>()),
      );
    });

    test('unknown section discriminator throws FormatException', () {
      final json = _fullSuccessJson();
      ((json['sections'] as List)[0] as Map<String, dynamic>)['section'] =
          'invalid_section_name';
      expect(
        () => ClaudeReportResponse.fromJson(json),
        throwsA(isA<FormatException>()),
      );
    });

    test('missing one required section (§3 omitted) throws FormatException',
        () {
      // Replace §3 with a duplicate §1, leaving §3 missing entirely.
      final json = _fullSuccessJson();
      (json['sections'] as List)[2] = _section1Body();
      expect(
        () => ClaudeReportResponse.fromJson(json),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('ClaudeReportResponse.fromJson — section-level violations', () {
    test('§1 missing pet_summary_line throws FormatException', () {
      final json = _fullSuccessJson();
      ((json['sections'] as List)[0] as Map<String, dynamic>)
          .remove('pet_summary_line');
      expect(
        () => ClaudeReportResponse.fromJson(json),
        throwsA(isA<FormatException>()),
      );
    });

    test('§2 nutrient_cards is a string (not a list) throws FormatException',
        () {
      final json = _fullSuccessJson();
      ((json['sections'] as List)[1] as Map<String, dynamic>)
          ['nutrient_cards'] = 'not a list';
      expect(
        () => ClaudeReportResponse.fromJson(json),
        throwsA(isA<FormatException>()),
      );
    });

    test(
      '§2 headline missing statement throws FormatException',
      () {
        final json = _fullSuccessJson();
        ((((json['sections'] as List)[1] as Map<String, dynamic>)['headline'])
                as Map<String, dynamic>)
            .remove('statement');
        expect(
          () => ClaudeReportResponse.fromJson(json),
          throwsA(isA<FormatException>()),
        );
      },
    );

    test(
      '§3 standalone_flags_summary missing present throws FormatException',
      () {
        final json = _fullSuccessJson();
        (((json['sections'] as List)[2] as Map<String, dynamic>)
                ['standalone_flags_summary'] as Map<String, dynamic>)
            .remove('present');
        expect(
          () => ClaudeReportResponse.fromJson(json),
          throwsA(isA<FormatException>()),
        );
      },
    );

    test('§4 early_signs contains a non-string throws FormatException', () {
      final json = _fullSuccessJson();
      final risk = ((json['sections'] as List)[3] as Map<String, dynamic>);
      ((risk['risk_sections'] as List).first as Map<String, dynamic>)
          ['early_signs'] = <dynamic>['valid string', 42];
      expect(
        () => ClaudeReportResponse.fromJson(json),
        throwsA(isA<FormatException>()),
      );
    });

    test(
      '§5 urgent_section missing action_cards throws FormatException',
      () {
        final json = _fullSuccessJson();
        (((json['sections'] as List)[4] as Map<String, dynamic>)
                ['urgent_section'] as Map<String, dynamic>)
            .remove('action_cards');
        expect(
          () => ClaudeReportResponse.fromJson(json),
          throwsA(isA<FormatException>()),
        );
      },
    );

    test(
      '§3 alert_cards element wrong type throws FormatException',
      () {
        final json = _fullSuccessJson();
        ((json['sections'] as List)[2] as Map<String, dynamic>)
            ['alert_cards'] = <dynamic>['not an object'];
        expect(
          () => ClaudeReportResponse.fromJson(json),
          throwsA(isA<FormatException>()),
        );
      },
    );

    test(
      '§5 prescription_note wrong type (number) throws FormatException',
      () {
        final json = _fullSuccessJson();
        ((json['sections'] as List)[4] as Map<String, dynamic>)
            ['prescription_note'] = 42;
        expect(
          () => ClaudeReportResponse.fromJson(json),
          throwsA(isA<FormatException>()),
        );
      },
    );
  });

  group('ClaudeReportResponseSectionId constants', () {
    test('section keys match Output Schema discriminators', () {
      expect(ClaudeReportResponseSectionId.section1, 'pet_risk_profile');
      expect(ClaudeReportResponseSectionId.section2, 'combo_load_report');
      expect(
        ClaudeReportResponseSectionId.section3,
        'mechanism_interaction_alerts',
      );
      expect(
        ClaudeReportResponseSectionId.section4,
        'observable_warning_signs',
      );
      expect(
        ClaudeReportResponseSectionId.section5,
        'action_plan_vet_escalation',
      );
    });
  });
}
