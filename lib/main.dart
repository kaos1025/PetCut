import 'package:flutter/material.dart';

import 'core/service_locator.dart';
import 'screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // TODO: dotenv.load, Firebase.initializeApp
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
        colorSchemeSeed: const Color(0xFF4CAF50),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}
