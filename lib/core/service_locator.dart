import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/gemini_analysis_service.dart';
import '../services/pet_profile_service.dart';

final getIt = GetIt.instance;

Future<void> setupServiceLocator() async {
  final prefs = await SharedPreferences.getInstance();

  getIt.registerSingleton<PetProfileService>(PetProfileService(prefs));
  getIt.registerSingleton<GeminiAnalysisService>(GeminiAnalysisService());
}
