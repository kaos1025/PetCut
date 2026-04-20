import 'package:get_it/get_it.dart';

import '../services/gemini_analysis_service.dart';
import '../services/pet_profile_service.dart';
import '../services/scan_history_service.dart';

final getIt = GetIt.instance;

Future<void> setupServiceLocator() async {
  // Hot restart 지원을 위해 기존 등록된 서비스 초기화
  await getIt.reset();

  getIt.registerLazySingleton<GeminiAnalysisService>(
    () => GeminiAnalysisService(),
  );
  getIt.registerLazySingleton<PetProfileService>(
    () => PetProfileService(),
  );
  getIt.registerLazySingleton<ScanHistoryService>(
    () => ScanHistoryService(),
  );
}
