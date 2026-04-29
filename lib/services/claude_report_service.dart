// lib/services/claude_report_service.dart
//
// PetCut — Claude Sonnet paid-report orchestration service
// ----------------------------------------------------------------------------
// One paid report = ONE Anthropic API call. This service:
//   1. Assembles the STATUS_0428 §4.2 envelope from a Gemini result + pet.
//   2. Builds the system + user prompts via ClaudePromptPet helpers.
//   3. Calls ClaudeApiClient.postMessages and parses the response into
//      a typed ClaudeReportResponse.
//   4. Applies single JSON-parse retry (STATUS_0428 §4.4): if the first
//      response is not valid JSON or violates the typed schema, one
//      additional API call is made before failing closed.
//
// Layered responsibilities:
//   - Envelope assembly:   this service + lib/services/section{1..5}_input_builder
//   - Transport / network: lib/services/claude_api_client.dart
//   - Wire schema (request/response): lib/models/claude_report_*.dart
//   - System prompt content: lib/prompts/claude_prompt_pet.dart
// ----------------------------------------------------------------------------

import 'dart:convert';

import '../models/claude_report_request.dart';
import '../models/claude_report_response.dart';
import '../models/pet_profile.dart';
import '../models/petcut_analysis_result.dart';
import '../prompts/claude_prompt_pet.dart';
import 'claude_api_client.dart';
import 'section1_input_builder.dart';
import 'section2_input_builder.dart';
import 'section3_input_builder.dart';
import 'section4_input_builder.dart';
import 'section5_input_builder.dart';

class ClaudeReportService {
  final ClaudeApiClient _apiClient;

  ClaudeReportService({required ClaudeApiClient apiClient})
      : _apiClient = apiClient;

  /// Generates the full 5-section paid report. Throws on failure
  /// (caller — UI / IAP refund flow — handles fail-closed UX).
  Future<ClaudeReportResponse> generateReport({
    required PetcutAnalysisResult geminiResult,
    required PetProfile pet,
  }) async {
    final envelope = assembleEnvelope(geminiResult: geminiResult, pet: pet);
    final systemPrompt = ClaudePromptPet.buildSystemPrompt();
    final userPrompt = ClaudePromptPet.buildUserPrompt(envelope.toJson());

    return _callWithJsonParseRetry(
      systemPrompt: systemPrompt,
      userPrompt: userPrompt,
    );
  }

  // --------------------------------------------------------------------------
  // Envelope assembly — public for envelope-shape unit tests
  // --------------------------------------------------------------------------

  /// Assembles the STATUS_0428 §4.2 envelope. Public so unit tests can
  /// verify envelope shape without invoking the network path.
  ClaudeReportRequest assembleEnvelope({
    required PetcutAnalysisResult geminiResult,
    required PetProfile pet,
  }) {
    final s1 = Section1InputBuilder.build(geminiResult: geminiResult, pet: pet);
    final s2 = Section2InputBuilder.build(geminiResult: geminiResult, pet: pet);
    final s3 = Section3InputBuilder.build(geminiResult: geminiResult, pet: pet);
    final s4 = Section4InputBuilder.build(geminiResult: geminiResult, pet: pet);
    final s5 = Section5InputBuilder.build(geminiResult: geminiResult, pet: pet);

    return ClaudeReportRequest(
      petContext: _buildPetContext(s1),
      geminiSummary: _buildGeminiSummary(geminiResult),
      sections: <ClaudeSectionInput>[
        ClaudeSectionInput(
          sectionId: ClaudeReportRequest.section1Id,
          input: s1,
        ),
        ClaudeSectionInput(
          sectionId: ClaudeReportRequest.section2Id,
          input: s2,
        ),
        ClaudeSectionInput(
          sectionId: ClaudeReportRequest.section3Id,
          input: s3,
        ),
        ClaudeSectionInput(
          sectionId: ClaudeReportRequest.section4Id,
          input: s4,
        ),
        ClaudeSectionInput(
          sectionId: ClaudeReportRequest.section5Id,
          input: s5,
        ),
      ],
    );
  }

  /// Re-uses §1 InputBuilder's `pet` block as the canonical pet_context —
  /// guarantees a single source of truth for weight_display etc.
  Map<String, dynamic> _buildPetContext(Map<String, dynamic> s1) {
    final petBlock = s1['pet'] as Map<String, dynamic>;
    return Map<String, dynamic>.from(petBlock);
  }

  /// Triages Gemini's analysis output into a top-level summary that
  /// gives Claude consistent context across the 5 sections.
  ///
  /// key_alerts integrates 3 sources (V2 mapping):
  ///   - mechanism conflicts with severity warning|critical
  ///   - flagged ingredients with severity critical
  ///   - nutrient totals with status warning|critical
  Map<String, dynamic> _buildGeminiSummary(PetcutAnalysisResult result) {
    final keyAlerts = <Map<String, dynamic>>[];

    for (final conflict in result.comboAnalysis.mechanismConflicts) {
      if (conflict.severity == 'warning' || conflict.severity == 'critical') {
        keyAlerts.add(<String, dynamic>{
          'type': 'mechanism',
          'conflict_type': conflict.conflictType,
          'severity': conflict.severity,
          'involved_ingredients':
              List<String>.from(conflict.involvedIngredients),
          'involved_products': List<String>.from(conflict.involvedProducts),
        });
      }
    }

    for (final product in result.products) {
      for (final flag in product.flaggedIngredients) {
        if (flag.severity == 'critical') {
          keyAlerts.add(<String, dynamic>{
            'type': 'flag',
            'ingredient': flag.ingredient,
            'reason': flag.reason,
            'severity': flag.severity,
            'product': product.productName,
          });
        }
      }
    }

    for (final nutrient in result.comboAnalysis.nutrientTotals) {
      if (nutrient.status == 'warning' || nutrient.status == 'critical') {
        keyAlerts.add(<String, dynamic>{
          'type': 'nutrient',
          'nutrient': nutrient.nutrient,
          'status': nutrient.status,
        });
      }
    }

    return <String, dynamic>{
      'overall_status': result.overallStatus,
      'summary': result.overallSummary,
      'key_alerts': keyAlerts,
    };
  }

  // --------------------------------------------------------------------------
  // Network + parse with single JSON-parse retry
  // --------------------------------------------------------------------------

  Future<ClaudeReportResponse> _callWithJsonParseRetry({
    required String systemPrompt,
    required String userPrompt,
  }) async {
    try {
      final responseText = await _apiClient.postMessages(
        systemPrompt: systemPrompt,
        userPrompt: userPrompt,
      );
      return _parseResponse(responseText);
    } on FormatException {
      // STATUS_0428 §4.4: single retry to absorb non-determinism in JSON
      // structure. Subsequent failures fail-closed (rethrow).
      final responseText = await _apiClient.postMessages(
        systemPrompt: systemPrompt,
        userPrompt: userPrompt,
      );
      return _parseResponse(responseText);
    }
  }

  /// Visible-for-testing JSON parse with code-fence stripping. The
  /// response is expected to be raw JSON, but Claude occasionally wraps
  /// it in ```json fences — we strip those defensively before decoding.
  ClaudeReportResponse _parseResponse(String responseText) {
    final cleaned = _stripCodeFences(responseText);
    final dynamic decoded;
    try {
      decoded = jsonDecode(cleaned);
    } on FormatException catch (e) {
      throw FormatException(
        'Claude response: invalid JSON — ${e.message}',
      );
    }
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException(
        'Claude response: top-level is not an object',
      );
    }
    return ClaudeReportResponse.fromJson(decoded);
  }

  static String _stripCodeFences(String raw) {
    var cleaned = raw.trim();
    if (cleaned.startsWith('```')) {
      cleaned = cleaned.replaceFirst(RegExp(r'^```(?:json)?\s*'), '');
      cleaned = cleaned.replaceFirst(RegExp(r'\s*```$'), '');
    }
    return cleaned.trim();
  }
}
