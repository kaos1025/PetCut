# PetCut

**AI Pet Food + Supplement Combo Analyzer**

Scan the labels of your pet's food and supplements, and PetCut's AI highlights ingredient overlap, overdoses, and mechanism conflicts — with warnings and exclusion recommendations tailored to your dog or cat.

> ⚠️ Not a substitute for professional veterinary advice.

---

## Target

- US pet owners aged 40–55
- Language: **English only** — Currency: **USD**

## Architecture Principle

**"Decisions by Gemini, Display by App"**

- Gemini Flash (free tier) produces the JSON decision; the app renders it.
- Claude Sonnet generates the paid ($1.99) explanatory report — no re-ranking.
- Prices are never hardcoded — rendered via Play Billing `formattedPrice`.

## Tech Stack

- **Flutter / Dart** (Android-first)
- State: `ChangeNotifier` + `Provider`
- DI: `get_it` (`lib/core/service_locator.dart`)
- AI: `google_generative_ai` (Gemini) + Claude (paid report)
- Billing: `in_app_purchase` (Play Billing)
- Env: `flutter_dotenv`
- PDF: `pdf` + `printing`
- Persistence: `shared_preferences`
- Other: `firebase_core`, `firebase_analytics`, `image_picker`, `uuid`

## Project Structure

```
lib/
├── config/         # App config
├── constants/      # Toxicity thresholds (D3, Iron, Ca, ...)
├── core/           # service_locator (get_it)
├── models/         # pet_profile, petcut_analysis_result
├── prompts/        # Gemini / Claude prompt strings
├── screens/        # UI screens
├── services/       # Gemini, Claude, IAP, PDF services
├── theme/          # App theme
├── utils/          # life_stage, daily_intake calculators
└── widgets/        # Shared widgets (traffic-light banners, cards)
```

## Setup

1. **Clone & install**
   ```bash
   flutter pub get
   ```

2. **Configure environment**

   Create a `.env` file in the project root:
   ```
   GEMINI_API_KEY=your_gemini_api_key_here
   ```

   > Never commit `.env` — it is in `.gitignore`.

3. **Run on Android**
   ```bash
   flutter emulators --launch Pixel_9    # or any Android device
   flutter run
   ```

## Development

### Quality checks
```bash
dart format .
flutter analyze    # must be 0 errors before commit
flutter test
```

### Slash commands (Claude Code)
- `/commit` — lint + security check + commit with suggested message
- `/push` — push current branch
- `/pr` — generate PR description (What / Why / How / Test)
- `/test` — run Flutter tests with expanded report
- `/review-cycle` — full pre-PR quality cycle

## MVP Scope

- Pet profile (species, weight, life stage)
- Label scan (food + supplement photos)
- Toxicity warnings (D3 chronic toxicity, Iron, etc.)
- Mechanism conflict detection
- Exclusion recommendations
- Paid AI report ($1.99, Play Billing)

### Out of MVP (v2)
Allergies • drug interactions • FDA recalls • alternative product recommendations

## Related

Sister product: [SuppleCut (yak-biseo)](https://github.com/kaos1025/yak-biseo_mvp) — human supplement analyzer sharing the same architecture.
