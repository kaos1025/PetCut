---
description: PetCut Flutter/Dart 코딩 규칙. Dart 파일을 생성하거나 수정할 때 적용.
globs: "lib/**/*.dart"
---

# Flutter/Dart Coding Rules (PetCut)

## CRITICAL

- **DO NOT** hardcode API keys (`GEMINI_API_KEY`, `GOOGLE_API_KEY`, `ANTHROPIC_API_KEY`, Firebase), tokens, or passwords. Use `flutter_dotenv`.
- **DO NOT** hardcode IAP prices. Always render `ProductDetails.price` (Play Billing `formattedPrice`).
- **DO NOT** use `dynamic` type unless absolutely necessary.
- **DO NOT** use `!` (null assertion) without guaranteed non-null context — prefer `??`, `?.`, or null checks.
- **DO NOT** re-compute, re-rank, or override Gemini's analysis output in app code. Principle: **"Decisions by Gemini, Display by App"**.
- **DO NOT** hardcode toxicity thresholds (D3 `0.01 mg/kg/day`, Iron, Ca `1.2%/1.5%`, etc.) inline — centralize in `lib/constants/toxicity_thresholds.dart`.
- **DO NOT** perform heavy computation or I/O inside `build()` methods.
- **DO NOT** call HTTP/AI services directly from UI widgets.

## HIGH

- **DO** use `snake_case.dart` filenames, `PascalCase` classes/enums, `camelCase` variables/functions.
- **DO** prefer `final` and `const` wherever possible.
- **DO** use explicit type declarations — avoid `var` for non-obvious types.
- **DO** follow Effective Dart and null-safety conventions.
- **DO** decompose widgets: no single widget file should exceed ~200 lines.
- **DO** use `ListView.builder` (or similar lazy builders) for long/dynamic lists.
- **DO** handle all UI states: loading, error, empty, data.
- **DO** store weight internally in **kg**; convert for UI display only (kg/lbs toggle).

## NORMAL

- **DO** use `ChangeNotifier` + `Provider` for state management (project standard).
- **DO** register services (Gemini, Claude, IAP, PetProfile) via `get_it` in `lib/core/service_locator.dart`.
- **DO** keep business logic in ChangeNotifier/Service, not in widget code.
- **DO** follow UI → Service → External API layering (no UI → API direct calls).
- **DO** wrap AI-generated JSON parsing in `try-catch` with safe conversions — match the SuppleCut pattern:
  ```dart
  (json['amount'] as num?)?.toDouble() ?? 0.0
  (json['warnings'] as List?)?.cast<String>() ?? const []
  ```
- **DO** inject the current `PetProfile` (species, weight kg, life stage) into every Gemini analysis request.
- **DO** place prompt strings in `lib/prompts/` (`gemini_prompt_pet.dart`, `claude_prompt_pet.dart`) — not inline in services.
