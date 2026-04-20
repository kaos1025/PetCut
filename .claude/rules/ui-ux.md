---
description: PetCut UI/UX 규칙. UI 위젯이나 화면을 수정할 때 적용.
globs: "lib/screens/**/*.dart,lib/presentation/**/*.dart,lib/widgets/**/*.dart"
---

# UI/UX Rules (PetCut 전용)

## CRITICAL

- **DO NOT** write any UI-facing text in Korean (or any non-English language). PetCut is **English only**.
- **DO NOT** hardcode IAP prices. Always render `ProductDetails.price` (Play Billing `formattedPrice`).
- **DO NOT** display analysis results without a veterinary disclaimer: *"Not a substitute for professional veterinary advice."*

## HIGH

- **DO** design for **US pet owners aged 40–55** — use sufficiently large text sizes and high contrast ratios.
- **DO** write all UI-facing text in **English**.
- **DO** display currency as **USD** only.
- **DO** use `Theme.of(context)` for colors, text styles, and spacing.
- **DO** surface the active `PetProfile` (species, weight, life stage) on any scan/result screen so users can verify the analysis context.

## NORMAL

- **DO** use a **traffic-light** scheme for severity:
  - `safe` → Green
  - `caution` → Amber/Orange
  - `critical` → Red
- **DO** handle loading, error, and empty states in every screen/widget.
- **DO** allow weight input toggle between **kg** and **lbs** (internal storage is always kg).
- **DON'T** use small or low-contrast text that older users may struggle to read.
- **DON'T** recompute or re-rank Gemini's analysis in the UI layer — render the JSON as-is ("Decisions by Gemini, Display by App").
