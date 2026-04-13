import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_generative_ai/google_generative_ai.dart';

import '../models/pet_profile.dart';
import '../models/petcut_analysis_result.dart';
import '../prompts/gemini_prompt_pet.dart';

// PetCut Gemini 분석 서비스 (SuppleCut GeminiAnalysisService 패턴)
class GeminiAnalysisService {
  late final String _apiKey;
  final String _model = 'gemini-2.0-flash';

  GeminiAnalysisService() {
    final key = dotenv.env['GEMINI_API_KEY'] ?? dotenv.env['API_KEY'] ?? '';
    if (key.isEmpty) {
      throw Exception('API Key not found in .env (GEMINI_API_KEY or API_KEY)');
    }
    _apiKey = key;
  }

  Future<PetcutAnalysisResult> analyzeImage(
    Uint8List imageBytes, {
    required PetProfile petProfile,
  }) async {
    final model = GenerativeModel(
      model: _model,
      apiKey: _apiKey,
      systemInstruction: Content.text(GeminiPromptPet.systemPrompt),
    );

    Exception? lastError;

    for (var attempt = 0; attempt < 3; attempt++) {
      try {
        final userMessage =
            '${GeminiPromptPet.userPrompt}\n\n${petProfile.toPromptText()}';

        final response = await model.generateContent([
          Content.multi([
            DataPart('image/jpeg', imageBytes),
            TextPart(userMessage),
          ]),
        ]);

        final text = response.text ?? '';
        if (text.isEmpty) {
          throw Exception('Gemini returned empty response');
        }

        final json = _parseJson(text);
        return PetcutAnalysisResult.fromJson(json);
      } catch (e) {
        lastError = e is Exception ? e : Exception(e.toString());
        if (attempt < 2) {
          await Future.delayed(Duration(seconds: 2 * (attempt + 1)));
        }
      }
    }

    throw lastError ?? Exception('Analysis failed');
  }

  Map<String, dynamic> _parseJson(String raw) {
    var cleaned = raw.trim();
    if (cleaned.startsWith('```')) {
      cleaned = cleaned.replaceFirst(RegExp(r'^```json?\s*'), '');
      cleaned = cleaned.replaceFirst(RegExp(r'\s*```$'), '');
    }
    cleaned = cleaned.trim();
    return jsonDecode(cleaned) as Map<String, dynamic>;
  }
}
