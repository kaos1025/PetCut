# PetCut 프로젝트 현재 상태

> Sprint 2 — IAP 인프라 완성 (백엔드 + UI + integration)
>
> 작성: 2026-04-30
> 직전 snapshot: `PETCUT_STATUS_0429.md` (Claude API 인프라 완성 + IAP 진입 대기)
> 본 문서는 신규 snapshot. STATUS_0429는 보존.

---

## 1. 프로젝트 단계: Sprint 2 엔지니어링 단계 · IAP 인프라 완성 · 라이브 통합 테스트 대기

| 단계 | 상태 |
|------|------|
| Sprint 0 — 자매 프로젝트(SuppleCut) 패턴 추출 | ✅ |
| Sprint 1 — 프로젝트 부트스트랩 · 펫 프로필 · 토큰 디자인 | ✅ |
| Sprint 2 — 프롬프트 + 환경 + 분석 흐름 + Claude API + **IAP 인프라** | ✅ (라이브 통합 테스트 ⬜) |
| Sprint 3 — Reddit/오가닉 가설 검증 + 베타 모집 | ⬜ |
| Sprint 4 — 베타 운영 + Play Console alpha → production | ⬜ |

**Sprint 2 잔여**: 라이브 IAP 통합 테스트 (Play Console alpha track + license tester + 실 기기 1회 결제) — 별도 세션 분리.

---

## 2. 핵심 결정사항

### 포지셔닝 (변경 없음)

- 미국 반려동물 보호자 40-55세 타겟
- "Decisions by engine, explanations by AI" 원칙
- 사료+보충제 라벨 사진 → Gemini 무료 분석 → Claude 유료 상세 리포트

### 기술 아키텍처 (IAP 인프라 갱신)

| 영역 | 현 시점 |
|------|---------|
| Flutter SDK 제약 | Dart `>=3.4.1 <4.0.0` (Phase 1 P1.1 검증) |
| State 관리 | ChangeNotifier + Provider, get_it DI |
| AI 백엔드 | Gemini Flash (무료) + Claude Sonnet 4.5 (유료) |
| **IAP** | `in_app_purchase: ^3.2.3` (Pattern D 지연 consume) |
| **보안 영속** | `flutter_secure_storage: ^9.2.2` (host-OS keystore) |
| **결제 상태머신** | 5-state PurchaseState + sealed ReportPurchaseResult |
| **크로스 세션 복구** | `recoverPendingPurchases` 앱 시작 시 fire-and-forget |
| 코드 레이어 | 4 신규 service · 4 신규 model · 6 신규 screen · 1 신규 widget |

### 수익모델 (변경 없음)

STATUS_0429 §4.6 실측치 그대로:
- 비용 $0.073/리포트 (실측, Sonnet 4.5)
- 가격 $1.99 (Play Billing formattedPrice — 하드코딩 금지)
- 마진 ~81%
- BEP ~7건/달

---

## 3. Sprint 2 IAP 인프라 완성 결과 (2026-04-30)

### 3.1 11 commits 요약

| # | Commit | 내용 |
|---|--------|------|
| 1 | `5732e60` | flutter_secure_storage + BILLING permission |
| 2 | `1650227` | scan_history_entry.isPaidReport (4-spot patch + 8 tests) |
| 3 | `ce52863` | PurchaseState + ReportPurchaseResult sealed (13 tests) |
| 4 | `371c5e6` | IapBillingService + product IDs + 4 fixtures (17 tests) |
| 5 | `65ede42` | IapEntitlementService + EntitlementToken (15 tests) |
| 6 | `741899f` | ReportPurchaseOrchestrator + Pattern D state machine (11 tests + Chunk 2b 부채 fix) |
| 7 | `2a7b356` | service_locator DI wiring + markAsPaid tests (5 tests) |
| 8 | `fa1fd06` | recoverPendingPurchases (Plan §10 Risk 1) (8 tests) |
| 9 | `c686f7d` | IAP UI 진입부 — Purchase + Failure + Disclaimer (5 tests) |
| 10 | `2a8ed38` | Generating + PaidReport 화면 + flow wiring (6 tests) |
| 11 | `fd5c913` | AnalysisResultScreen CTA wiring (entry point) (5 tests) |

### 3.2 누적 변경

| 항목 | 수치 |
|------|------|
| Commits | 11 |
| 테스트 | **207 → 300** (+93) |
| 신규 lib 파일 | 14 (4 services + 6 screens + 4 models + 1 widget + 1 constants — `iap_product_ids.dart` 포함) |
| 수정 lib 파일 | 4 (`service_locator.dart`, `main.dart`, `scan_history_service.dart`, `scan_history_entry.dart`, `analysis_result_screen.dart`) |
| 신규 fixtures | 4 IAP JSON (`test/fixtures/iap/`) |
| 신규 test helper | 2 (`load_claude_fixture.dart`, `orchestrator_test_doubles.dart`) |

### 3.3 사용자 흐름 9-step end-to-end

1. 사용자가 사료/보충제 라벨 스캔 → AnalysisResult 화면 도착
2. (선택) Save scan → ScanHistoryEntry 영속
3. **CTA "Get Detailed Report" 탭** → idempotent `_saveScan` + push to PurchaseScreen
4. PurchaseScreen → 가격 표시 (또는 Free Retry CTA) + D8 disclaimer
5. CTA 탭 → pushReplacement to GeneratingScreen
6. Orchestrator 실행:
   - 결제 성공 + Claude 성공 → `consume()` + `markAsPaid` + push to PaidReportScreen
   - 결제 성공 + Claude 실패 → `grantFreeRetry` (consume 안 함, Google 자동 환불) + push to FailureScreen
   - 결제 취소 → silent pop
   - 결제/Claude 에러 → 인라인 에러 + Close 버튼
7. PaidReportScreen → 5섹션 카드로 Claude 결과 렌더 + footer disclaimer
8. FailureScreen → D6 환불 안내 + "Retry Now (Free)" Suggestion blue 버튼
9. 앱 재시작 시 → `recoverPendingPurchases`가 미consume purchase 자동 복구 → `grantFreeRetry` → 다음 진입 시 Free Retry 경로

### 3.4 Pattern D consume 게이트 다층 검증

| 레이어 | 검증 위치 | 단언 |
|--------|----------|------|
| **모델** | `report_purchase_result_test.dart` | sealed class exhaustive switch — 새 분기 누락 시 컴파일 에러 |
| **서비스 (billing)** | `iap_billing_service_test.dart` | `buyConsumable(autoConsume: false)` + `verifyNever(completePurchase)` for purchased/restored stream events |
| **서비스 (orchestrator)** | `report_purchase_orchestrator_test.dart` | 모든 비-Success 분기 `verifyNever(billing.consume)` |
| **서비스 (recovery)** | `report_purchase_orchestrator_test.dart` | recovery 경로 `verifyNever(billing.consume)` regardless of branch |
| **UI (purchase entry)** | `report_purchase_screen_test.dart` | CTA 탭 → pushReplacement (orchestrator 호출 verify) |
| **UI (failure handling)** | `report_failure_screen_test.dart` | D6 verbatim 카피 노출 |
| **UI (disclaimer)** | `refund_policy_disclaimer_test.dart` | D8 verbatim static const |
| **Integration (CTA wiring)** | `analysis_result_screen_test.dart` | idempotent `_saveScan` + scanId 전달 |

---

## 4. 코드베이스 구조 (Sprint 2 IAP 완성 시점)

```
lib/
├── constants/
│   └── iap_product_ids.dart                  ★ NEW
├── core/
│   └── service_locator.dart                  ⚙ MODIFIED (+4 registrations)
├── main.dart                                 ⚙ MODIFIED (+recoverPendingPurchases unawaited)
├── models/
│   ├── entitlement_token.dart                ★ NEW
│   ├── iap_purchase_state.dart               ★ NEW
│   ├── report_purchase_result.dart           ★ NEW (sealed hierarchy)
│   └── scan_history_entry.dart               ⚙ MODIFIED (+isPaidReport)
├── screens/
│   ├── analysis_result_screen.dart           ⚙ MODIFIED (+CTA section)
│   ├── paid_report_screen.dart               ★ NEW
│   ├── report_failure_screen.dart            ★ NEW
│   ├── report_generating_screen.dart         ★ NEW
│   └── report_purchase_screen.dart           ★ NEW
├── services/
│   ├── iap_billing_service.dart              ★ NEW (Pattern D 지연 consume)
│   ├── iap_entitlement_service.dart          ★ NEW (single-key + delete-on-consume)
│   ├── report_purchase_orchestrator.dart     ★ NEW (state machine)
│   └── scan_history_service.dart             ⚙ MODIFIED (+markAsPaid)
└── widgets/
    └── refund_policy_disclaimer.dart         ★ NEW (D8 single source)

test/
├── fixtures/
│   ├── claude_responses/                     (기존, Chunk 5에서 재사용)
│   └── iap/                                  ★ NEW (4 JSON)
│       ├── purchase_canceled.json
│       ├── purchase_error.json
│       ├── purchase_pending.json
│       └── purchase_success.json
├── helpers/
│   ├── load_claude_fixture.dart              ★ NEW (shared loader)
│   └── orchestrator_test_doubles.dart        ★ NEW (FakeOrchestrator + Fakes)
├── core/
│   └── service_locator_test.dart             ★ NEW (DI sanity)
├── models/
│   ├── entitlement_token_test.dart           — (within iap_entitlement_service_test.dart)
│   ├── iap_purchase_state_test.dart          ★ NEW
│   ├── report_purchase_result_test.dart      ★ NEW (Chunk 5 부채 fix)
│   └── scan_history_entry_test.dart          ★ NEW
├── screens/
│   ├── analysis_result_screen_test.dart      ★ NEW
│   ├── paid_report_screen_test.dart          ★ NEW
│   ├── report_failure_screen_test.dart       ★ NEW
│   ├── report_generating_screen_test.dart    ★ NEW
│   └── report_purchase_screen_test.dart      ★ NEW
├── services/
│   ├── iap_billing_service_test.dart         ★ NEW
│   ├── iap_entitlement_service_test.dart     ★ NEW
│   ├── report_purchase_orchestrator_test.dart  ★ NEW
│   └── scan_history_service_test.dart        ★ NEW (markAsPaid)
└── widgets/
    └── refund_policy_disclaimer_test.dart    ★ NEW
```

---

## 5. 품질 지표 (현 시점)

| 지표 | 결과 |
|------|------|
| 총 테스트 | **300 passed** (live integration 제외) |
| `flutter analyze` | **0 issues** |
| 가격 하드코딩 (`$1.99`/`"1.99"`/`USD`/`formattedPrice="..."`) | **0 매치** |
| DS v0.4 토큰 (신규 6 화면 + 1 위젯) `Color(0x...)`/`TextStyle(...)` 직접 사용 | **0** |
| Korean UI 문자열 (신규 화면) | **0** |
| `print()` (신규 lib 코드) | **0** |
| `.env` staging 사고 | **0** |
| 1 commit = 1 intent | ✅ (11/11) |
| 명시 경로 staging | ✅ (모든 commit, `git add .`/`-A` 0회) |
| `/review-cycle` 게이트 | 모든 commit 통과 |

---

## 6. 자매 프로젝트 참조 (변경 없음)

- SuppleCut(yak-biseo) MVP 패턴 — `service_locator` lazySingleton, `try-catch + safe defaults` JSON 파싱, 토큰 디자인 v0.4
- IAP 패턴은 SuppleCut과 분기 — Pattern D (지연 consume + 자동 환불 + Free Retry)는 PetCut 신규 도입

---

## 7. 확인 필요 가정 (Pre-MVP)

| # | 가정 | 검증 시점 |
|---|------|----------|
| 1 | Reddit r/dogs / r/cats 카르마 0 → 200+ 도달 시 베타 모집 가능 | Sprint 3 |
| 2 | 미국 반려동물 보호자 40-55세 — 사료 + 보충제 동시 사용률 ≥ 30% | 베타 인터뷰 |
| 3 | $1.99/리포트 — 첫 결제 전환율 ≥ 5% | 베타 |
| 4 | Claude Sonnet 4.5 응답 일관성 — 동일 입력 vs 5회 호출 시 헤드라인 일치율 ≥ 80% | Sprint 3 별도 측정 |
| **5** | **★ Pattern D fail-closed UX 작동 — 라이브 결제 성공 + Claude 강제 실패 시 Google 자동 환불 발생 + 사용자 free retry 경로 진입 가능** | **Sprint 2 라이브 통합 테스트** |
| 6 | 60초 대기 이탈률 ≤ 10% | 베타 |
| 7 | App Store / Play Console 결제 SKU 승인 — 기각 사유 0 | Sprint 2 라이브 |

---

## 8. 다음 액션 (우선순위 순)

1. **★ 라이브 IAP 통합 테스트** — Play Console alpha track upload + license tester 등록 + 실 기기 1회 결제 + Pattern D fail-closed 시나리오 검증 (별도 세션)
2. v1.1 백로그 우선순위 결정 (§10)
3. Reddit 가정 1 검증 (카르마 200+ 도달 시)
4. STATUS_0430 → STATUS_05XX 갱신 (라이브 테스트 결과 기반)

---

## 9. 결정 로그 (Decision Log)

### 2026-04-30 (Sprint 2 IAP 인프라)

#### Phase 1 검증 (락인 G1~G4, P1.1~P1.8)
- **G1**: `flutter_secure_storage` 추가 승인
- **G2**: Dart SDK 제약 `>=3.4.1` 유지 (현 패키지 호환)
- **G3**: `scan_history_entry.isPaidReport` 패치 Chunk 2 통합 (이후 Chunk 2a/2b로 분리)
- **G4**: Chunk 1.5 결과 별도 보고 후 Chunk 1 진입 (gate 패턴 정착)
- **P1.1~P1.8**: 8 검증 항목 (SDK / pubspec / minSdk / Manifest / CTA 위치 / `isPaidReport` 추가 가능성 / DI 패턴) 모두 통과

#### Plan-first 락인 (D1~D9, Phase 2)
- **D1**: Pattern D 채택 (purchased 후 consume 보류 → Claude 실패 시 자동 환불 + Free Retry)
- **D2**: secure_storage 토큰 보관 (HMAC v1.1)
- **D3**: 단일 SKU `petcut_report_standard_v1`
- **D4**: 4-service 생성자 주입
- **D5**: silent grantFreeRetry (R1.3 dialog v1.1)
- **D6**: 실패 화면 verbatim 카피 락인
- **D7**: Pattern D 상태머신 5-state
- **D8**: 결제 전+실패 화면 환불 안내 단일 위젯
- **D9**: v1.1 백로그 Voided Purchases API

#### Phase 2 chunks 진행 락인
- **G3-revisit**: Chunk 2를 2a (scan_history) + 2b (IAP 모델) 분리
- **E1~E4**: EntitlementToken schema (4 fields), single-key, JSON, secure_storage only
- **O1~O3**: Orchestrator + Chunk 2b 부채 fix 단일 commit, 4-service 생성자 주입, Plan §5 상태머신
- **W1~W3**: `recoverPendingPurchases` Chunk 6.5 분리, markAsPaid tests Chunk 6 동시 처리, lazySingleton + explicit factory 패턴
- **R1.1~R1.3**: 부팅 시 자동 fire-and-forget, R1.2 정책 (미consume + 토큰 없음 → grant), silent UX
- **U1~U8**: 별도 Screen + ProductDetails.price 그대로 + Free retry CTA 변경 + D8 fine print + Suggestion blue
- **V1~V5**: pushReplacement 흐름, V2 60-90s 카피, PopScope 차단, ListView 5섹션, PDF 별도 sprint
- **X1~X4**: CTA 항상 표시, 가격 미표시 (PurchaseScreen이 첫 노출), Primary Button, scanId 자동 추적

### 2026-04-29 (Claude API)

(STATUS_0429 §3.3 그대로 reference)

### 2026-04-28

(STATUS_0428 reference)

### 2026-04-21

(STATUS_0421 reference)

### 2026-04-20

(STATUS_0420 reference)

---

## 10. v1.1 백로그 ★

| # | 항목 | 진입 조건 |
|---|------|----------|
| 1 | **HMAC 토큰 검증** | 위변조 ROI 측정 (실 사용자 환경 + jailbroken/rooted 비율 ≥ 5% 또는 부정 결제 시도 감지 시) |
| 2 | **Voided Purchases API 연동** | 사용자 ≥ 100건 도달 시 (refund 운영 부담 시그널 발생 시점) |
| 3 | **"이전 결제 이어가기" UX dialog** | 베타 인터뷰에서 "왜 결제 후 보고서가 없냐" 시그널 ≥ 2건 |
| 4 | **풍부한 UI surface** (alertCards/riskSections/triageBanner.tier per-section severity 등) — **우선순위 1** | Sprint 2 라이브 통합 테스트 통과 직후 (UI fidelity가 다음 차별화 축) |
| 5 | `analysis_result_screen.dart` inline `TextStyle()` cleanup | 별도 cleanup chunk 또는 풍부한 UI surface 작업과 병행 (기존 부채) |
| 6 | **Streaming v1.1** (Claude API streaming) | 60초 대기 이탈률 ≥ 10% 측정 시 (베타 시작 후) |
| 7 | **Prompt caching v1.1** | Sonnet 4.6 cache hits $0.30/MTok = 약 1/10 비용 — 사용자 트래픽 ≥ 100 리포트/일 도달 시 |
| 8 | **Per-section severity badges** | §4 풍부한 UI surface 작업과 묶음 처리 (별도 진입 조건 없음) |

각 항목은 진입 조건 미충족 시 backlog 유지. 우선순위 4가 가장 가까운 후보.

---

## 11. Changelog

- **2026-04-30** — 본 문서 작성. Sprint 2 IAP 인프라 완성 공식 선언. 11 commits (5732e60~fd5c913), +93 tests (207→300), 9-step end-to-end 사용자 흐름 검증, Pattern D consume 게이트 다층 verifyNever 박힘. 다음 작업: 라이브 IAP 통합 테스트 (별도 세션, Play Console alpha + license tester + 실 기기). v1.1 백로그 8건 진입 조건 명시.
- **2026-04-29** — STATUS_0429 (Claude API 인프라 완성 + 통합 테스트 baseline + IAP 진입 대기)
- **2026-04-28** — STATUS_0428 (weight_display follow-up + Claude API 설계 결정)
- **2026-04-21** — STATUS_0421 (Sprint 2 프롬프트 완결)
- **2026-04-20** — STATUS_0420 (Sprint 1 완결)

---

## 12. Sprint 2 IAP 회고

### 잘된 점

- **Phase 1 read-only 검증 + Plan-first 락인 패턴이 효과적이었음**: P1.1~P1.8 검증으로 in_app_purchase 이미 등록(P1.2) / minSdk Flutter 기본값(P1.4) 등 사전 가정 오류 제거. Plan-first 락인(D1~D9, E1~E4 등)은 11 commits 동안 0 scope creep으로 완성에 기여.
- **11 commits 누적 디버그 5회만 발생, 모두 첫 시도에서 90%+ 통과**: 1차 실패는 (Chunk 3 stream identity / Chunk 4 not applicable / Chunk 5 registerFallbackValue / Chunk 7a unnecessary_import / Chunk 7b 4차 fix). 모두 1~2회 수정으로 통과.
- **DS v0.4 토큰 100% 준수**: 신규 6 화면 + 1 위젯에서 `Color(0x...)` / `TextStyle(...)` 직접 사용 0. 기존 잔존 부채(`analysis_result_screen.dart`)는 v1.1 백로그로 분리.
- **Pattern D consume 게이트 다층 verifyNever**: 모델 / 서비스 / orchestrator / recovery / UI 5 레이어 각각에서 박혀 있어 새 분기 추가 시 컴파일 또는 테스트 단계에서 surfaces.
- **D6 / D8 verbatim 카피 단일 소스 보장**: `RefundPolicyDisclaimer.text` 정적 상수 + `_refundCopy` static const → 카피 drift 위험 0.

### 개선점

- **Chunk 7b 4차 fix**: 위젯 테스트 환경 한계 학습 (CircularProgressIndicator indefinite animation + single-route navigator pop 단언 + ListView lazy build + Page transition multi-frame). 첫 실패 후 4단계 우회. 향후 widget test 패턴 라이브러리 정리 권장.
- **inline TextStyle 부채 잔존**: `analysis_result_screen.dart`에 Sprint 1 시점부터 다수 존재. Chunk 8 스코프 외로 분리, v1.1 백로그 #5에 명시. 풍부한 UI surface (#4) 작업과 병행 권장.
- **테스트 helper 진화 보고 누락**: `orchestrator_test_doubles.dart`이 Chunk 7a 시작 후 Chunk 7b/8에서 `pendingPurchaseCompleter` 추가, scanId nullable 정합 등 누적 진화 — 별도 helper changelog 필요할 수 있음.

### 학습

- **Hand-rolled `Fake*` vs mocktail trade-off**: `FakeOrchestrator` / `FakeBillingService` / `FakeEntitlementService` 등은 mocktail보다 setup 단순. `registerFallbackValue` 보일러플레이트 0. 향후 widget 테스트는 `Fake` 우선, 서비스 단위 테스트는 mocktail (call counting / verifyNever) 우선.
- **`pendingPurchaseCompleter` 패턴 보편화**: single-route navigator의 `_history.isNotEmpty` 단언을 안전 회피. 위젯 테스트에서 비동기 흐름 mid-flight 단언이 필요할 때 표준 패턴.
- **Stream identity 함정**: `StreamController.broadcast().stream`은 매 호출마다 `_ControllerStream` 래퍼 반환 가능 → `same()` 매처 부적합. `verify(getter)` + `isA<Stream<...>>` + 동작 등가성으로 우회.
- **Page transition multi-frame**: `tester.pump(Duration(seconds: 1))` 단일 호출은 1프레임. Material page transition은 여러 프레임 필요 → `for (n) await tester.pump(50ms)` 시퀀스로 우회.
- **`flutter_secure_storage` 9.x vs 10.x**: 10.0.0이 minSdk 23 요구. 9.2.x는 21 호환 — `flutter.minSdkVersion` 기본값 위임 상태에서는 9.x 보수적 선택이 안전.
