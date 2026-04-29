// test/integration/claude_report_service_live_test.dart
//
// PetCut — LIVE integration test against the real Anthropic Messages API.
// Excluded from default `flutter test` runs by the [@Tags(['live'])]
// marker. Invoke explicitly:
//   flutter test --tags live test/integration/claude_report_service_live_test.dart
//
// Requires `.env` with a valid ANTHROPIC_API_KEY at the project root.
// One report = one billable API call (~16k max output tokens worth of
// budget). NEVER prints the API key or full response body — only
// metrics and section headlines.
// ----------------------------------------------------------------------------

@Tags(<String>['live'])
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:petcut/models/pet_profile.dart';
import 'package:petcut/models/petcut_analysis_result.dart';
import 'package:petcut/services/claude_api_client.dart';
import 'package:petcut/services/claude_report_service.dart';

// ---------------------------------------------------------------------------
// Mock pet + analysis: Golden Retriever scenario (PETCUT_PLANNING.md §1)
// ---------------------------------------------------------------------------

PetProfile _goldenRetriever() => PetProfile(
      name: 'Buddy',
      species: Species.dog,
      breed: 'Golden Retriever',
      weight: 30.0,
      weightUnit: WeightUnit.kg,
      ageYears: 4.0,
      lifeStage: LifeStage.adult,
    );

PetcutAnalysisResult _scenario1() => const PetcutAnalysisResult(
      products: <PetcutProduct>[
        PetcutProduct(
          productName: 'Blue Buffalo Adult Chicken & Brown Rice',
          productType: 'food',
          brand: 'Blue Buffalo',
          ingredientsRaw:
              'Deboned Chicken, Chicken Meal, Brown Rice, Barley, '
              'Oatmeal, Chicken Fat, Flaxseed, Fish Oil, Vitamin D3 supplement, '
              'Calcium Carbonate, Iron Proteinate.',
          keyNutrients: <KeyNutrient>[
            KeyNutrient(
              nutrient: 'vitamin_d3',
              amount: 502.8,
              unit: 'IU',
              sourceBasis: 'per_day',
            ),
          ],
          flaggedIngredients: <FlaggedIngredient>[],
        ),
        PetcutProduct(
          productName: 'Zesty Paws 8-in-1 Multivitamin Bites',
          productType: 'supplement',
          brand: 'Zesty Paws',
          ingredientsRaw:
              'Vitamin D3, Vitamin E, Glucosamine, Chondroitin, '
              'Turmeric, Fish Oil, Coenzyme Q10.',
          keyNutrients: <KeyNutrient>[
            KeyNutrient(
              nutrient: 'vitamin_d3',
              amount: 500.0,
              unit: 'IU',
              sourceBasis: 'per_serving',
            ),
          ],
          flaggedIngredients: <FlaggedIngredient>[],
        ),
      ],
      comboAnalysis: PetcutComboAnalysis(
        nutrientTotals: <NutrientTotal>[
          NutrientTotal(
            nutrient: 'vitamin_d3',
            totalDailyIntake: 1002.8,
            unit: 'IU',
            sources: <String>[
              'Blue Buffalo Adult: 502.8 IU',
              'Zesty Paws 8-in-1: 500 IU',
            ],
            percentOfLimit: 16.7,
            status: 'caution',
            safeUpperLimit: 200.0,
            safeUpperLimitSource: 'NRC',
          ),
        ],
        mechanismConflicts: <MechanismConflict>[
          MechanismConflict(
            conflictType: 'anticoagulant_stacking',
            involvedIngredients: <String>['fish oil', 'turmeric', 'vitamin E'],
            involvedProducts: <String>[
              'Blue Buffalo Adult Chicken & Brown Rice',
              'Zesty Paws 8-in-1 Multivitamin Bites',
            ],
            severity: 'caution',
            explanation:
                'Multiple blood-thinning ingredients reduce clotting '
                'capacity. Usually not dangerous on its own but compounds '
                'risk during injury, surgery, or anticoagulant therapy.',
          ),
        ],
        exclusionRecommendations: <ExclusionRecommendation>[
          ExclusionRecommendation(
            tier: 3,
            action: 'remove',
            targetProduct: 'Zesty Paws 8-in-1 Multivitamin Bites',
            reason:
                'Three anticoagulant ingredients stacking with fish oil in '
                'food. Supplement may not be needed given food profile.',
          ),
        ],
      ),
      overallStatus: 'caution',
      overallSummary:
          'Vitamin D3 elevated; mild anticoagulant stacking pattern.',
    );

// ---------------------------------------------------------------------------
// Capturing client — wraps a real http call so the test can extract
// token usage AFTER the service flow has run. Implements ClaudeApiClient
// so ClaudeReportService treats it like any other transport.
// ---------------------------------------------------------------------------

class _LiveCapturingApiClient implements ClaudeApiClient {
  final String _apiKey;

  Map<String, dynamic>? lastRawResponse;
  Duration? lastLatency;
  int? lastStatusCode;
  String? lastRequestId;
  int? lastBodySize;

  _LiveCapturingApiClient(this._apiKey);

  @override
  Future<String> postMessages({
    required String systemPrompt,
    required String userPrompt,
  }) async {
    final body = jsonEncode(<String, dynamic>{
      'model': 'claude-sonnet-4-6',
      'max_tokens': 16000,
      'system': systemPrompt,
      'messages': <Map<String, dynamic>>[
        <String, dynamic>{'role': 'user', 'content': userPrompt},
      ],
    });
    lastBodySize = body.length;

    final headers = <String, String>{
      'x-api-key': _apiKey,
      'anthropic-version': '2023-06-01',
      'content-type': 'application/json',
    };

    final stopwatch = Stopwatch()..start();
    final response = await http
        .post(
          Uri.parse('https://api.anthropic.com/v1/messages'),
          headers: headers,
          body: body,
        )
        .timeout(const Duration(seconds: 120));
    stopwatch.stop();

    lastLatency = stopwatch.elapsed;
    lastStatusCode = response.statusCode;
    lastRequestId = response.headers['request-id'];

    if (response.statusCode != 200) {
      // Surface only safe metadata; never the body.
      throw ClaudeApiException(
        message: 'Live API call failed (HTTP ${response.statusCode})',
        statusCode: response.statusCode,
        requestId: lastRequestId,
      );
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    lastRawResponse = decoded;

    final content = decoded['content'];
    if (content is! List) {
      throw const FormatException(
        'Anthropic response missing "content" array',
      );
    }
    for (final block in content) {
      if (block is Map<String, dynamic> && block['type'] == 'text') {
        final text = block['text'];
        if (text is String) return text;
      }
    }
    throw const FormatException('Anthropic response: no text block');
  }
}

// ---------------------------------------------------------------------------
// Helper — load .env from project root without exposing values to stdout
// ---------------------------------------------------------------------------

void _loadDotenvFromProjectRoot() {
  final envFile = File('.env');
  if (!envFile.existsSync()) {
    fail('.env file not found at project root');
  }
  final env = <String, String>{};
  for (final line in envFile.readAsLinesSync()) {
    final trimmed = line.trim();
    if (trimmed.isEmpty || trimmed.startsWith('#')) continue;
    final idx = trimmed.indexOf('=');
    if (idx <= 0) continue;
    env[trimmed.substring(0, idx).trim()] =
        trimmed.substring(idx + 1).trim();
  }
  dotenv.testLoad(mergeWith: env);
}

// ---------------------------------------------------------------------------
// Live test
// ---------------------------------------------------------------------------

void main() {
  setUpAll(_loadDotenvFromProjectRoot);

  test(
    'LIVE: ClaudeReportService.generateReport against real Anthropic API',
    timeout: const Timeout(Duration(seconds: 180)),
    () async {
      final apiKey = dotenv.env['ANTHROPIC_API_KEY'] ?? '';
      if (apiKey.isEmpty) {
        fail('ANTHROPIC_API_KEY not set in .env (or empty)');
      }

      final client = _LiveCapturingApiClient(apiKey);
      final service = ClaudeReportService(apiClient: client);

      final report = await service.generateReport(
        geminiResult: _scenario1(),
        pet: _goldenRetriever(),
      );

      // ---- Metrics extraction ----
      final raw = client.lastRawResponse;
      if (raw == null) {
        fail('Capturing client did not record a response');
      }
      final usage = raw['usage'] as Map<String, dynamic>;
      final inputTokens = (usage['input_tokens'] as num).toInt();
      final outputTokens = (usage['output_tokens'] as num).toInt();
      // Sonnet 4.6 list price (per V6): \$3 / MTok input, \$15 / MTok output.
      final cost =
          inputTokens * 3.0 / 1000000.0 + outputTokens * 15.0 / 1000000.0;

      // ---- Tier distribution for §4 ----
      final tierDistribution = <String, int>{};
      for (final r in report.section4.riskSections) {
        tierDistribution[r.tierBadge] =
            (tierDistribution[r.tierBadge] ?? 0) + 1;
      }

      // ---- Stdout report (metrics + headlines only) ----
      // ignore: avoid_print
      print('\n=== LIVE INTEGRATION TEST RESULT ===');
      // ignore: avoid_print
      print('HTTP status:        ${client.lastStatusCode}');
      // ignore: avoid_print
      print('Request id:         ${client.lastRequestId ?? '(none)'}');
      // ignore: avoid_print
      print(
          'Latency:            ${client.lastLatency!.inMilliseconds} ms');
      // ignore: avoid_print
      print('Request body size:  ${client.lastBodySize} bytes');
      // ignore: avoid_print
      print('Input tokens:       $inputTokens');
      // ignore: avoid_print
      print('Output tokens:      $outputTokens');
      // ignore: avoid_print
      print('Estimated cost:     \$${cost.toStringAsFixed(4)}');
      // ignore: avoid_print
      print('--');
      // ignore: avoid_print
      print('§1 pet_summary_line: "${report.section1.petSummaryLine}"');
      // ignore: avoid_print
      print(
        '§2 headline:         "${report.section2.headline.statement}"',
      );
      // ignore: avoid_print
      print(
        '§2 nutrient_cards:   ${report.section2.nutrientCards.length}'
        '${report.section2.nutrientCards.isEmpty ? '' : ' '
            '(first: ${report.section2.nutrientCards.first.displayName})'}',
      );
      // ignore: avoid_print
      print(
        '§3 headline:         "${report.section3.headline.statement}"',
      );
      // ignore: avoid_print
      print('§3 alert_cards:      ${report.section3.alertCards.length}');
      // ignore: avoid_print
      print(
        '§4 risk_sections:    ${report.section4.riskSections.length} '
        'tiers: $tierDistribution',
      );
      // ignore: avoid_print
      print(
        '§5 triage_banner:    "${report.section5.triageBanner.tierDisplay}"',
      );
      // ignore: avoid_print
      print('=== END ===\n');

      // ---- Assertions ----
      expect(client.lastStatusCode, 200);
      expect(report.reportVersion, 'v1');
      expect(report.section1.section, 'pet_risk_profile');
      expect(report.section2.section, 'combo_load_report');
      expect(report.section3.section, 'mechanism_interaction_alerts');
      expect(report.section4.section, 'observable_warning_signs');
      expect(report.section5.section, 'action_plan_vet_escalation');
    },
  );
}
