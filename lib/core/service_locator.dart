import 'package:get_it/get_it.dart';

import '../services/claude_api_client.dart';
import '../services/claude_report_service.dart';
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

  // Claude paid-report pipeline. Both registrations are lazy:
  // ANTHROPIC_API_KEY validation happens on first resolution, mirroring
  // the GeminiAnalysisService pattern.
  getIt.registerLazySingleton<ClaudeApiClient>(
    () => HttpClaudeApiClient(),
  );
  getIt.registerLazySingleton<ClaudeReportService>(
    () => ClaudeReportService(apiClient: getIt<ClaudeApiClient>()),
  );
}
