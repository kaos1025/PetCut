---
name: flutter-code-review
description: Flutter/Dart 코드 리뷰를 수행합니다. 사용자가 "코드 리뷰", "리뷰해줘", "검토해줘", "code review" 등을 요청할 때 사용합니다.
---

# Flutter 코드 리뷰 스킬 (PetCut)

## 리뷰 체크리스트

코드 리뷰 시 아래 항목을 **순서대로** 검사하라:

### 1. 🚨 Critical (반드시 확인)

- [ ] **보안**: Gemini/Claude API Key, Firebase secret, 토큰이 하드코딩되어 있지 않은가? (`.env` + `flutter_dotenv` 사용)
- [ ] **가격 하드코딩 금지**: IAP 가격이 하드코딩되어 있지 않은가? (Play Billing `formattedPrice`만 사용)
- [ ] **Null Safety**: `!` 연산자가 남발되지 않았는가? (`?? defaultValue` 또는 null 체크 선호)
- [ ] **에러 처리**: AI JSON 파싱에 try-catch + safe defaults 적용 (`(json['x'] as num?)?.toDouble() ?? 0.0`)
- [ ] **타입 안전성**: `dynamic` 타입이 사용되지 않았는가?
- [ ] **면책조항**: 분석 결과 화면에 "Not a substitute for professional veterinary advice" 표기 여부

### 2. ⚠️ Major (중요)

- [ ] **아키텍처 원칙**: "Decisions by Gemini, Display by App" 준수 — 앱에서 재판단/독자 계산 금지
- [ ] **독성 역치 상수 분리**: D3(0.01 mg/kg/day), Iron, Ca(대형견 강아지 >1.2%/>1.5%) 등 매직 넘버가 `constants/toxicity_thresholds.dart`에 있는가?
- [ ] **체중 단위**: 내부는 kg, UI는 kg/lbs 선택 가능한가?
- [ ] **위젯 분리**: 하나의 위젯이 200줄을 넘지 않는가?
- [ ] **상태 관리**: ChangeNotifier + Provider 패턴을 따르며 비즈니스 로직이 UI에서 분리되어 있는가?
- [ ] **DI**: 서비스가 `service_locator.dart`(get_it)에 등록되고 주입되는가?
- [ ] **성능**: `build()` 안에서 무거운 연산이나 네트워크 호출이 없는가?
- [ ] **리스트**: 긴 리스트에 `ListView.builder`를 사용했는가?

### 3. 📝 Minor (권장)

- [ ] **네이밍**: 파일은 `snake_case.dart`, 클래스는 `PascalCase`, 변수는 `camelCase`인가?
- [ ] **final/const**: 변하지 않는 값/위젯에 `final`/`const` 키워드를 사용했는가?
- [ ] **주석**: 불필요한 주석이나 `print()` 문이 있는가? (`debugPrint()` 또는 제거)
- [ ] **코드 중복**: SuppleCut 패턴과 중복되는 코드가 있는가?

### 4. 🎨 UI/UX (PetCut 전용)

- [ ] **언어**: UI 텍스트가 **English only**로 작성되어 있는가? (한글/기타 언어 금지)
- [ ] **통화**: 가격 표기가 **USD**인가?
- [ ] **타겟**: 미국 40~55세 반려동물 보호자에 맞는 텍스트 크기/톤인가?
- [ ] **신호등 UI**: 경고 수준(critical/caution/safe)이 색상으로 명확히 구분되는가?
- [ ] **상태 UI**: 로딩/에러/빈 상태가 처리되어 있는가?
- [ ] **펫 프로필**: 종(dog/cat), 생애주기, 체중이 분석 요청에 포함되는가?

---

## 리뷰 결과 출력 형식

리뷰 결과는 반드시 아래 형식으로 출력하라:

```markdown
## 코드 리뷰 결과

### 🚨 Critical (수정 필수)
- [파일명:라인] 이슈 설명
  ```dart
  // 문제 코드
  ```
  **수정 제안:**
  ```dart
  // 개선 코드
  ```

### ⚠️ Major (권장 수정)
- [파일명:라인] 이슈 설명

### 📝 Minor (선택 개선)
- [파일명:라인] 이슈 설명

### ✅ 잘된 점
- 칭찬할 부분

### 📊 요약
- Critical: N개
- Major: N개
- Minor: N개
- 전체 평가: [통과/조건부 통과/재검토 필요]
```

---

## 리뷰 우선순위

1. Critical 이슈가 1개라도 있으면 → **재검토 필요**
2. Major 이슈가 3개 이상이면 → **조건부 통과**
3. 그 외 → **통과**
