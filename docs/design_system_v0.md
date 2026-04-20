# PetCut Design System v0

> 락인 일자: 2026-04-20
> 상태: v0 — 첫 공식 버전. 수정 시 이 문서부터 업데이트 후 코드 반영.
> 자매 프로젝트 SuppleCut과 DS를 공유 (플랫폼 통일 · 예비창업패키지 내러티브).
> 반영 위치: `lib/theme/petcut_tokens.dart`, `lib/main.dart` ThemeData

---

## 0. At a glance

| 항목 | 결정 |
|---|---|
| Brand accent | Sage `#1D9E75` |
| Neutral 톤 | Warm-tinted (ink `#1A1A1A` / surface2 `#FAF8F3`) |
| Semantic | Amber / Red / Green 트리오 + Blue (Suggestion) |
| Font | Pretendard · 2 weights (400 / 500) |
| Scale | 28 · 22 · 17 · 16 · 13 · 11 |
| Spacing | 4pt grid (4 / 8 / 12 / 16 / 24 / 32 / 48) |
| Radius | 8 · 12 · 20 · ∞ |
| Dark mode | v2 디퍼 |

---

## 1. 원칙 (Non-negotiable)

### 1.1 Traffic Light Core
🟢🟡🔴 신호등 메타포가 사용자 눈에 0.5초 안에 들어와야 함. 결과 화면 상단은 반드시 신호등 도트 + 한 단어 상태 (`Perfect` / `Caution` / `Warning`)로 시작.

### 1.2 4050-friendly
- Body 텍스트는 **16px 이상** (Material 기본 14 아님)
- 주요 CTA는 **56px 이상 높이**
- 화면 뎁스 **2단계 이하**
- 탭 타겟 최소 48px

### 1.3 Flat, no tricks
- Gradient · Drop shadow · Blur · Glow 전부 금지
- 구조 표현은 **Border (0.5 ~ 1px) + Surface 대비**로만
- Elevation 개념 없음

---

## 2. 컬러 토큰

### 2.1 Brand
| Token | Hex | 역할 |
|---|---|---|
| `brand` | `#1D9E75` | Primary accent · 아바타 배경 · selected 상태 |
| `brandTint` | `#E1F5EE` | Pet 프로필 카드 bg · 친근한 뱃지 bg |

### 2.2 Neutrals
| Token | Hex | 역할 |
|---|---|---|
| `ink` | `#1A1A1A` | 주 텍스트 · Primary button bg |
| `surface` | `#FFFFFF` | 주 화면 bg · 카드 bg |
| `surface2` | `#FAF8F3` | 서브 bg · 패시브 슬롯 · 입력창 bg |
| `border` | `#EDE9DF` | 모든 경계선 (1px, border-only 구조) |
| `textSec` | `#6B6B63` | 보조 텍스트 (caption, source 정보) |
| `textTer` | `#9A9A90` | 힌트 텍스트 (placeholder) |

### 2.3 Semantic · Traffic Light
| Status | bg | accent | text |
|---|---|---|---|
| Perfect (green) | `#EAF3DE` | `#639922` | `#173404` |
| Caution (amber) | `#FAEEDA` | `#EF9F27` | `#412402` |
| Warning (red) | `#FCEBEB` | `#E24B4A` | `#501313` |

### 2.4 Semantic · Suggestion (action prompt)
| Status | bg | accent | text |
|---|---|---|---|
| Suggestion (blue) | `#E6F1FB` | `#378ADD` | `#042C53` |

**중요한 색상 사용 규칙:**
- 색상 하드코딩 절대 금지. 모든 색은 `PcColors.*`로만 참조.
- 경고(Amber/Red) ≠ 해결책(Blue). "이걸 빼세요/이걸 대체하세요" 같은 액션 제안 카드는 **반드시 Suggestion 블루**만 사용.
- 컬러 bg 위 텍스트는 **같은 램프의 어두운 쉐이드**를 사용. 절대 순수 `#000` 혹은 회색 금지.
- 색상은 의미를 인코딩. 카테고리가 아니라 **상태**에 매핑.

---

## 3. Typography

### 3.1 Font family
**Pretendard** (SuppleCut 공유)
- Source: https://github.com/orioncactus/pretendard
- 라이선스: SIL OFL 1.1
- 한글 + Latin 통합 디자인 → 한영 혼용 시 baseline/굵기 이질감 0
- 번들: Regular(400) + Medium(500) **두 개만** (총 ~1MB)

### 3.2 Scale
| Token | Size | Weight | Line-height | 용도 |
|---|---|---|---|---|
| `display` | 28 | 500 | 1.15 | 히어로 문구 ("Ready to scan") |
| `h1` | 22 | 500 | 1.25 | 스크린 타이틀 ("Caution · 1 conflict") |
| `h2` | 17 | 500 | 1.3 | 카드 타이틀 ("Vitamin D3") |
| `body` | 16 | 400 | 1.5 | 본문 텍스트 |
| `caption` | 13 | 400 | 1.5 | 보조 정보 (소스, 카운트) |
| `label` | 11 | 500 | 1.4 | UPPERCASE 라벨, letterSpacing 0.08em |

### 3.3 Typography 규칙
- 허용 weight는 **400 Regular, 500 Medium** 단 두 가지. 600/700/800/900 금지.
- **ALL CAPS는 11px 라벨만.** 본문/제목 ALL CAPS 금지.
- **Sentence case only.** Title Case 금지.
- **중간 볼드 금지.** 제품명·기능명은 `code style` 또는 칩으로.
- Line-height: display 1.15, h1 1.25, body 1.5, caption 1.5.

---

## 4. Spacing & Radius

### 4.1 Spacing scale (4pt grid)
`4 · 8 · 12 · 16 · 24 · 32 · 48`

| Token | Value | 용도 |
|---|---|---|
| `xs` | 4 | 아이콘-텍스트 간격 |
| `sm` | 8 | 칩 사이 · 인라인 요소 |
| `md` | 12 | 카드 내부 패딩 (세로) |
| `lg` | 16 | 스크린 좌우 패딩 · 카드 내부 (가로) |
| `xl` | 24 | 섹션 간 간격 |
| `xxl` | 32 | 주요 블록 구분 |

### 4.2 Radius
| Token | Value | 용도 |
|---|---|---|
| `sm` | 8 | 칩, 소형 컨트롤 |
| `md` | 12 | 기본 — 카드, 버튼, 배너, progress 카드 |
| `lg` | 20 | 바텀 시트, 히어로 카드, 폰 프레임 |
| `full` | 999 | 아바타, pill 버튼 |

### 4.3 Touch targets
- 최소 48px
- Primary CTA 56px
- 아바타 38~44px

---

## 5. Flutter 토큰 (복붙용)

`lib/theme/petcut_tokens.dart`에 그대로 저장.

```dart
import 'package:flutter/material.dart';

class PcColors {
  // Brand
  static const brand     = Color(0xFF1D9E75);
  static const brandTint = Color(0xFFE1F5EE);

  // Neutrals
  static const ink       = Color(0xFF1A1A1A);
  static const surface   = Color(0xFFFFFFFF);
  static const surface2  = Color(0xFFFAF8F3);
  static const border    = Color(0xFFEDE9DF);
  static const textSec   = Color(0xFF6B6B63);
  static const textTer   = Color(0xFF9A9A90);

  // Semantic — Perfect (green)
  static const okBg      = Color(0xFFEAF3DE);
  static const okAccent  = Color(0xFF639922);
  static const okText    = Color(0xFF173404);

  // Semantic — Caution (amber)
  static const warnBg     = Color(0xFFFAEEDA);
  static const warnAccent = Color(0xFFEF9F27);
  static const warnText   = Color(0xFF412402);

  // Semantic — Warning (red)
  static const dangerBg     = Color(0xFFFCEBEB);
  static const dangerAccent = Color(0xFFE24B4A);
  static const dangerText   = Color(0xFF501313);

  // Semantic — Suggestion (blue, actions only)
  static const infoBg     = Color(0xFFE6F1FB);
  static const infoAccent = Color(0xFF378ADD);
  static const infoText   = Color(0xFF042C53);
}

class PcText {
  static const display = TextStyle(fontSize: 28, fontWeight: FontWeight.w500, height: 1.15);
  static const h1      = TextStyle(fontSize: 22, fontWeight: FontWeight.w500, height: 1.25);
  static const h2      = TextStyle(fontSize: 17, fontWeight: FontWeight.w500);
  static const body    = TextStyle(fontSize: 16, fontWeight: FontWeight.w400, height: 1.5);
  static const caption = TextStyle(fontSize: 13, fontWeight: FontWeight.w400);
  static const label   = TextStyle(fontSize: 11, fontWeight: FontWeight.w500, letterSpacing: 0.88);
}

class PcRadius {
  static const sm   = 8.0;
  static const md   = 12.0;
  static const lg   = 20.0;
  static const full = 999.0;
}

class PcSpace {
  static const xs  = 4.0;
  static const sm  = 8.0;
  static const md  = 12.0;
  static const lg  = 16.0;
  static const xl  = 24.0;
  static const xxl = 32.0;
}
```

---

## 6. ThemeData 세팅

`lib/main.dart`의 MaterialApp:

```dart
MaterialApp(
  theme: ThemeData(
    fontFamily: 'Pretendard',
    scaffoldBackgroundColor: PcColors.surface,
    colorScheme: ColorScheme.light(
      primary: PcColors.ink,          // Primary button, selected
      secondary: PcColors.brand,      // Accent
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
  // ...
)
```

`pubspec.yaml`:

```yaml
flutter:
  fonts:
    - family: Pretendard
      fonts:
        - asset: assets/fonts/Pretendard-Regular.otf
          weight: 400
        - asset: assets/fonts/Pretendard-Medium.otf
          weight: 500
```

---

## 7. 핵심 컴포넌트 스펙

### 7.1 Primary Button
- bg: `PcColors.ink`
- fg: `PcColors.surface`
- padding: vertical 16, horizontal 20
- radius: `PcRadius.md` (12)
- font: size 15, weight 500
- 높이: 최소 56
- width: 보통 full-width (스크린 좌우 16 패딩 빼고)

### 7.2 Secondary Button
- bg: `PcColors.surface`
- fg: `PcColors.ink`
- border: 0.5, `PcColors.border`
- 나머지는 Primary와 동일

### 7.3 Nutrient Progress Bar (킬러피처 UI)
**구조:**
```
[Card · border 0.5 · radius 12 · padding 12h · 14v]
  [Row: nutrient 이름 (h2, 17/500) · 우측 퍼센트 (caption/500, 색상은 상태별)]
  [Track: 높이 6 · bg surface2 · radius 3]
    [Fill: 너비 = percent · 색상 = 상태 accent]
  [Caption: "1,003 IU / 3,000 IU daily" (11, textSec)]
  [Caption: "Food 503 + Suppl 500" (11, textSec)]
```

**퍼센트 상태 매핑 (체중 기준 독성 역치 대비):**
- 0~79% → 초록 accent, status label 생략
- 80~99% → 앰버 accent ("Monitor")
- 100~149% → 앰버 accent 굵게 ("Caution")
- 150%+ → 레드 accent ("Warning")
- D3 chronic_toxic 초과 시 → 레드 ("Critical")

### 7.4 Status Banner (Traffic Light)
- Result 스크린 최상단 배치
- bg: 상태별 bg 토큰 (`okBg` / `warnBg` / `dangerBg`)
- padding: 16h · 16v
- 내부: 좌측 신호등 도트 3개 (세로 stack, 현재 상태만 full opacity, 나머지 opacity 0.35)
- 우측: Display(28/500) 상태 단어 + caption 서머리 (`1 conflict · 2 cautions`)

### 7.5 Card
- bg: `PcColors.surface`
- border: 0.5 `PcColors.border`
- radius: `PcRadius.md` (12)
- padding: 12 vertical · 14 horizontal (카드 종류에 따라 ±4)

### 7.6 Chip
- bg: `PcColors.surface2` (비선택) 또는 `PcColors.brandTint` (선택)
- fg: `PcColors.ink` (비선택) 또는 `#085041` (선택, teal 800)
- padding: 6 vertical · 10 horizontal
- radius: `PcRadius.sm` (8)
- font: caption (13 / 400) 또는 선택 시 500

### 7.7 Image Slot (Scan 화면)
- 정사각형 (aspect 1:1)
- 채워진 상태: 제품 사진 · radius `PcRadius.md`
- 빈 상태: `PcColors.surface2` bg · 0.5 dashed `PcColors.border` · 중앙에 `+` (textTer)
- 아래에 caption (제품명) + label (카테고리)

### 7.8 Pet Profile Card
- bg: `PcColors.surface`
- border: 0.5 `PcColors.border`, radius `PcRadius.md`
- padding: 10 vertical · 14 horizontal
- 좌측: **발바닥 아이콘 아바타** (v0 친근함 우선 결정)
  - 원형 48x48
  - bg: `PcColors.brandTint` (#E1F5EE)
  - 아이콘: `Icons.pets` (Material) 또는 커스텀 paw SVG, 색상 `PcColors.brand` (#1D9E75)
  - 아이콘 size 24
  - v2에서 multi-pet 도입 시 이니셜 텍스트 변형 검토 (섹션 8.3 참조)
- 우측: name (body/500) + 메타 (caption, textSec: `Golden Retriever · 30 kg · 4y`)
- 우측 끝: 편집 연필 아이콘 (`Icons.edit`, size 20, color `PcColors.textSec`)

### 7.9 Save Button (Secondary + State)
명시적 저장이 필요한 화면에서 사용. Result 스크린이 첫 사용처.

**두 상태:**
- **Idle (저장 전):**
  - Outlined 스타일: bg `PcColors.surface`, border 0.5 `PcColors.border`, fg `PcColors.ink`
  - radius: `PcRadius.md`
  - padding: vertical 10, horizontal 14
  - 높이 40 (Primary CTA 56보다 낮춰 위계 구분)
  - Icon `Icons.bookmark_border` size 18 + label "Save scan" (PcText.body w500)
  - icon-label gap 6
- **Saved (저장 후):**
  - 같은 shape, 같은 크기
  - Icon `Icons.bookmark` size 18, color `PcColors.brand`
  - Label "Saved" color `PcColors.brand`
  - border color `PcColors.brand` (transition 150ms)
  - 비활성화 (다시 탭해도 반응 없음)

**Snackbar (탭 직후 1회):**
- bg `PcColors.ink`, fg `PcColors.surface`
- radius `PcRadius.md`
- text: "Saved to history" (PcText.body w400, size 14로 약간 축소)
- duration 2초
- 위치: 화면 하단에서 16px 띄움
- SnackBarBehavior.floating

### 7.10 Unsaved Changes Dialog
미저장 상태에서 뒤로가기 시 1회 확인.

**AlertDialog 스펙:**
- bg: `PcColors.surface`
- radius: `PcRadius.lg` (20)
- padding: 24 전방위
- 타이틀: "Save this scan?" (PcText.h2, 17/500)
- 본문: "You can review it later in Recent scans." (PcText.body, color textSec)
- 버튼 2개 수평 정렬:
  - Secondary (좌): "Discard" — textButton, color `PcColors.textSec`
  - Primary (우): "Save" — FilledButton(ink bg), 높이 40
- 버튼 간 gap: 8
- 외부 탭으로 dismiss 가능 (barrierDismissible: true) — 아무 것도 안 함 (스크린 유지)

### 7.11 Section Header
리스트 섹션 제목용. 홈의 "Recent scans", "See all" 링크 등.

**구조:**
- Row, `MainAxisAlignment.spaceBetween`
- 좌측: 제목 (PcText.label, UPPERCASE, color `PcColors.textSec`)
  - 예: `RECENT SCANS`
- 우측 (선택): 링크 (PcText.caption w500, color `PcColors.ink`)
  - 예: `See all →`
  - 화살표는 `Icons.chevron_right` size 14 color textSec 또는 글리프 `→`
- padding: bottom 8 (섹션 내용과의 간격)

### 7.12 Recent Scan List Item
홈의 Recent 섹션에 쌓이는 스캔 기록 카드. DS 7.5 Card 스펙 기반 + 리스트 특화 조정.

**구조:**
- bg `PcColors.surface`
- border 0.5 `PcColors.border`, radius `PcRadius.md`
- padding: vertical 10, horizontal 14
- InkWell 감싸기 (전체 영역 탭 → 해당 Result 다시 열기)
- Row 내부 3영역:

**좌측 — Status dot (8x8 원형):**
| overall_status | dot color |
|---|---|
| `perfect` | `PcColors.okAccent` |
| `caution` | `PcColors.warnAccent` |
| `warning` | `PcColors.dangerAccent` |

- 세로 중앙 정렬
- 우측 여백 `PcSpace.md` (12)

**중앙 — 메인 정보 (Expanded):**
- 상단: 제품명 요약 (PcText.body w500)
  - 포맷: `"Product A + Product B"` (2개)
  - 3개 이상: `"Product A + 2 more"`
  - 단일 긴 이름은 `overflow: TextOverflow.ellipsis`, `maxLines: 1`
- 하단 (4px 간격): 메타 (PcText.caption, color `PcColors.textSec`)
  - 포맷: `"{relative time} · {summary}"`
  - relative time: "Today", "Yesterday", "3d ago" (30일 이내), 그 이후는 "Jan 15"
  - summary 예시:
    - conflict 0, caution 0 → "All clear"
    - conflict N, caution 0 → "N conflict(s)"
    - conflict 0, caution M → "M caution(s)"
    - 둘 다 있음 → "N conflict · M caution"

**우측 — Chevron (Icons.chevron_right):**
- size 18, color `PcColors.textTer`
- "탭 가능" 시그널

**리스트 배치:**
- 아이템 간 간격: `PcSpace.sm` (8)
- `ListView` 아닌 `Column` 권장 (3개 고정이라 스크롤 불필요, 홈 전체 스크롤은 상위 컨테이너가 담당)

### 7.13 Empty State Card
Recent 섹션이 비어있을 때 쓰는 더미 카드. DS 7.12의 모양을 **복제**해서 사용자가 "쌓이면 이렇게 보이는구나"를 학습하게 함.

**구조:**
- 7.12 Recent Scan List Item과 동일한 외형 (border, radius, padding)
- 하지만 내용이 톤다운됨:
  - 좌측 dot 자리: `Icons.bookmark_add_outlined` size 20, color `PcColors.textTer`
    - (status dot 아님 — 저장할 게 없다는 의미)
  - 중앙 상단: `"Your scans will appear here"` (PcText.body w500, color `PcColors.textSec`)
  - 중앙 하단: `"Tap Scan Labels above to start"` (PcText.caption, color `PcColors.textTer`)
  - 우측 chevron 없음 (탭 불가)
- InkWell 없음 (탭 불가)

**사용 조건:**
- `scanHistory.isEmpty` 일 때만 렌더
- 첫 스캔 저장 후에는 자동으로 실제 Recent 카드들로 대체됨

### 7.14 Full-screen Loading State
Analysis Loading 같이 화면 전체가 대기 상태일 때.

**구조:**
- 전체 화면 세로 중앙 정렬 (Column `mainAxisAlignment: center`, `crossAxisAlignment: center`)
- bg: `PcColors.surface` (앱 배경 그대로)
- 내부 3단:
  - CircularProgressIndicator
    - color: `PcColors.brand` (기본 primary 컬러가 tenant에 따라 달라질 수 있으므로 명시)
    - strokeWidth: 3 (기본 4는 두꺼움)
    - size: 40×40 (Container로 감싸 강제)
  - SizedBox height `PcSpace.xl` (24)
  - 메인 메시지 (PcText.h2, color `PcColors.ink`)
    - 예: "Analyzing..."
  - SizedBox height `PcSpace.sm` (8)
  - 서브 메시지 (PcText.body, color `PcColors.textSec`, textAlign center)
    - 예: "Checking food + supplement combos"
- 좌우 패딩: `PcSpace.xl` (24)

### 7.15 Full-screen Error State
네트워크 에러, 분석 실패 등 전체 화면 에러 시. Analysis Loading의 실패 경로 첫 사용처.

**구조:**
- 전체 화면 세로 중앙 정렬, 좌우 패딩 `PcSpace.xxl` (32)
- 내부 5단:
  - Icon
    - size 48 (DS 내 최대. 아이콘이 크면 거슬림, 48이 균형점)
    - color `PcColors.textTer` (톤다운, 공포 유발 X)
    - 기본: `Icons.wifi_off` (네트워크 에러)
    - 일반 에러: `Icons.error_outline`
  - SizedBox height `PcSpace.lg` (16)
  - 메인 메시지 (PcText.h1, color `PcColors.ink`, textAlign center)
    - 네트워크: "Connection error"
    - 일반: "Analysis failed"
  - SizedBox height `PcSpace.sm` (8)
  - 서브 메시지 (PcText.body, color `PcColors.textSec`, textAlign center, maxLines 3)
    - 네트워크: "Check your internet connection and try again."
    - 일반: "Something went wrong. Please try again."
  - SizedBox height `PcSpace.xl` (24)
  - 버튼 그룹 (Row, `mainAxisAlignment: center`):
    - Primary: "Try again" (DS 7.1 Primary CTA 축소형, 높이 48, 좌우 padding 24)
      - onPressed: **같은 화면 내 재시도** (Home으로 pop 금지)
    - SizedBox width `PcSpace.md` (12)
    - Secondary: "Back" (DS 7.2 Secondary, 높이 48)
      - onPressed: Home으로 pop

**톤 원칙:**
- 빨간색 사용 금지 (에러지만 사용자 탓 아님, 위협 톤 회피)
- 이모지 금지 ("😭", "⚠️" 같은 장식 안 씀)
- 기술 용어 금지 ("SocketException", "HTTP 503" 등)
- 재시도가 앞, 포기가 뒤 (사용자 성공 경로 우선)

---

## 8. 결정 로그

### 8.1 v0에서 락인
- Brand accent: Sage `#1D9E75` (SuppleCut 대비 건강/pet-safe 톤 유지, 파스텔/유치함 회피)
- Warm neutral (`#FAF8F3`): 수의학 앱의 차가움 완화, "가족/홈" 0.5스푼
- Pretendard: 한영 혼용 시각 일관성 + SuppleCut 플랫폼 통일
- 두 weight (400/500)만: 시스템 UI와 충돌 회피, 시각 노이즈 최소화
- Suggestion을 Blue로 분리: 경고 ≠ 해결책, 액션 스캔 가능성 향상
- **Pet avatar: 발바닥 아이콘 채택** (04/20) — 이니셜 대안 대비 반려동물 도메인 친근함 승리. v0 single-pet 전제에선 개성 구분 불필요. Multi-pet 도입 시점(v2)에 재검토.

### 8.2 v2로 디퍼
- **Dark mode** — 4050 타겟은 라이트 선호, 접근성 체크 오버헤드 큼
- **Variable font** — `FontVariation` Flutter 다루기 번거로움
- **Display용 weight 확장 (600+)** — 현재 스케일로 충분
- **다중 브랜드 테마** — PetCut과 SuppleCut의 시각적 구분이 필요해지면
- **한글 dynamic subsetting** — 웹 전용, 모바일 앱 번들에선 무의미

### 8.3 논의 대기
- 펫 종별 아이콘 세트 (dog/cat/rabbit/bird 등) — Sprint 2 시점
- 다크 제품 사진이 흰 bg에서 눈에 띄게 하는 이미지 처리 전략
- Loading 화면의 애니메이션 (currently 미정)
- **Multi-pet 시나리오의 아바타 구분 전략** — v2에서 펫 2마리 이상 지원 시, 발바닥 아이콘 유지(+이름 글자로 구분)할지, 이니셜 전환할지, 펫 사진 업로드 도입할지 재검토

---

## 9. Claude Code 프롬프트 템플릿

### A. 새 화면 추가 시
```
design_system_v0.md를 따라줘.
- 색상은 PcColors.* 만 사용 (하드코딩 금지)
- 텍스트 스타일은 PcText.* 만 사용
- spacing은 PcSpace.* · radius는 PcRadius.* 만 사용
- border는 0.5 width · PcColors.border
- gradient/shadow/blur 일체 금지
flutter analyze 0 errors 유지.
```

### B. 기존 화면 리팩토링 시
```
lib/screens/[파일명].dart를 design_system_v0.md 기준으로 리팩토링해줘.
- 하드코딩된 Color() → PcColors.*
- 하드코딩된 TextStyle() → PcText.*
- 하드코딩된 EdgeInsets/padding 숫자 → PcSpace.*
- 하드코딩된 BorderRadius 숫자 → PcRadius.*
- 불필요한 BoxShadow 제거
- flutter analyze 0 errors 유지
```

### C. Result 화면 특화
```
analysis_result_screen.dart를 design_system_v0.md의 7.3 Nutrient Progress Bar, 
7.4 Status Banner 스펙 그대로 구현해줘. 
퍼센트 상태 매핑(0-79/80-99/100-149/150+)도 반영.
```

---

## 10. 참조

- Pretendard 릴리스: https://github.com/orioncactus/pretendard/releases
- SuppleCut (자매 프로젝트 · 참조만): https://github.com/kaos1025/yak-biseo_mvp.git
- 본 문서와 짝을 이루는 코드: `lib/theme/petcut_tokens.dart`

---

## Changelog

- **v0 · 2026-04-20** — 첫 공식 락인. Brand Sage, Pretendard, 4pt grid, 3+1 semantic. Dark mode v2 디퍼.
- **v0.1 · 2026-04-20** — Pet Profile Card 아바타를 이니셜 텍스트 → 발바닥 아이콘(`Icons.pets` + brandTint bg)으로 변경. 반려동물 도메인 친근함 우선. Multi-pet 전략은 v2로 디퍼.
- **v0.2 · 2026-04-20** — Save Button (7.9) + Unsaved Changes Dialog (7.10) 추가. Scan history 명시적 저장 패턴 정립. Result 스크린이 첫 사용처.
- **v0.3 · 2026-04-20** — Section Header (7.11), Recent Scan List Item (7.12), Empty State Card (7.13) 추가. 홈 Recent 섹션 + 첫 방문 학습 경로 정립. "See all" 링크는 Sprint 2 전체 History 스크린 대기.
- **v0.4 · 2026-04-20** — Full-screen Loading (7.14), Full-screen Error (7.15) 추가. Analysis Loading의 에러 UI 정식 스펙화 + 톤 원칙 (위협 X, 기술 용어 X, 재시도 우선) 명시.
