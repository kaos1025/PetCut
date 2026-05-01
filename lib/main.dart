import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'core/route_observer.dart';
import 'core/service_locator.dart';
import 'screens/home_screen.dart';
import 'services/report_purchase_orchestrator.dart';
import 'theme/petcut_tokens.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");
  // TODO: Firebase.initializeApp
  // → Firebase 설정 파일(google-services.json) 추가 후 활성화
  await setupServiceLocator();

  // Pattern D-1 cross-session recovery (Sprint 2 Chunk 6.5). Fire-and-forget
  // by design: the user must not block on platform billing replay at boot,
  // and any failure here is silent (R1.3 — "이전 결제 이어가기" dialog is
  // v1.1 backlog). The orchestrator's recoverPendingPurchases is itself
  // idempotent against an existing entitlement token.
  unawaited(
    getIt<ReportPurchaseOrchestrator>()
        .recoverPendingPurchases()
        .catchError((Object _) {
      // Swallow — pre-UI errors must not crash the app.
    }),
  );

  runApp(const PetCutApp());
}

class PetCutApp extends StatelessWidget {
  const PetCutApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PetCut',
      debugShowCheckedModeBanner: false,
      navigatorObservers: [routeObserver],
      theme: ThemeData(
        fontFamily: 'Pretendard',
        scaffoldBackgroundColor: PcColors.surface,
        colorScheme: const ColorScheme.light(
          primary: PcColors.ink,
          secondary: PcColors.brand,
          surface: PcColors.surface,
          onSurface: PcColors.ink,
          error: PcColors.dangerAccent,
        ),
        textTheme: const TextTheme(
          displayLarge: PcText.display,
          headlineLarge: PcText.h1,
          titleMedium: PcText.h2,
          bodyLarge: PcText.body,
          bodyMedium: PcText.body,
          bodySmall: PcText.caption,
          labelSmall: PcText.label,
        ),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}
