import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'core/service_locator.dart';
import 'screens/home_screen.dart';
import 'theme/petcut_tokens.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");
  // TODO: Firebase.initializeApp
  // → Firebase 설정 파일(google-services.json) 추가 후 활성화
  await setupServiceLocator();
  runApp(const PetCutApp());
}

class PetCutApp extends StatelessWidget {
  const PetCutApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PetCut',
      debugShowCheckedModeBanner: false,
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
