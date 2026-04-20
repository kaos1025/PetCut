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
- bg: `PcColors.surface2`
- radius: `PcRadius.md`
- padding: 10 vertical · 12 horizontal
- 좌측: brand 컬러 원형 아바타 (40x40, 이니셜, white text)
- 우측: name (body/500) + 메타 (caption, textSec: `Golden Retriever · 30 kg · 4y`)

---

## 8. 결정 로그

### 8.1 v0에서 락인
- Brand accent: Sage `#1D9E75` (SuppleCut 대비 건강/pet-safe 톤 유지, 파스텔/유치함 회피)
- Warm neutral (`#FAF8F3`): 수의학 앱의 차가움 완화, "가족/홈" 0.5스푼
- Pretendard: 한영 혼용 시각 일관성 + SuppleCut 플랫폼 통일
- 두 weight (400/500)만: 시스템 UI와 충돌 회피, 시각 노이즈 최소화
- Suggestion을 Blue로 분리: 경고 ≠ 해결책, 액션 스캔 가능성 향상

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
