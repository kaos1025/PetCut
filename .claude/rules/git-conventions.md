---
description: PetCut Git 커밋/푸시 규칙. 커밋 메시지 작성이나 git 작업 시 적용.
globs: ""
---

# Git Conventions (PetCut)

## CRITICAL

- **DO NOT** commit `.env`, `.env.*`, credentials, API keys (Gemini / Google / Anthropic / Firebase), keystores, or secret files.
- **DO NOT** commit hardcoded IAP prices or pricing strings (`$1.99`, `1.99 USD`, etc.).
- **DO NOT** mix multiple intents in one commit (**1 commit = 1 intent**).
- **DO NOT** commit with `flutter analyze` errors present.
- **DO NOT** commit Korean/non-English UI strings (PetCut is English-only).

## HIGH

- **DO** use Conventional Commits format: `<type>: <subject>`
  - Types: `feat`, `fix`, `refactor`, `docs`, `chore`
  - Subject: English, 50 chars max, no trailing period.
  - Examples:
    - `feat: add pet profile screen for scan flow`
    - `fix: handle null Gemini response in analysis service`
    - `refactor: move toxicity thresholds to constants`
- **DO** run `dart format .` before committing.
- **DO** run `flutter analyze` and confirm 0 errors before committing.
- **DO** remove stray `print()` statements before committing (use `debugPrint` if needed).
- **DO** verify `.env` and service-account JSON files are not staged before committing.

## NORMAL

- **DO** target `main` branch for PRs.
- **DO** write PR descriptions in English, following the `/pr` workflow (What / Why / How / Test).
- **DO** reference related issue numbers when applicable.
