# PetCut — AI Pet Food + Supplement Combo Analyzer

> ⚠️ 이 파일의 모든 규칙은 절대적이다. 모든 작업에서 반드시 따른다.

## Project Overview

Flutter 앱 "PetCut" — 반려동물 사료+보충제 라벨 사진을 찍으면 AI가 성분 중복/과잉/기전 충돌을 분석하여 경고와 제외 추천을 제공하는 서비스.

SuppleCut(yak-biseo, 인체 영양제 분석 앱)의 자매 제품. 동일 아키텍처 + 동일 패턴.
SuppleCut 참조 repo: https://github.com/kaos1025/yak-biseo_mvp.git

- **타겟 사용자:** 미국 반려동물 보호자 (40~55세)
- **UI 언어:** 영어(English) only
- **통화:** USD
- **State Management:** ChangeNotifier + Provider (get_it DI)
- **AI Backend:** Gemini Flash (무료) + Claude Sonnet (유료 $1.99)

## Architecture Principle

> **"Decisions by Gemini, Display by App"**
- Gemini JSON을 신뢰하고 UI에 매핑만 함
- Claude는 유료 리포트에서 "설명"만 (재판단 금지)
- 가격 하드코딩 절대 금지 → Play Billing formattedPrice

## Tech Stack

Flutter/Dart, google_generative_ai, firebase_core/analytics,
in_app_purchase, get_it, flutter_dotenv, pdf/printing,
shared_preferences, image_picker, uuid

## Project Structure

```
lib/
├── config/           # 앱 설정
├── core/             # service_locator (get_it)
├── constants/        # ★ 독성 역치 상수
├── models/           # ★ pet_profile, petcut_analysis_result
├── prompts/          # ★ Gemini/Claude 프롬프트 문자열
├── screens/          # 스크린 위젯
├── services/         # Gemini, Claude, IAP 서비스
├── theme/            # 테마
├── utils/            # ★ life_stage, daily_intake 계산
└── widgets/          # 공용 위젯 (신호등, 카드)
```

## SuppleCut → PetCut Migration

### 그대로 복사
- theme/app_theme.dart, core/service_locator.dart (등록 대상만 교체)
- services/iap_service.dart (상품 ID만), services/pdf_report_service.dart
- widgets/ (warning_banner, savings_banner 등)
- pubspec.yaml (패키지명만 교체)

### 복사 후 수정
- services/gemini_analysis_service.dart → 프롬프트 교체 + PetProfile 주입
- services/claude_report_service.dart → 리포트 프롬프트 교체
- models/onestop_analysis_result.dart → petcut_analysis_result.dart
- screens/ → 펫 프로필 선택 UI 추가

### 신규 작성
- models/pet_profile.dart
- constants/toxicity_thresholds.dart
- utils/life_stage_calculator.dart, daily_intake_calculator.dart
- prompts/gemini_prompt_pet.dart, claude_prompt_pet.dart
- screens/pet_profile_screen.dart

---

## CRITICAL — 절대 규칙

### NEVER DO
- API keys/tokens/passwords 하드코딩 금지
- 가격 하드코딩 금지 (Play Billing formattedPrice만)
- 사용자 승인 없이 패키지 추가/구조 변경 금지
- 1 change = 1 intent (섞지 마)

### ALWAYS DO
- 변경 전 계획 먼저: summary + action items
- flutter analyze → 0 errors 확인
- AI JSON 파싱: try-catch + safe defaults (SuppleCut 패턴)
- 면책조항: "Not a substitute for professional veterinary advice"

### PetCut 전용 규칙
- 체중: 내부 kg, UI kg/lbs 선택
- D3: chronic_toxic (0.01 mg/kg/day)이 primary threshold
- Iron: 사료 기준(mg/kg food DM) + 급성 기준(mg/kg BW) 이원 트랙
- 대형견 강아지 Ca: >1.2% caution, >1.5% warning

## Code Style (SuppleCut 동일)
- snake_case.dart, PascalCase class, camelCase var
- final/const 적극, dynamic 금지, ! 남발 금지
- JSON: `(json['x'] as num?)?.toDouble() ?? 0.0` 패턴

## Git: `<type>: <subject>` (feat|fix|refactor|docs|chore, 50자)

## MVP: 펫 프로필 + 사진 스캔 + 독성 경고 + 기전 충돌 + 제외 추천 + 유료 리포트
## NOT MVP (v2): 알레르기, 약물 상호작용, FDA 리콜, 대안 추천
