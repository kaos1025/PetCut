# PetCut Sprint 0 — Claude Code 작업 플랜

> SuppleCut 프로덕션 심사 병렬 기간 (4/3~4/19)
> 목표: PetCut 전용 레이어 스캐폴딩 + Gemini PoC 준비

---

## Phase 1: 프로젝트 초기화 (Day 1)

### 1.1 별도 repo 생성
```bash
mkdir petcut && cd petcut
flutter create --org com.petcut --project-name petcut .
git init
```

### 1.2 SuppleCut에서 복사
```bash
# SuppleCut repo clone (참조용)
git clone https://github.com/kaos1025/yak-biseo_mvp.git supplecut_ref

# 복사 대상 (수정 없이 사용)
cp supplecut_ref/lib/theme/app_theme.dart lib/theme/
cp supplecut_ref/lib/services/iap_service.dart lib/services/
cp supplecut_ref/lib/services/pdf_report_service.dart lib/services/

# 복사 대상 (수정 필요 — 나중에 처리)
cp supplecut_ref/lib/core/service_locator.dart lib/core/
cp supplecut_ref/lib/services/gemini_analysis_service.dart lib/services/
cp supplecut_ref/lib/services/claude_report_service.dart lib/services/
```

### 1.3 pubspec.yaml 의존성 복사
SuppleCut pubspec.yaml에서 dependencies 복사 후:
- name: petcut 으로 변경
- description 변경

### 1.4 부트스트랩 파일 배치
petcut_bootstrap/ 디렉토리의 파일을 프로젝트에 복사:
- lib/models/pet_profile.dart
- lib/constants/toxicity_thresholds.dart
- lib/utils/life_stage_calculator.dart
- lib/utils/daily_intake_calculator.dart
- lib/prompts/gemini_prompt_pet.dart
- CLAUDE.md

### 1.5 flutter analyze 통과 확인
```bash
flutter pub get
flutter analyze
# 0 errors 목표 (import 경로 수정)
```

---

## Phase 2: 펫 프로필 UI (Day 1~2)

### 2.1 펫 프로필 입력 스크린
- lib/screens/pet_profile_screen.dart
- 필드: name, species (Dog/Cat 토글), breed (텍스트), weight + unit (kg/lbs), age
- LifeStage 자동 계산 표시 (수동 override 가능)
- 저장: shared_preferences (JSON)
- SuppleCut의 화면 패턴 참조 (큰 텍스트, 높은 명도 대비)

### 2.2 홈 스크린 수정
- 펫 프로필 선택 드롭다운 또는 카드
- "Add Pet" / "Edit Pet" 플로우
- 프로필 없으면 프로필 생성 먼저 유도

---

## Phase 3: Gemini 서비스 교체 (Day 2~3)

### 3.1 gemini_analysis_service.dart 수정
- _systemPrompt → GeminiPromptPet.systemPrompt 교체
- _userPrompt → GeminiPromptPet.userPrompt + pet.toPromptText() 결합
- analyzeImage() 시그니처에 PetProfile 파라미터 추가
- Content.multi에 펫 프로필 텍스트 포함

수정 포인트 (SuppleCut 원본 기준):
```dart
// Before (SuppleCut)
final response = await model.generateContent([
  Content.multi([
    DataPart('image/jpeg', imageBytes),
    TextPart(_userPrompt),
  ]),
]);

// After (PetCut)
final petContext = petProfile.toPromptText();
final response = await model.generateContent([
  Content.multi([
    DataPart('image/jpeg', imageBytes),
    TextPart('${GeminiPromptPet.userPrompt}\n\n$petContext'),
  ]),
]);
```

### 3.2 응답 모델 교체
- onestop_analysis_result.dart → petcut_analysis_result.dart
- _ulTable → ToxicityThresholds 참조로 교체
- _enforceOverallStatus → PetCut 규칙 기반으로 재작성
  - D3: chronic_toxic 기준
  - Iron: diet-based track
  - Ca: 대형견 강아지 1.2% caution

---

## Phase 4: PoC 테스트 준비 (Day 3)

### 4.1 사료 라벨 사진 5장 수집
| # | 난이도 | 예시 브랜드 | 검증 포인트 |
|---|--------|-----------|-----------|
| 1 | Easy | Purina Pro Plan | 깔끔한 GA 테이블 |
| 2 | Easy | Blue Buffalo | D3 명시 확인 |
| 3 | Medium | Orijen | 복잡한 원재료 + 보충제 혼재 |
| 4 | Hard | Stella & Chewy's | Freeze-dried, 비표준 포맷 |
| 5 | Edge | 컬러 배경 + 작은 텍스트 | OCR 한계 |

### 4.2 보충제 라벨 2장 (조합 테스트용)
- Zesty Paws Multivitamin for Dogs
- 관절 보충제 (글루코사민 + 칼슘 포함)

### 4.3 PoC 실행
Google AI Studio에서 직접 테스트:
1. 시스템 프롬프트: GeminiPromptPet.systemPrompt
2. 사용자 메시지: 라벨 사진 + petProfile.toPromptText()
3. 결과 JSON → PoC 체크리스트 대조

### 4.4 PoC 검증 체크리스트
| # | 항목 | Pass 기준 |
|---|------|----------|
| 1 | OCR 텍스트 추출 | GA 핵심 수치 누락 없음 |
| 2 | 원재료 목록 추출 | 90%+ 정확도 |
| 3 | key_nutrients JSON | D3, Fe, Ca, Zn, Cu 추출 |
| 4 | unit 인식 | per_kg vs per_serving 구분 |
| 5 | 단위 변환 | 계산 오차 ≤10% |
| 6 | 독성 플래그 | 마늘/자일리톨 정확히 flagged |
| 7 | combo 합산 | 2제품 합산 정확 |
| 8 | overall_status | 위험 조합에 warning |
| 9 | UNREADABLE 처리 | hallucination 없음 |
| 10 | 응답 시간 | <15초 |

---

## 클로드코드 세션별 작업 가이드

### Session 1: "프로젝트 초기화"
```
Flutter 프로젝트 생성하고 SuppleCut에서 기본 파일 복사해줘.
부트스트랩 파일(pet_profile, toxicity_thresholds, life_stage_calculator,
daily_intake_calculator, gemini_prompt_pet)을 배치하고
flutter analyze 통과시켜줘.
```

### Session 2: "펫 프로필 UI"
```
펫 프로필 입력 스크린 만들어줘.
SuppleCut의 screens/ 패턴 참조.
Species 토글, 체중 입력 (kg/lbs), 나이, LifeStage 자동 계산.
shared_preferences로 저장.
```

### Session 3: "Gemini 서비스 교체"
```
SuppleCut의 gemini_analysis_service.dart를 PetCut용으로 수정해줘.
프롬프트는 prompts/gemini_prompt_pet.dart의 것으로 교체.
PetProfile을 받아서 프롬프트에 주입.
응답 모델은 새로 만들어야 함 (PetCut JSON 스키마 기준).
```
