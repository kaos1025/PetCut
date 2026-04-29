# PetCut 프로젝트 현재 상태

> 이 문서는 채팅방 간 컨텍스트 공유를 위한 living document입니다.
> 최종 업데이트: 2026-04-29 (Sprint 2 Claude API 서비스 8 commits 완료 + 통합 테스트 1회 통과 + push 완료)

---

## 1. 프로젝트 단계: Sprint 2 엔지니어링 단계 · Claude API 인프라 완성 · IAP 진입 대기

| 항목 | 상태 |
|------|------|
| 경쟁 분석 | ✅ 완료 (6개 앱 심층 분석) |
| 린캔버스 | ✅ v0.1 완료 |
| 시장 조사 | ✅ 완료 ($31.4B 글로벌, 북미 43%) |
| 핵심 가정 1 (보충제 2개+ 급여 비율) | 🟡 Reddit 카르마 빌딩 중 |
| 핵심 가정 2 (Gemini PoC) | ✅ Pass (04/14) |
| Gemini 프롬프트 | ✅ v0.4 (PoC 4차 검증 완료) |
| 데이터 모델 + 독성 로직 | ✅ v0.2 (약사 검증 완료) |
| 디자인 시스템 | ✅ v0.4 락인 (04/20, 15 컴포넌트) |
| 앱 이름/도메인 확보 | ⬜ 미시작 |
| Sprint 0 (프로젝트 초기화) | ✅ 완료 |
| Sprint 1 (E2E + UX + 저장 + 에러처리) | ✅ 공식 완료 (04/20) |
| Sprint 2 프롬프트 설계 (5 섹션) | ✅ 공식 완료 (04/21) |
| weight_display follow-up | ✅ 완료 (04/28, d7497f9) |
| Claude API 서비스 설계 결정 | ✅ 락인 (04/28, 6/6) |
| **Claude API 서비스 구현** | **✅ 완료 (04/29, 9670f18~95a2144, 7 commits)** |
| **Claude API 실기기 통합 테스트** | **✅ 통과 (04/29, 2af6dc1, 실측 baseline 확보)** |
| **8 commits push** | **✅ origin/main 도달 (04/29)** |
| IAP (Google Play Billing) | ⬜ 다음 세션 진입 |
| PDF 생성 + 공유 | ⬜ IAP 후 |
| 리포트 구매 UI / History 통합 | ⬜ PDF 후 |

---

## 2. 핵심 결정사항

### 포지셔닝 (변경 없음)
- **"사료 + 보충제 조합 분석"** = 블루오션 (경쟁자 0개)
- SuppleCut 파이프라인 70~80% 재활용

### 기술 아키텍처 (Claude API 구현 시점 갱신)
- **별도 repo 전략** — SuppleCut fork 아닌 클린 스타트
- SuppleCut은 참조용만 (https://github.com/kaos1025/yak-biseo_mvp.git)
- Gemini Flash (무료 분석) + Claude Sonnet (유료 리포트 $1.99)
- **Claude Sonnet 모델: `claude-sonnet-4-6` alias** (Sonnet 4.5는 legacy로 분류, 가격 동일)
- **5-섹션 유료 리포트 구조 확정**: §1 Pet Risk Profile / §2 Combo Load Report / §3 Mechanism Alerts / §4 Observable Warning Signs / §5 Action Plan & Vet Escalation
- **"Decisions by engine, explanations by AI"** 원칙: InputBuilder(Dart)가 기계적 판단, Claude Sonnet은 렌더만 — **실 호출에서 검증됨 (§4 참조)**
- 단일 통합 호출 + sections 배열 envelope + typed response model
- HTTP 레이어: 기존 `http: ^1.6.0` (신규 패키지 추가 0)
- 모킹: `mocktail: ^1.0.4` (dev_dependency 1건만 추가)
- Pretendard 폰트 + DS v0.4 토큰 시스템
- RouteObserver + RouteAware 패턴
- connectivity_plus + DNS probe 2단계 네트워크 체크
- get_it DI + lazySingleton 패턴

### 수익모델 (실측 비용 반영)
| 티어 | 내용 | 가격 | 실 비용 | Gross 마진 |
|------|------|------|--------|----------|
| Free | 사료/보충제 조합 스캔 + 중복/과잉 경고 (Gemini) | $0 | ~$0.001 | - |
| Standard | 5섹션 상세 리포트 + 체중별 독성 계산 (Claude) | $1.99 | $0.073 | ~81% (Play 15% 수수료 차감 후) |
| Premium (v2) | 풀 리포트 + 대안 추천 + 급여 스케줄 | $4.99 | TBD | TBD |

---

## 3. Claude API 서비스 구현 결과 (2026-04-29)

### 3.1 8 commits 요약

| # | hash | 커밋 | 변경 |
|---|------|------|------|
| 1 | 9670f18 | feat(sprint2): add Claude report typed models | 4 files, +1337 |
| 2 | 4d2ede4 | feat(sprint2): add Claude Sonnet system prompts | 1 file, +708 |
| 3 | bfeb14a | feat(sprint2): add Claude API client | 2 files, +788 |
| 4 | 037627e | feat(sprint2): add Claude report orchestration | 1 file, +216 |
| 5 | a86d518 | chore(sprint2): add mocktail + service test suite | 6 files, +747 |
| 6 | 82e01ed | chore(sprint2): register Claude services in DI | 1 file, +12 |
| 7 | 95a2144 | chore(sprint2): add .env.example template | 2 files, +13 |
| 8 | 2af6dc1 | test(sprint2): add Claude API live integration test | 1 file (untracked → committed) |

### 3.2 품질 지표

- 총 테스트: **207 passed** (141 → +66 신규)
  - model 25 + client 25 + service 16
- `flutter analyze`: **0 issues**
- 보안 (price/key/print/.env body): **0 violations**
- `claude_report_service.dart` LOC: **216줄** (목표 ≤250)
- 1 commit = 1 intent: **7개 분리, 무관 변경 0**
- 신규 패키지: **mocktail ^1.0.4 only**

### 3.3 결정 그리드 (Phase 1 → Plan-first → Phase 2)

| # | 결정 포인트 | 채택안 |
|---|---|---|
| 1 | Sonnet 모델 ID | `claude-sonnet-4-6` alias (V6 Anthropic docs 검증) |
| 2 | HTTP 클라이언트 | 기존 `http: ^1.6.0` (별도 추가 0) |
| 3 | 모킹 라이브러리 | `mocktail: ^1.0.4` (null safety + codegen 불필요) |
| 4 | System prompt 파일 구조 | 단일 `lib/prompts/claude_prompt_pet.dart` (preamble + 5 section system) |
| 5 | Claude 출력 모델 | typed `ClaudeReportResponse` + 5 `SectionOutput` (fail-closed 첫 방어선) |
| 6 | Message 분배 (D1) | system = preamble + Critical Rules / user = Output Schema + envelope JSON |
| 7 | Retry/Timeout | 90s timeout, 5xx/timeout 1회 retry, 429 backoff 1s→2s→4s 최대 3회, parse fail 1회 retry, 4xx 즉시 실패 |
| 8 | Fixtures | 5종 `test/fixtures/claude_responses/` (success / partial / malformed / schema_violation / timeout) |
| 9 | Prompt caching v1.1 백로그 | Sonnet 4.6 cache hits $0.30/MTok (1/10 비용) — 출시 후 N건 측정 후 ROI 산정 |

---

## 4. Claude API 통합 테스트 결과 (2026-04-29, commit 2af6dc1)

### 4.1 1회 실 호출 실측치

| 항목 | 값 |
|---|---|
| HTTP status | 200 |
| Request ID | req_011CaY7uNU7eVNup7FzP9oyS |
| Latency | 57,835 ms (~58초, 90s timeout 안전 margin 32s) |
| Request body size | 32,945 bytes |
| Input tokens | 8,974 |
| Output tokens | 3,082 (16K max 중 19% 사용) |
| 실 비용 | **$0.0732** ($3/MTok input + $15/MTok output) |
| 5 섹션 fromJson | **전부 ✓** |
| fail-closed flow 발동 | No |

### 4.2 추정 vs 실측 비교 (STATUS_0428 §4.6 갱신)

| 항목 | 추정 | 실측 | Δ | 평가 |
|---|---|---|---|---|
| Input tokens | ~8K | 8,974 | +12% | ✅ 거의 정확 |
| Output tokens | ~2,500 | 3,082 | +23% | ⚠️ 약간 초과 |
| **리포트당 비용** | **$0.062** | **$0.0732** | **+18%** | ✅ 마진 안전 |
| Latency | 60s 가정 | 57.8s | -4% | ✅ 4050 가설과 정확히 일치 |

### 4.3 시그널 일관성 (envelope → response, "Decisions by engine, explanations by AI" 원칙 검증)

| envelope 입력 | response 출력 | 일치 |
|---|---|---|
| overall_status: caution + tier-3 exclusion + caution mechanism | §5 triage "Mention at Next Vet Visit" | ✓ |
| 1 mechanism (anticoagulant_stacking, caution) | §3 alert_cards = 1, severity caution | ✓ |
| 1 nutrient (vitamin_d3, caution, 16.7%) | §2 nutrient_cards = 1, status caution | ✓ |
| weight_display "30 kg (66 lbs)" | §1 pet_summary_line 정확 echo | ✓ |
| Golden Retriever (non-copper-sensitive) | §1 sensitivity_notes 빈 / 짧은 처리 | ✓ |

100% 일치 — Claude가 재분류/재평가하지 않고 envelope 결정 verbatim echo. 5섹션 프롬프트 RULE 1/3 동작 확인.

### 4.4 비용/마진 분석 (실측 기반)

- 매출 $1.99 → Google Play 수수료 15% = **$1.69**
- Claude API 비용 = **$0.073**
- **건당 gross margin $1.62 (~81%)**
- fail-closed 발동 시 (자동 refund + 1회 무료 재시도): **건당 최악 손실 $0.146** ($0.073 × 2)
- 4 in 100건 실패 시 EBITDA 영향 < 1%

### 4.5 학습 사항

- **"Decisions by engine, explanations by AI" 원칙이 실 호출에서 검증됨** — 5섹션 프롬프트의 RULE 1/3가 의도대로 동작, Claude는 input verbatim echo만 수행
- **4050 60초 대기 수용 가설**의 첫 데이터 포인트 1건 확보 (출시 후 N건 측정으로 정식 검증 필요, STATUS_0428 §4.5 streaming v1.1 진입 조건 입력값)
- **비용 +18% 초과의 원인은 output token +23%** — 5섹션 통합 호출 시 Claude의 자연스러운 elaboration. system prompt에 "최대 N words per section" 제약 추가 시 v1.1에서 절감 가능
- **Phase 1 검증 → 결정 그리드 → Plan-first → Phase 2 7 commits → 통합 테스트** 절차의 효율성 — 디버그 라운드 거의 없음, 각 chunk가 독립적으로 testable

---

## 5. Sprint 2 잔여 작업 우선순위

| # | 작업 | 상태 | 비고 |
|---|------|------|------|
| 1 | IAP (Google Play Billing) | ⬜ 다음 세션 | Phase 1 검증 6개 항목 → plan-first → 구현. ★ 핵심: server-less 환경 자동 refund 가능 여부 |
| 2 | PDF 생성 + 공유 | ⬜ | IAP 후. 정형 JSON → PDF 매핑 |
| 3 | 리포트 구매 UI | ⬜ | PDF 후 |
| 4 | 전체 History 스크린 ("See all" 활성화) | ⬜ | UI 통합 |
| 5 | Recent 카드 탭 → Result 재진입 | ⬜ | UI 통합 |

### 권장 진행 순서 (변경 없음)

IAP → PDF → UI 통합

**이유:**
- IAP는 가장 시간을 잡아먹을 작업 + Play Console 테스트 환경 셋업 필수
- fail-closed UX의 환불/entitlement-grant 로직이 IAP에 강결합
- PDF는 Claude 응답 typed schema가 락인된 상태에서 매핑
- UI는 마지막 통합

---

## 6. IAP 진입 — Phase 1 검증 항목 (다음 세션)

| # | 확인 사항 | 영향 |
|---|---|---|
| V1 | `in_app_purchase` (Flutter 공식) vs `flutter_inapp_purchase` 점유율 + 권장 패키지 | 패키지 선택 |
| V2 | Consumable 상품 라이프사이클 (구매 → 검증 → consume) | $1.99/건 매번 결제 모델 적합성 |
| V3 | Server 없이 entitlement 검증 가능성 + 위변조 리스크 | 아키텍처 결정 |
| V4 | **Refund 자동화 — Google Play Developer API server-less 가능 여부 (★)** | STATUS §4.7 "automatically refunded" 문구 실현 가능성 |
| V5 | fail-closed UX 대안 매트릭스 (패턴 A/B/C/D) | V4 결과에 따라 분기 |
| V6 | SuppleCut IAP 패턴 재활용 가능성 | 코드 재사용 |

### V5 패턴 옵션 (V4 결과 대기 중)

- 패턴 A: 자동 refund + 1회 무료 재시도 (server 필요 시 PetCut 불가)
- 패턴 B: 수동 refund 안내 + 1회 무료 재시도 (server 불필요)
- 패턴 C: refund 없이 무료 재시도만 (가장 단순)
- **패턴 D: Acknowledge 전에 retry** — Claude API 실패 시 acknowledgePurchase 미호출 → Google Play 3일 후 자동 refund + 사용자에게 즉시 무료 재시도 (server-less에서 가장 우아한 해결, V4 검증 후 채택 여부 결정)

---

## 7. 코드베이스 구조 (Sprint 2 Claude API 완성 시점)

```
petcut/
├── CLAUDE.md
├── .env                          # GEMINI_API_KEY (회전 후 신규) + ANTHROPIC_API_KEY 추가됨
├── .env.example                  # 신규 (95a2144) — 두 키 자리만 노출, 값 없음
├── pubspec.yaml                  # mocktail: ^1.0.4 dev_dep 추가됨
├── assets/fonts/
│   ├── Pretendard-Regular.otf
│   └── Pretendard-Medium.otf
├── lib/
│   ├── main.dart
│   ├── core/
│   │   ├── service_locator.dart  # 82e01ed: ClaudeApiClient + ClaudeReportService 등록
│   │   └── route_observer.dart
│   ├── theme/
│   │   └── petcut_tokens.dart
│   ├── models/
│   │   ├── pet_enums.dart
│   │   ├── pet_profile.dart
│   │   ├── petcut_analysis_result.dart
│   │   ├── scan_history_entry.dart
│   │   ├── claude_report_request.dart      # 신규 (9670f18) — typed envelope
│   │   └── claude_report_response.dart     # 신규 (9670f18) — typed response + 5 SectionOutput
│   ├── constants/
│   │   ├── toxicity_thresholds.dart
│   │   └── observable_warning_signs.dart
│   ├── utils/
│   │   ├── life_stage_calculator.dart
│   │   ├── daily_intake_calculator.dart
│   │   └── observation_expression.dart
│   ├── prompts/
│   │   ├── gemini_prompt_pet.dart
│   │   └── claude_prompt_pet.dart          # 신규 (4d2ede4) — preamble + 5 section system
│   ├── screens/
│   │   ├── home_screen.dart
│   │   ├── pet_profile_screen.dart
│   │   ├── scan_screen.dart
│   │   ├── analysis_loading_screen.dart
│   │   └── analysis_result_screen.dart
│   └── services/
│       ├── gemini_analysis_service.dart
│       ├── pet_profile_service.dart
│       ├── scan_history_service.dart
│       ├── risk_detector.dart
│       ├── section1_input_builder.dart
│       ├── section2_input_builder.dart
│       ├── section3_input_builder.dart
│       ├── section4_input_builder.dart
│       ├── section5_input_builder.dart
│       ├── claude_api_client.dart           # 신규 (bfeb14a) — abstract + Http impl + retry
│       └── claude_report_service.dart       # 신규 (037627e) — envelope assembler + orchestration, 216 LOC
├── test/
│   ├── services/
│   │   ├── risk_detector_test.dart
│   │   ├── section1_input_builder_test.dart   # 21
│   │   ├── section2_input_builder_test.dart   # 13
│   │   ├── section3_input_builder_test.dart   # 17
│   │   ├── section4_input_builder_test.dart   # 22
│   │   ├── section5_input_builder_test.dart   # 22
│   │   ├── claude_report_models_test.dart     # 신규 (a86d518) — 25
│   │   ├── claude_api_client_test.dart        # 신규 (a86d518) — 25
│   │   └── claude_report_service_test.dart    # 신규 (a86d518) — 16
│   ├── fixtures/claude_responses/             # 신규 (a86d518)
│   │   ├── success_full.json
│   │   ├── partial_section3_missing.json
│   │   ├── malformed_json.json
│   │   ├── invalid_schema.json
│   │   └── timeout_simulation.json
│   └── integration/
│       └── claude_report_service_live_test.dart  # 신규 (2af6dc1) — @Tags(['live'])
└── docs/
    ├── SPRINT_0_PLAN.md
    ├── design_system_v0.md
    ├── PETCUT_STATUS_0420.md
    ├── PETCUT_STATUS_0421.md
    ├── PETCUT_STATUS_0428.md
    ├── PETCUT_STATUS_0429.md              # 본 문서
    └── prompts/
        ├── section_1_pet_risk_profile.md
        ├── section_2_combo_load_report.md
        ├── section_3_mechanism_interaction_alerts.md
        ├── section_4_observable_warning_signs.md
        └── section_5_action_plan_vet_escalation.md
```

---

## 8. 품질 지표 (현 시점)

- 총 테스트: **207 passed** (141 → +66)
- `flutter analyze`: **0 issues**
- 보안 / 가격 하드코딩 / print() / .env body 노출: **모두 clean**
- 8 commits push 완료 (origin/main 도달)
- Working tree: `.claude/settings.local.json` 무관 변경 1건 잔여 (사용자 판단)
- 클린 베이스라인 유지

---

## 9. 자매 프로젝트 참조

| 프로젝트 | 상태 | 관계 |
|---------|------|------|
| SuppleCut | 🟢 클로즈드 베타 진행 중 | 아키텍처 레퍼런스 (참조만, fork 아님) |
| **PetCut** | ⚙️ **Sprint 2 Claude API 인프라 완성 · IAP 진입 대기** | 본 프로젝트 |
| Trouble Detective | 💡 아이디어 | 후순위 |

---

## 10. 확인 필요 가정 (Pre-MVP)

| 가정 | 검증 방법 | 상태 | 결과 |
|------|---------|------|------|
| 반려동물 주인이 보충제 2개+ 급여 | Reddit 설문 | 🟡 카르마 빌딩 중 | — |
| Gemini가 사료+보충제 조합 분석 가능 | PoC + 실기기 | ✅ Pass | v0.4, 실기기 E2E + 6 Case 통과 |
| **Claude Sonnet이 5섹션 정형 JSON 안정적 생성** | **통합 테스트 1회** | **✅ Pass** | **fromJson 5/5, 시그널 일관성 100%** |
| **리포트당 비용 STATUS 추정 범위 내** | **실 호출 측정** | **✅ Pass (+18%)** | **$0.073 vs 추정 $0.062, 마진 안전** |
| "조합 분석" 지불의향(WTP) | 커뮤니티 반응 | ⬜ | IAP + UI 출시 후 |
| 동물 독성 역치 데이터 접근 가능 | Merck/ASPCA/NRC | ✅ | v0.2 정리 완료 |
| 4050 사용자 60초 대기 수용 가능성 | 출시 후 이탈률 측정 | 🟡 데이터 포인트 1건 | streaming v1.1 결정 입력 |

---

## 11. 다음 액션 (우선순위 순)

| # | 항목 | 담당 | 시기 |
|---|------|------|------|
| 1 | IAP Phase 1 검증 (V1~V6 read-only) | @Tech | **다음 세션 첫 작업** |
| 2 | Phase 1 결과 기반 plan-first 작성 → 승인 | @Tech | Phase 1 직후 |
| 3 | IAP 구현 (env_setup → consumable 상품 → fail-closed UX → entitlement) | @Tech | plan 승인 후 |
| 4 | PDF 생성 + 공유 기능 | @Tech | IAP 후 |
| 5 | 리포트 구매 UI + 전체 History 스크린 | @Tech + @UX | PDF 후 |
| 6 | (선택) `.claude/settings.local.json` `.gitignore` 추가 | @Tech | 짬 날 때 |
| 7 | Reddit 가정 1 검증 (카르마 200+ 도달 시) | @SNS | 대기 |
| 8 | 앱 이름/도메인/소셜 핸들 확보 | @CMO | Sprint 2 중 |
| 9 | 예비창업패키지 확장성 슬라이드 (SuppleCut + PetCut 2제품) | @BM | 5월 |

---

## 12. 결정 로그 (Decision Log)

### 2026-04-29
- ✅ Sonnet 모델 ID: **`claude-sonnet-4-6` alias** 채택 (4-5 legacy, 가격 동일)
- ✅ HTTP 클라이언트: **기존 `http: ^1.6.0`** 사용 (신규 패키지 추가 0)
- ✅ 모킹 라이브러리: **`mocktail: ^1.0.4`** dev_dep 1건만 추가
- ✅ System prompt 구조: **단일 `lib/prompts/claude_prompt_pet.dart`** (preamble + 5 section system)
- ✅ Claude 출력 모델: **typed `ClaudeReportResponse` + 5 `SectionOutput`** (fail-closed 첫 방어선)
- ✅ Message 분배: **D1 (rules → system, schema + envelope JSON → user)**
- ✅ Retry/Timeout 정책: **90s timeout + 사유별 분기 retry** (5xx/timeout/429/parse_fail)
- ✅ Fixtures + mocktail 모킹 패턴 (5종 fixture)
- ✅ Prompt caching **v1.1 백로그** (출시 후 N건 측정 → cache hits $0.30/MTok = 1/10 비용 ROI 산정)
- ✅ Phase 2 7 sequential commits + 통합 테스트 1 commit = **8 commits push 완료**
- ✅ 통합 테스트 1회 실측 baseline 확보 ($0.073/리포트, 58s, 207 tests pass)
- ✅ 보안 사고 처리: GEMINI_API_KEY 회전 완료

### 2026-04-28
- ✅ weight_display follow-up 완료 — origin 단위 직접 분기 (옵션 B)
- ✅ Claude API 호출 구조: **단일 통합 호출** 채택
- ✅ Input envelope: **sections 배열 + 공통 envelope** 채택
- ✅ Response schema: **sections 배열 mirror + 정형 JSON** 채택
- ✅ 에러 처리: **timeout 90s + retry 정책 + non-streaming v1**
- ✅ 부분 실패: **Fail-closed + 자동 retry 1회 + 환불 + 무료 재시도**
- ✅ 모킹: **mocktail + test/fixtures/claude_responses/**
- ✅ Streaming **v1 미채택**, v1.1 진입 조건 명시

### 2026-04-21
- ✅ Sprint 2 프롬프트 설계 5/5 완결 (138 tests)
- ✅ "Decisions by engine, explanations by AI" 원칙 5섹션 일관 적용

### 2026-04-20
- ✅ DS v0.4 락인 (15 컴포넌트)
- ✅ Sprint 1 공식 완료 (E2E + UX + 저장 + 에러처리)

---

## Changelog

- **2026-04-29** — 본 문서 작성. Sprint 2 Claude API 서비스 7 commits + 통합 테스트 1 commit (총 8 commits) push 완료. 실측 비용 baseline $0.073/리포트 확보 (추정 $0.062 대비 +18%, 마진 81% 안전). "Decisions by engine, explanations by AI" 원칙 실 호출에서 시그널 일관성 100% 검증. 다음 작업: IAP Phase 1 검증 (★ 핵심: server-less 환경 자동 refund 가능 여부).
- **2026-04-28** — STATUS_0428 (weight_display follow-up + Claude API 설계 결정)
- **2026-04-21** — STATUS_0421 (Sprint 2 프롬프트 완결)
- **2026-04-20** — STATUS_0420 (Sprint 1 완결)
