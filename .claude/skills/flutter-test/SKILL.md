---
name: flutter-test
description: Flutter 테스트를 작성하거나 실행합니다. 사용자가 "테스트 작성", "테스트 실행", "유닛 테스트", "위젯 테스트", "test" 등을 요청할 때 사용합니다.
---

# Flutter 테스트 스킬

## 테스트 실행 명령어

### 전체 테스트
```bash
flutter test
```

### 특정 파일 테스트
```bash
flutter test test/특정_파일_test.dart
```

### 커버리지 포함
```bash
flutter test --coverage
```

---

## 테스트 작성 가이드

### 1. 파일 위치 및 네이밍

```
lib/services/gemini_analysis_service.dart
→ test/services/gemini_analysis_service_test.dart
```

- 파일명: `원본파일명_test.dart`
- 폴더 구조: `lib/` 구조를 `test/`에서 미러링

### 2. 테스트 구조 (AAA 패턴)

```dart
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('클래스명 또는 기능명', () {
    // 공통 setup
    late SomeClass sut; // System Under Test
    
    setUp(() {
      sut = SomeClass();
    });

    test('무엇을 하면 어떤 결과가 나온다', () {
      // Arrange (준비)
      final input = 'test';
      
      // Act (실행)
      final result = sut.doSomething(input);
      
      // Assert (검증)
      expect(result, equals('expected'));
    });
  });
}
```

### 3. 테스트 네이밍 규칙

```dart
// ✅ Good - 행동과 결과를 명확히
test('PetProfile이 null이면 분석 요청은 ArgumentError를 던진다', () {});
test('유효한 Gemini 응답이면 PetcutAnalysisResult로 파싱된다', () {});
test('D3가 0.01 mg/kg/day 초과이면 chronic_toxic 경고를 반환한다', () {});

// ❌ Bad - 모호한 이름
test('test1', () {});
test('analysis test', () {});
```

---

## 테스트 유형별 가이드

### Unit Test (비즈니스 로직)

```dart
// Service, Repository, Calculator 등
group('DailyIntakeCalculator', () {
  test('체중 10kg, 성견일 때 D3 권장량을 반환한다', () {
    // Arrange
    final calc = DailyIntakeCalculator();
    final profile = PetProfile(species: Species.dog, weightKg: 10, lifeStage: LifeStage.adult);

    // Act
    final result = calc.recommendedD3(profile);

    // Assert
    expect(result, greaterThan(0));
  });
});
```

### Widget Test (UI)

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Scan 버튼 탭하면 카메라 화면으로 이동한다', (tester) async {
    // Arrange
    await tester.pumpWidget(
      const MaterialApp(home: HomeScreen()),
    );

    // Act
    await tester.tap(find.text('Scan Label'));
    await tester.pump(); // 애니메이션 한 프레임
    // await tester.pumpAndSettle(); // 모든 애니메이션 완료까지

    // Assert
    expect(find.text('Analyzing...'), findsOneWidget);
  });
}
```

---

## Mock/Fake 가이드

### Fake 우선 (권장)

```dart
// ✅ Fake - 단순하고 명확
class FakeGeminiAnalysisService implements GeminiAnalysisService {
  PetcutAnalysisResult? _stubbedResult;

  void stubResult(PetcutAnalysisResult result) => _stubbedResult = result;

  @override
  Future<PetcutAnalysisResult> analyze({
    required PetProfile profile,
    required List<String> imagePaths,
  }) async {
    if (_stubbedResult == null) throw StateError('No stubbed result');
    return _stubbedResult!;
  }
}
```

### Mock (복잡한 경우만)

```dart
// mockito 사용 시
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';

@GenerateMocks([GeminiAnalysisService])
void main() {
  late MockGeminiAnalysisService mockService;

  setUp(() {
    mockService = MockGeminiAnalysisService();
  });

  test('네트워크 예외 발생 시 AnalysisFailure 반환', () {
    when(mockService.analyze(profile: anyNamed('profile'), imagePaths: anyNamed('imagePaths')))
        .thenThrow(Exception('Network error'));
    // ...
  });
}
```

---

## 테스트 작성 시 주의사항

### DO ✅
- 하나의 테스트는 하나의 동작만 검증
- 실패 시 원인이 명확하도록 assertion 작성
- 에러 케이스도 반드시 테스트
- `Future.delayed` 있으면 `tester.pump(Duration)` 사용

### DON'T ❌
- 여러 동작을 하나의 테스트에 넣지 마라
- 실제 API 호출하지 마라 (Fake/Mock 사용)
- 테스트 간 상태 공유하지 마라
- `sleep()` 사용하지 마라 (`pump` 사용)

---

## 테스트 결과 출력 형식

테스트 작성 후 아래 형식으로 보고하라:

```markdown
## 테스트 작성 완료

### 작성된 테스트 파일
- `test/services/gemini_analysis_service_test.dart`

### 테스트 케이스 (N개)
1. ✅ 유효한 PetProfile + 이미지면 PetcutAnalysisResult를 반환한다
2. ✅ D3가 chronic_toxic 역치 초과이면 critical 경고를 반환한다
3. ✅ 네트워크 에러 시 AnalysisFailure를 던진다

### 실행 명령어
```bash
flutter test test/services/gemini_analysis_service_test.dart
```

### 커버리지 확인
```bash
flutter test --coverage && genhtml coverage/lcov.info -o coverage/html
```
```
