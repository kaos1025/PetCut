// test/services/claude_report_service_test.dart
//
// PetCut — ClaudeReportService orchestration tests
// ----------------------------------------------------------------------------
// Covers:
//   1. Envelope assembly — sections in canonical order, pet_context
//      reuses §1's pet block, gemini_summary triages 3 alert sources.
//   2. Response parse path — happy path, JSON-parse retry, schema-fail
//      retry, code-fence stripping.
//   3. Error propagation — ClaudeApiException and TimeoutException are
//      surfaced verbatim and never retried at the service level (the
//      transport layer has already applied its own retry policy).
// ----------------------------------------------------------------------------

import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:petcut/models/claude_report_request.dart';
import 'package:petcut/models/pet_profile.dart';
import 'package:petcut/models/petcut_analysis_result.dart';
import 'package:petcut/services/claude_api_client.dart';
import 'package:petcut/services/claude_report_service.dart';

class _MockClaudeApiClient extends Mock implements ClaudeApiClient {}

// ---------------------------------------------------------------------------
// Fixtures
// ---------------------------------------------------------------------------

String _fixture(String name) =>
    File('test/fixtures/claude_responses/$name').readAsStringSync();

PetProfile _pet({
  String name = 'Buddy',
  Species species = Species.dog,
  String? breed = 'Doberman Pinscher',
  double weight = 30.0,
  WeightUnit weightUnit = WeightUnit.kg,
  LifeStage lifeStage = LifeStage.adult,
}) =>
    PetProfile(
      name: name,
      species: species,
      breed: breed,
      weight: weight,
      weightUnit: weightUnit,
      lifeStage: lifeStage,
      ageYears: 4.0,
    );

PetcutAnalysisResult _result({
  String overallStatus = 'caution',
  String summary = 'Mixed status combo.',
  List<NutrientTotal> nutrients = const <NutrientTotal>[],
  List<MechanismConflict> mechanisms = const <MechanismConflict>[],
  List<ExclusionRecommendation> exclusions =
      const <ExclusionRecommendation>[],
  List<PetcutProduct> products = const <PetcutProduct>[],
}) =>
    PetcutAnalysisResult(
      products: products,
      comboAnalysis: PetcutComboAnalysis(
        nutrientTotals: nutrients,
        mechanismConflicts: mechanisms,
        exclusionRecommendations: exclusions,
      ),
      overallStatus: overallStatus,
      overallSummary: summary,
    );

// ---------------------------------------------------------------------------
// Mocktail when() helper — captures both named args without repetition
// ---------------------------------------------------------------------------

When<Future<String>> _whenPost(ClaudeApiClient mock) => when(
      () => mock.postMessages(
        systemPrompt: any(named: 'systemPrompt'),
        userPrompt: any(named: 'userPrompt'),
      ),
    );

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  late _MockClaudeApiClient mockClient;
  late ClaudeReportService service;

  setUp(() {
    mockClient = _MockClaudeApiClient();
    service = ClaudeReportService(apiClient: mockClient);
  });

  // -------------------------------------------------------------------------
  // Envelope assembly — pure, no network
  // -------------------------------------------------------------------------
  group('ClaudeReportService.assembleEnvelope — sections', () {
    test('sections array has 5 entries in canonical section_id order', () {
      final envelope = service.assembleEnvelope(
        geminiResult: _result(),
        pet: _pet(),
      );
      final ids = envelope.sections.map((s) => s.sectionId).toList();
      expect(ids, <String>[
        'section_1_pet_risk_profile',
        'section_2_combo_load_report',
        'section_3_mechanism_interaction_alerts',
        'section_4_observable_warning_signs',
        'section_5_action_plan_vet_escalation',
      ]);
    });

    test('report_request_version is "v1"', () {
      final envelope = service.assembleEnvelope(
        geminiResult: _result(),
        pet: _pet(),
      );
      expect(envelope.reportRequestVersion, 'v1');
    });
  });

  // -------------------------------------------------------------------------
  // pet_context — §1 pet block reused verbatim (single source of truth)
  // -------------------------------------------------------------------------
  group('ClaudeReportService.assembleEnvelope — pet_context', () {
    test('pet_context mirrors §1 pet block including weight_display', () {
      final envelope = service.assembleEnvelope(
        geminiResult: _result(),
        pet: _pet(weight: 66.0, weightUnit: WeightUnit.lbs),
      );

      // §1 InputBuilder is the canonical formatter (d7497f9 origin-unit
      // branching). pet_context must echo that block exactly.
      final s1Pet =
          envelope.sections[0].input['pet'] as Map<String, dynamic>;
      expect(envelope.petContext, equals(s1Pet));
      expect(envelope.petContext['weight_display'], '66 lbs (30 kg)');
    });
  });

  // -------------------------------------------------------------------------
  // gemini_summary — overall_status, summary, key_alerts triage
  // -------------------------------------------------------------------------
  group('ClaudeReportService.assembleEnvelope — gemini_summary', () {
    test('overall_status and summary echo the Gemini result', () {
      final envelope = service.assembleEnvelope(
        geminiResult: _result(
          overallStatus: 'warning',
          summary: 'D3 elevated; iron stacking.',
        ),
        pet: _pet(),
      );
      expect(envelope.geminiSummary['overall_status'], 'warning');
      expect(
        envelope.geminiSummary['summary'],
        'D3 elevated; iron stacking.',
      );
    });

    test(
        'key_alerts triages 3 sources: mechanism (warning|critical), '
        'flag (critical), nutrient (warning|critical)', () {
      final envelope = service.assembleEnvelope(
        geminiResult: _result(
          mechanisms: const <MechanismConflict>[
            MechanismConflict(
              conflictType: 'hemolytic_risk',
              involvedIngredients: <String>['garlic'],
              involvedProducts: <String>['Food X'],
              severity: 'warning',
              explanation: 'irrelevant for triage',
            ),
            MechanismConflict(
              conflictType: 'minor_pattern',
              involvedIngredients: <String>['turmeric'],
              involvedProducts: <String>['Supp Y'],
              severity: 'caution',
              explanation: 'caution should NOT promote to key_alerts',
            ),
          ],
          products: <PetcutProduct>[
            const PetcutProduct(
              productName: 'Food X',
              productType: 'food',
              ingredientsRaw: '',
              keyNutrients: <KeyNutrient>[],
              flaggedIngredients: <FlaggedIngredient>[
                FlaggedIngredient(
                  ingredient: 'xylitol',
                  reason: 'toxic_to_species',
                  severity: 'critical',
                  detail: '',
                ),
                FlaggedIngredient(
                  ingredient: 'fish oil',
                  reason: 'cumulative_risk',
                  severity: 'caution',
                  detail: 'caution should NOT promote',
                ),
              ],
            ),
          ],
          nutrients: const <NutrientTotal>[
            NutrientTotal(
              nutrient: 'iron',
              totalDailyIntake: 200,
              unit: 'mg',
              sources: <String>[],
              status: 'warning',
            ),
            NutrientTotal(
              nutrient: 'zinc',
              totalDailyIntake: 5,
              unit: 'mg',
              sources: <String>[],
              status: 'safe',
            ),
          ],
        ),
        pet: _pet(),
      );

      final alerts =
          (envelope.geminiSummary['key_alerts'] as List).cast<Map>();
      final types = alerts.map((a) => a['type']).toList();
      expect(types, containsAll(<String>['mechanism', 'flag', 'nutrient']));
      expect(alerts.length, 3); // 1 mechanism + 1 flag + 1 nutrient
    });

    test('caution-only signals produce no key_alerts', () {
      final envelope = service.assembleEnvelope(
        geminiResult: _result(
          mechanisms: const <MechanismConflict>[
            MechanismConflict(
              conflictType: 'soft_pattern',
              involvedIngredients: <String>[],
              involvedProducts: <String>[],
              severity: 'caution',
              explanation: '',
            ),
          ],
        ),
        pet: _pet(),
      );
      expect(envelope.geminiSummary['key_alerts'], isEmpty);
    });
  });

  // -------------------------------------------------------------------------
  // generateReport — happy path (1 API call)
  // -------------------------------------------------------------------------
  group('ClaudeReportService.generateReport — happy path', () {
    test('success_full fixture parses into typed ClaudeReportResponse',
        () async {
      _whenPost(mockClient)
          .thenAnswer((_) async => _fixture('success_full.json'));

      final response = await service.generateReport(
        geminiResult: _result(),
        pet: _pet(),
      );

      expect(response.reportVersion, 'v1');
      expect(response.section1.section, 'pet_risk_profile');
      expect(response.section3.alertCards.length, 1);
      expect(response.section5.triageBanner.tierEmoji, '🟡');
      verify(
        () => mockClient.postMessages(
          systemPrompt: any(named: 'systemPrompt'),
          userPrompt: any(named: 'userPrompt'),
        ),
      ).called(1);
    });

    test('code-fenced response (```json ... ```) is stripped before parsing',
        () async {
      final fenced = '```json\n${_fixture('success_full.json')}\n```';
      _whenPost(mockClient).thenAnswer((_) async => fenced);

      final response = await service.generateReport(
        geminiResult: _result(),
        pet: _pet(),
      );
      expect(response.reportVersion, 'v1');
    });
  });

  // -------------------------------------------------------------------------
  // generateReport — single JSON-parse retry path (STATUS §4.4)
  // -------------------------------------------------------------------------
  group('ClaudeReportService.generateReport — JSON-parse retry', () {
    test('malformed JSON then success_full → recovers, 2 calls', () async {
      var calls = 0;
      _whenPost(mockClient).thenAnswer((_) async {
        calls++;
        return calls == 1
            ? _fixture('malformed_json.json')
            : _fixture('success_full.json');
      });

      final response = await service.generateReport(
        geminiResult: _result(),
        pet: _pet(),
      );
      expect(response.reportVersion, 'v1');
      expect(calls, 2);
    });

    test('malformed JSON twice → throws FormatException, 2 calls', () async {
      _whenPost(mockClient)
          .thenAnswer((_) async => _fixture('malformed_json.json'));

      await expectLater(
        service.generateReport(geminiResult: _result(), pet: _pet()),
        throwsA(isA<FormatException>()),
      );
      verify(
        () => mockClient.postMessages(
          systemPrompt: any(named: 'systemPrompt'),
          userPrompt: any(named: 'userPrompt'),
        ),
      ).called(2);
    });

    test('schema violation then success_full → recovers, 2 calls', () async {
      var calls = 0;
      _whenPost(mockClient).thenAnswer((_) async {
        calls++;
        return calls == 1
            ? _fixture('invalid_schema.json')
            : _fixture('success_full.json');
      });

      final response = await service.generateReport(
        geminiResult: _result(),
        pet: _pet(),
      );
      expect(response.reportVersion, 'v1');
      expect(calls, 2);
    });

    test('schema violation twice → throws FormatException', () async {
      _whenPost(mockClient)
          .thenAnswer((_) async => _fixture('invalid_schema.json'));

      await expectLater(
        service.generateReport(geminiResult: _result(), pet: _pet()),
        throwsA(isA<FormatException>()),
      );
    });

    test(
        'partial_section3_missing then success_full → recovers, '
        'demonstrates schema-violation-as-FormatException retry path',
        () async {
      var calls = 0;
      _whenPost(mockClient).thenAnswer((_) async {
        calls++;
        return calls == 1
            ? _fixture('partial_section3_missing.json')
            : _fixture('success_full.json');
      });

      final response = await service.generateReport(
        geminiResult: _result(),
        pet: _pet(),
      );
      expect(response.section3.section, 'mechanism_interaction_alerts');
      expect(calls, 2);
    });
  });

  // -------------------------------------------------------------------------
  // generateReport — transport-layer errors propagate without service retry
  // -------------------------------------------------------------------------
  group('ClaudeReportService.generateReport — transport errors', () {
    test('ClaudeApiException is propagated verbatim, no service retry',
        () async {
      _whenPost(mockClient).thenThrow(
        const ClaudeApiException(
          message: 'Server error after retry',
          statusCode: 500,
          requestId: 'req-x',
        ),
      );

      await expectLater(
        service.generateReport(geminiResult: _result(), pet: _pet()),
        throwsA(
          isA<ClaudeApiException>()
              .having((e) => e.statusCode, 'statusCode', 500),
        ),
      );
      verify(
        () => mockClient.postMessages(
          systemPrompt: any(named: 'systemPrompt'),
          userPrompt: any(named: 'userPrompt'),
        ),
      ).called(1);
    });

    test('TimeoutException is propagated verbatim, no service retry',
        () async {
      _whenPost(mockClient).thenThrow(
        TimeoutException('client gave up'),
      );

      await expectLater(
        service.generateReport(geminiResult: _result(), pet: _pet()),
        throwsA(isA<TimeoutException>()),
      );
      verify(
        () => mockClient.postMessages(
          systemPrompt: any(named: 'systemPrompt'),
          userPrompt: any(named: 'userPrompt'),
        ),
      ).called(1);
    });
  });

  // -------------------------------------------------------------------------
  // generateReport — prompt content uses ClaudePromptPet helpers
  // -------------------------------------------------------------------------
  group('ClaudeReportService.generateReport — prompt assembly', () {
    test(
        'system prompt includes all 5 section blocks; user prompt includes '
        'envelope JSON with the canonical 5 section_ids', () async {
      String? capturedSystem;
      String? capturedUser;
      _whenPost(mockClient).thenAnswer((invocation) async {
        capturedSystem = invocation.namedArguments[#systemPrompt] as String;
        capturedUser = invocation.namedArguments[#userPrompt] as String;
        return _fixture('success_full.json');
      });

      await service.generateReport(geminiResult: _result(), pet: _pet());

      expect(capturedSystem, contains('[§1 — Pet Risk Profile]'));
      expect(capturedSystem, contains('[§5 — Action Plan'));
      expect(capturedUser, contains('OUTPUT SCHEMA'));
      expect(capturedUser, contains(ClaudeReportRequest.section1Id));
      expect(capturedUser, contains(ClaudeReportRequest.section5Id));
    });
  });
}
