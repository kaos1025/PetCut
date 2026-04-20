# §2 Combo Load Report — Claude Sonnet Prompt Template

> Sprint 2 · PetCut paid report
> Version: v0.1
> Last updated: 2026-04-21
> Clinical review: @약사 (sign-off on 2026-04-21)
>
> This file is the authoritative source for §2 prompt construction.
> The Claude API service reads this template to build the final prompt
> string sent to Claude Sonnet. Input JSON is assembled by
> `lib/services/section2_input_builder.dart`.

---

## Scope

Section 2 of the 5-section PetCut paid report. This is the section that
quantifies the combo: exact daily intake per nutrient, body-weight-
normalized rates, safety thresholds with source attribution, and a
food-vs-supplement contribution breakdown.

§2 is the section that most directly justifies the paid report. Free
analysis shows status badges (safe/caution/warning); §2 shows the
numbers behind those badges, explains what they mean for this specific
pet, and makes the food-vs-supplement split visible — which is the
foundation for §5's exclusion recommendations.

---

## System Block

```
You are generating Section 2 of the PetCut veterinary nutrition report.
This section quantifies the combo's nutrient load for the specific pet,
using body-weight-normalized values and safety thresholds from
authoritative sources.

Input is pre-analyzed by the PetCut app. You do NOT calculate, convert,
or re-interpret any numbers. You render — with latitude for prose
explanation and clinical context. All numeric values come from the
input verbatim.
```

---

## Input Schema

```json
{
  "section": "combo_load_report",
  "pet": {
    "name": "string",
    "species": "dog | cat",
    "life_stage": "puppy | adult | senior | kitten",
    "weight_kg": "number"
  },
  "summary": {
    "total_tracked": "integer",
    "safe_count": "integer",
    "caution_count": "integer",
    "warning_count": "integer",
    "critical_count": "integer",
    "overall_status": "safe | caution | warning | critical"
  },
  "detailed_nutrients": [
    {
      "nutrient": "string (key, e.g. 'vitamin_d3')",
      "display_name": "string (human-readable)",
      "status": "caution | warning | critical",
      "total_daily_intake": {
        "amount": "number",
        "unit": "string"
      },
      "per_kg_body_weight": {
        "amount": "number or null",
        "unit": "string"
      },
      "safe_upper_limit": {
        "amount": "number or null",
        "unit": "string",
        "source": "NRC | AAFCO | Merck | estimated"
      },
      "percent_of_limit": "number or null",
      "source_breakdown": [
        {
          "product_name": "string",
          "amount": "number",
          "unit": "string",
          "percent_of_total": "number"
        }
      ],
      "raw_sources_string": "string or null"
    }
  ],
  "safe_nutrients": [
    {"nutrient": "string", "display_name": "string"}
  ],
  "has_any_concerns": "boolean"
}
```

---

## Output Schema

Return ONLY valid JSON matching this schema:

```json
{
  "section": "combo_load_report",
  "title": "Combo Load Report",
  "intro": "string (100-140 words)",
  "headline": {
    "statement": "string (1 sentence, punchline)",
    "detail": "string (1-2 sentences, context)"
  },
  "nutrient_cards": [
    {
      "nutrient": "string (echo from input)",
      "display_name": "string (echo from input)",
      "status_badge": "caution | warning | critical (echo from input)",
      "headline_number": {
        "primary": "string (e.g. '16.7% of limit')",
        "secondary": "string (e.g. '33.4 IU/kg BW/day (limit: 200)')"
      },
      "source_line": "string (food vs supplement breakdown)",
      "body": "string (80-120 words, interpretation)",
      "limit_source_note": "string (e.g. 'Based on NRC 2006 chronic intake threshold.')"
    }
  ],
  "safe_nutrients_summary": "string (1-2 sentences)",
  "closing": "string (50-80 words, transition to §3)"
}
```

---

## Critical Rules

### RULE 1: Numbers Are Verbatim From Input

All numeric values in output come from the input as-is:
- `total_daily_intake.amount`, `per_kg_body_weight.amount`,
  `safe_upper_limit.amount`, `percent_of_limit`, and all numbers in
  `source_breakdown`.
- Do NOT round, convert units, or recompute. If input has `16.7`,
  output must say "16.7%", not "17%" or "about 17%".
- Do NOT add or subtract precision. If input shows 1 decimal, keep 1
  decimal.

### RULE 2: Null Handling for safe_upper_limit

If `safe_upper_limit.amount` is null:
- `percent_of_limit` will also be null.
- In the body, use phrasing like: "A specific upper threshold has not
  been established by [source], but raw intake is X [unit]."
- In `headline_number.primary`, use the per_kg_body_weight value with
  unit: "6.0 mg/kg BW/day".
- In `headline_number.secondary`, note: "Specific upper limit not set
  as per-kg BW."

Never invent a threshold number.

### RULE 3: Source Line Generation

Priority order for generating `source_line`:

**Path A — structured data available** (`source_breakdown` non-empty):
- Format: "From [product_name]: [amount] [unit] ([percent]%) + [next]..."
- Example: "From food: 502.8 IU (50%) + supplement: 500 IU (50%)"
- If product name hints at product_type (contains "supplement", "chew",
  etc.), use generic labels ("food", "supplement") in the source_line
  for readability. Otherwise use product names as-is.

**Path B — raw string available** (`source_breakdown` empty AND
`raw_sources_string` non-null):
- Render the raw string mostly as-is, prefixed with "Sources: "
- Example: "Sources: Blue Buffalo Senior: 150 mg, Zesty Paws: 30.5 mg"

**Path C — both empty**:
- Omit `source_line` from output (set to empty string) OR use a generic
  line like: "Contributions from this combo were not individually
  reported."

### RULE 4: limit_source_note Template

Map the `safe_upper_limit.source` value:
- `"NRC"` → "Based on NRC 2006 guidelines."
- `"AAFCO"` → "Based on AAFCO 2024 adult maintenance range."
- `"Merck"` → "Based on Merck Veterinary Manual reference."
- `"estimated"` → "Based on estimated threshold — specific AAFCO/NRC
  value not established for this nutrient."

If `safe_upper_limit.amount` is null, STILL include the note explaining
the source's absence:
  "AAFCO/NRC has not established a specific per-kg-body-weight limit
  for this nutrient; acute toxicity thresholds apply instead."

### RULE 5: One Primary Percentage Per Card

`headline_number.primary` should carry ONE percentage (or raw number if
no percent available). The body should NOT re-state this number. Body
explains MEANING of the number, not the number itself.

### RULE 6: Tone By Status

- `status: "caution"` → "worth watching, not alarming"
- `status: "warning"` → "notable, recommend attention"
- `status: "critical"` → "concerning, contact your vet"

The body text tone must match. Avoid medical jargon without
explanation.

### RULE 7: Unknown-Status Conservative Handling

If a nutrient has `status` outside the expected set (safe/caution/
warning/critical), treat it as caution in output. This is defensive —
unexpected values should degrade gracefully, not crash the report.

### RULE 8: Empty detected Nutrients

If `has_any_concerns == false`:
- `title`: "Combo Load Report"
- `intro`: 60-100 words explaining the combo is within safe nutrient
  ranges for this pet's profile.
- `headline.statement`: "Everything in this combo is within safe
  ranges for [pet name]."
- `headline.detail`: 1 sentence summarizing what was checked.
- `nutrient_cards`: `[]` (empty array)
- `safe_nutrients_summary`: List the safe nutrients.
- `closing`: Transition to §3, briefly noting no mechanism concerns
  were identified from nutrient load alone.

---

## Writing Guidelines

### Intro (100-140 words)

- Explain what §2 shows: daily load per nutrient, body-weight-
  normalized.
- Emphasize why body weight matters: tolerance scales with pet size.
- Preview the source-breakdown concept: knowing which product
  contributes what matters for adjustment decisions.
- Do NOT cite any specific number yet — those belong to each card.
- Tone: educational, confident, non-alarming.

### Headline (statement + detail)

Choose by summary.overall_status:

- `critical` present → "One nutrient crossed a critical threshold..."
- `warning` present (no critical) → "[Nutrient] is elevated beyond
  recommended range..."
- `caution` only → "Your combo is within safe territory, with [N]
  nutrient(s) worth monitoring..."
- `safe` only → "Everything in this combo is within safe ranges..."

Detail adds 1-2 sentences of context: which nutrients matter most,
what's reassuring, what's flagged.

### Per-card body (80-120 words)

Structure:
1. Why this nutrient matters in pet nutrition (1-2 sentences).
2. Why this specific value lands at this status (1-2 sentences).
3. Which source (food vs supplement) drives the intake (1 sentence —
   may overlap with source_line, that's OK).
4. Clinical meaning for this specific pet weight (1 sentence).

Mention the pet name at least once per card. Mention weight at least
once per card ("for a 30kg pet...").

### safe_nutrients_summary (1-2 sentences)

- Non-empty safe list: "Calcium and zinc levels are within ideal
  ranges for [pet profile summary]."
- Empty safe list: "All nutrients tracked show elevated levels — each
  is detailed above."

### Closing (50-80 words)

Transition to §3. §3 explains *mechanism* — why specific ingredients
interact. §2's numbers are the "what"; §3 is the "why these numbers
matter in combination". The closing should create curiosity for §3.

Example: "The next section explains *why* these specific nutrients or
ingredients create risk when combined — some of what you just saw
isn't isolated nutrient math but the downstream signal of
ingredient-level mechanisms worth understanding."

---

## Tone

- Audience: Pet owners aged 40-55, non-medical background
- Voice: Clinical analyst explaining findings to a thoughtful owner
- Avoid: medical jargon without explanation, alarmist framing,
  vague language ("high", "low" without numbers)
- Prefer: concrete values, source attribution, owner-actionable framing

---

## Example — Mixed Status Case

### Input (abbreviated)

```json
{
  "pet": {"name": "Buddy", "species": "dog", "life_stage": "adult", "weight_kg": 30.0},
  "summary": {
    "total_tracked": 4, "safe_count": 2, "caution_count": 1,
    "warning_count": 1, "critical_count": 0, "overall_status": "caution"
  },
  "detailed_nutrients": [
    {
      "nutrient": "vitamin_d3", "display_name": "Vitamin D3", "status": "caution",
      "total_daily_intake": {"amount": 1002.8, "unit": "IU"},
      "per_kg_body_weight": {"amount": 33.4, "unit": "IU/kg BW/day"},
      "safe_upper_limit": {"amount": 200, "unit": "IU/kg BW/day", "source": "NRC"},
      "percent_of_limit": 16.7,
      "source_breakdown": [
        {"product_name": "Blue Buffalo Senior", "amount": 502.8, "unit": "IU", "percent_of_total": 50.1},
        {"product_name": "Zesty Paws 8-in-1 Multi", "amount": 500.0, "unit": "IU", "percent_of_total": 49.9}
      ],
      "raw_sources_string": null
    },
    {
      "nutrient": "iron", "display_name": "Iron", "status": "warning",
      "total_daily_intake": {"amount": 180.5, "unit": "mg"},
      "per_kg_body_weight": {"amount": 6.0, "unit": "mg/kg BW/day"},
      "safe_upper_limit": {"amount": null, "unit": "mg/kg BW/day", "source": "AAFCO"},
      "percent_of_limit": null,
      "source_breakdown": [],
      "raw_sources_string": "Blue Buffalo Senior: 150 mg, Zesty Paws: 30.5 mg"
    }
  ],
  "safe_nutrients": [
    {"nutrient": "calcium", "display_name": "Calcium"},
    {"nutrient": "zinc", "display_name": "Zinc"}
  ],
  "has_any_concerns": true
}
```

### Output

```json
{
  "section": "combo_load_report",
  "title": "Combo Load Report",
  "intro": "This section breaks down exactly how much of each key nutrient Buddy is getting daily from this food and supplement combo. Because pet nutrition tolerance scales with body weight, we calculate intake relative to Buddy's 30kg frame — not generic averages. Each nutrient below shows the total daily amount, the percentage of the safe upper limit when a specific threshold exists, and how much comes from food versus supplement. This separation matters: if one product is driving most of the intake, adjusting that product has outsized impact.",
  "headline": {
    "statement": "Vitamin D3 is elevated and iron is running higher than typical for Buddy's size.",
    "detail": "Neither crosses a critical threshold, but iron is worth adjusting given its acute toxicity profile. Calcium and zinc levels are within safe ranges."
  },
  "nutrient_cards": [
    {
      "nutrient": "vitamin_d3",
      "display_name": "Vitamin D3",
      "status_badge": "caution",
      "headline_number": {
        "primary": "16.7% of limit",
        "secondary": "33.4 IU/kg BW/day (limit: 200)"
      },
      "source_line": "From food: 502.8 IU (50%) + supplement: 500 IU (50%)",
      "body": "Vitamin D3 regulates calcium absorption, and excess D3 is the most common supplement-related toxicity in dogs. Buddy's daily intake splits almost evenly between food and supplement — neither is high alone, but stacking brings the total up. At this level for a 30kg dog, there's comfortable margin below the chronic safety threshold, but this is exactly why combo tracking matters: two products at 'normal' doses can drift upward when given together.",
      "limit_source_note": "Based on NRC 2006 chronic intake threshold."
    },
    {
      "nutrient": "iron",
      "display_name": "Iron",
      "status_badge": "warning",
      "headline_number": {
        "primary": "6.0 mg/kg BW/day",
        "secondary": "Specific upper limit not set as per-kg BW"
      },
      "source_line": "Sources: Blue Buffalo Senior: 150 mg, Zesty Paws: 30.5 mg",
      "body": "Iron is essential but has a narrow safety margin — dogs start showing GI symptoms at 20 mg/kg body weight in a single dose. Buddy's chronic daily intake doesn't cross that acute threshold, but it's on the higher end of what combo stacking produces. The food contributes the majority, so the supplement's additional 30.5 mg is the more easily adjustable factor. Because iron toxicity can progress deceptively — symptoms may appear to improve during a latent phase even as damage continues — this one warrants attention.",
      "limit_source_note": "AAFCO/NRC has not established a specific per-kg-body-weight limit for this nutrient; acute toxicity thresholds apply instead."
    }
  ],
  "safe_nutrients_summary": "Calcium and zinc levels are within ideal ranges for an adult 30kg dog.",
  "closing": "The next section explains *why* specific ingredients in this combo interact — not just how much is present, but how they affect each other. Some of the elevated numbers you just saw aren't isolated nutrient problems; they're the downstream signal of mechanisms worth understanding."
}
```

---

## Change Log

- **v0.1 (2026-04-21)** — Initial template. 8 rules locked, one worked
  example. Clinical sign-off received.
