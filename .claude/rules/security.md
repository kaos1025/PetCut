---
description: PetCut 보안 규칙. 모든 코드 변경 시 적용.
globs: "lib/**/*.dart"
---

# Security Rules (PetCut)

## CRITICAL

- **DO NOT** hardcode any of the following in source code:
  - `GEMINI_API_KEY`, `GOOGLE_API_KEY`, `ANTHROPIC_API_KEY`
  - Firebase API keys, service account credentials
  - IAP product prices (`$1.99`, `1.99 USD`, etc.) — always render `ProductDetails.price` from Play Billing
  - Any tokens, passwords, or secrets
- **DO NOT** print, log, or share `.env` file contents (no `print(dotenv.env)`).
- **DO NOT** stage `.env`, `.env.*`, `*.secret`, `credentials.*`, `google-services.json` (if untracked), or service account JSON files for git commit.

## HIGH

- **DO** load secrets via `flutter_dotenv` (`dotenv.env['GEMINI_API_KEY']`) or secure platform storage.
- **DO** wrap every AI (Gemini / Claude) response parse in `try-catch` with safe defaults:
  ```dart
  (json['amount'] as num?)?.toDouble() ?? 0.0
  (json['warnings'] as List?)?.cast<String>() ?? const []
  ```
- **DO** fail closed: when analysis throws, render a user-facing error state instead of a partial/fabricated result.

## NORMAL

- **DO** verify `.gitignore` covers `.env*`, `android/key.properties`, keystore files, and Firebase service-account JSON before committing.
- **DO** strip PII from analytics events — pet names, owner names, and free-text notes must not leave the device without explicit user consent.
