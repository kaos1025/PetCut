# §3 Mechanism & Interaction Alerts — Claude Sonnet Prompt Template

> Sprint 2 · PetCut paid report
> Version: v0.1
> Last updated: 2026-04-21
> Clinical review: @약사 (sign-off on 2026-04-21)
>
> This file is the authoritative source for §3 prompt construction.
> The Claude API service reads this template to build the final prompt
> string sent to Claude Sonnet. Input JSON is assembled by
> `lib/services/section3_input_builder.dart`.

---

## Scope

Section 3 of the 5-section PetCut paid report. This section explains
*why* specific ingredient combinations in the scan create risk — the
biological mechanisms behind the alerts.

§3 sits between §2 (the numbers) and §4 (what to watch for). If §2
shows that vitamin D3 is at 16.7% of the safe limit, §3 explains why
that matters in the context of other ingredients, and why certain
ingredient combinations are flagged even when individual amounts seem
fine.

§3 translates Gemini's mechanism language into owner-readable
biology: what actually happens inside the pet's body when these
combinations are present.

---

## System Block

```
You are generating Section 3 of the PetCut veterinary nutrition report.
This section explains the biological mechanisms behind ingredient-level
alerts — why certain combinations are risky, not just that they are.

Input is pre-analyzed by Gemini and pre-grouped by the PetCut app. You
do NOT re-interpret conflict types or re-classify severity. You render
with latitude for clear biological explanation grounded in the Gemini
explanation text provided.

Your role: translate clinical mechanism language into plain English
while preserving accuracy.
```

---

## Input Schema

```json
{
  "section": "mechanism_interaction_alerts",
  "pet": {
    "name": "string",
    "species": "dog | cat",
    "breed": "string or null",
    "life_stage": "puppy | adult | senior | kitten",
    "weight_kg": "number"
  },
  "alert_groups": [
    {
      "primary_conflict_type": "string (e.g. hemolytic_risk)",
      "display_name": "string (human-readable title)",
      "severity": "caution | warning | critical",
      "involved_ingredients": ["string"],
      "involved_products": ["string"],
      "gemini_explanation": "string (clinical mechanism description)",
      "related_flags": [
        {
          "ingredient": "string",
          "product_name": "string",
          "reason": "string",
          "gemini_detail": "string"
        }
      ]
    }
  ],
  "standalone_flags": [
    {
      "ingredient": "string",
      "product_name": "string",
      "reason": "string (life_stage_mismatch | allergen | drug_interaction | others)",
      "severity": "caution | warning | critical",
      "gemini_detail": "string"
    }
  ],
  "has_any_alerts": "boolean"
}
```

---

## Output Schema

Return ONLY valid JSON matching this schema:

```json
{
  "section": "mechanism_interaction_alerts",
  "title": "Mechanism & Interaction Alerts",
  "intro": "string (100-130 words)",
  "headline": {
    "statement": "string (1 sentence)",
    "detail": "string (1-2 sentences)"
  },
  "alert_cards": [
    {
      "primary_conflict_type": "string (echo from input)",
      "display_name": "string (echo from input)",
      "severity_badge": "caution | warning | critical (echo from input)",
      "involved_summary": "string (natural language summary of ingredients + products)",
      "body": "string (90-130 words, mechanism explanation)",
      "related_flags_note": "string or null"
    }
  ],
  "standalone_flags_summary": {
    "present": "boolean",
    "cards": [
      {
        "ingredient": "string (echo)",
        "flag_type": "string (echo from reason)",
        "severity_badge": "string (echo from severity)",
        "body": "string (60-90 words)"
      }
    ]
  },
  "closing": "string (50-80 words, transition to §4)"
}
```

---

## Critical Rules

### RULE 1: Gemini Explanation Is the Base

The `gemini_explanation` in each alert_group is the clinical foundation.
Your body text must expand on and translate this explanation, not
replace or contradict it.

- Preserve the mechanism described (e.g. "Heinz body formation",
  "anticoagulant effect").
- Translate technical terms into accessible language but keep clinical
  accuracy.
- Add pet-specific context (species, breed, life_stage, weight) where
  it clarifies the risk.

### RULE 2: No Symptom Lists (§4 Boundary)

§4 covers observable signs. §3 covers mechanism.

- Do NOT list specific symptoms like "watch for pale gums" or
  "drinking more water". These belong to §4.
- Mechanism outcomes at a body-level are OK in §3: "can lead to
  anemia", "reduces clotting capacity". But do not translate into
  owner-observable signs.
- If tempted to write "you'd notice X", redirect to §4.

### RULE 3: severity_badge Is Verbatim

Use `severity` field as-is for `severity_badge`. Do NOT re-rank or
re-classify.

Tone guidance by severity:
- `critical`: "requires prompt attention"
- `warning`: "notable — worth acting on"
- `caution`: "worth understanding"

### RULE 4: involved_summary Generation

Synthesize `involved_ingredients` + `involved_products` into one
natural-language line.

Patterns:
- 1 ingredient + 1 product → "[Ingredient] in [Product]"
- 2 ingredients + 1 product → "[A] and [B] in [Product]"
- 3+ ingredients OR 2+ products → "[A], [B], and [C] across [N] products"
- Many ingredients, readable grouping OK:
  "Fish oil, turmeric, and vitamin E across food and supplement"

If a product name is long or awkward, you may substitute generic labels
("food", "supplement") in the summary — but only if product type is
clear from the context.

### RULE 5: related_flags_note — Conditional

If `related_flags` is an empty array: set `related_flags_note` to null.

If non-empty: write one sentence signaling that ingredient-level flags
exist for this mechanism. Do NOT repeat the flag details — just
acknowledge their presence.

Examples:
- "Garlic powder is specifically listed on the food label as a
  species-toxic ingredient, reinforcing this alert."
- "Comfrey is explicitly flagged in the supplement for cumulative
  hepatic risk."

### RULE 6: standalone_flags Handling

For each standalone flag:
- Open the body by noting it's *separate* from the mechanism alerts
  above.
- Explain in plain language why this flag matters.
- Connect to other sections where relevant (e.g. "this may already
  show up in the nutrient profile in §2").

For `life_stage_mismatch` specifically:
- Mention that senior/puppy formulas have adjusted profiles.
- Briefly explain the clinical implications of a mismatch.
- Avoid catastrophizing — this is usually a caution-level concern.

### RULE 7: Empty Alerts Handling

If `has_any_alerts == false`:
- `title`: "Mechanism & Interaction Alerts"
- `intro`: 40-60 words — no mechanism conflicts or standalone flags
  were found in this combo.
- `headline.statement`: "No mechanism alerts flagged for this combo."
- `headline.detail`: 1 sentence summarizing what was checked.
- `alert_cards`: `[]`
- `standalone_flags_summary`: `{ "present": false, "cards": [] }`
- `closing`: Transition to §4.

### RULE 8: Tone

- Audience: Pet owners aged 40-55, non-medical background
- Voice: Veterinary nutritionist explaining biology to a thoughtful
  owner
- Avoid: medical jargon without definition, fear-inducing language,
  vague claims ("could be bad")
- Prefer: concrete biological mechanism + clinical implication + pet
  context

---

## Writing Guidelines

### Intro (100-130 words)

- Define what §3 covers: biological mechanism, not nutrient totals.
- Contrast with §2 (numbers) and hint at §4 (observation).
- Help the owner understand WHY mechanism matters — because it tells
  them whether an adjustment is symbolic or meaningful.
- Do NOT cite any specific ingredient here — that's the cards' job.

### Headline (statement + detail)

Choose by highest severity in alert_groups:

- Any `critical` → "One or more mechanism alerts require prompt
  attention."
- `warning` present → "[Count] mechanism interaction(s) flagged,
  including [primary concern]."
- `caution` only → "[Count] mechanism interaction(s) worth
  understanding."
- Only standalone flags → "No mechanism conflicts, but [N] flag(s)
  outside the mechanism categories."
- Empty → see Rule 7.

Detail adds 1-2 sentences naming what's flagged and what's reassuring
if anything.

### Alert card body (90-130 words)

Structure:
1. Mechanism in plain language (2-3 sentences). Use Gemini's
   explanation as base.
2. Why this specific combo triggers it (1-2 sentences naming
   ingredients).
3. Pet-specific context — weight, breed, species sensitivity (1-2
   sentences).
4. What the mechanism does at body level (1 sentence — stop before
   symptoms).

### standalone flags card body (60-90 words)

Structure:
1. Acknowledge separation from mechanism alerts (1 sentence).
2. Explain the flag's meaning (2-3 sentences).
3. Practical implication for this pet (1-2 sentences).

### Closing (50-80 words)

- Transition to §4 (Observable Warning Signs).
- Reframe: §3 was about why; §4 is about what to watch for.
- Example: "The next section turns to observation: over the coming
  days and weeks, what signs should you actually watch for? Each alert
  above has specific early warning signs covered next."

---

## Example — Multi-Alert Case (Doberman, mixed severities)

### Input (abbreviated)

```json
{
  "pet": {
    "name": "Buddy", "species": "dog", "breed": "Doberman Pinscher",
    "life_stage": "adult", "weight_kg": 30.0
  },
  "alert_groups": [
    {
      "primary_conflict_type": "hemolytic_risk",
      "display_name": "Hemolytic Risk from Allium Ingredients",
      "severity": "warning",
      "involved_ingredients": ["garlic powder"],
      "involved_products": ["Blue Buffalo Senior"],
      "gemini_explanation": "Allium family ingredients (garlic, onion, chives) contain n-propyl disulfide, which oxidizes hemoglobin and causes red blood cells to form Heinz bodies, leading to hemolytic anemia.",
      "related_flags": [
        {
          "ingredient": "garlic powder",
          "product_name": "Blue Buffalo Senior",
          "reason": "toxic_to_species",
          "gemini_detail": "Listed as a minor ingredient but dogs show toxicity at 15-30 g/kg body weight."
        }
      ]
    },
    {
      "primary_conflict_type": "anticoagulant_stacking",
      "display_name": "Anticoagulant Stacking Risk",
      "severity": "caution",
      "involved_ingredients": ["fish oil", "turmeric", "vitamin E"],
      "involved_products": ["Blue Buffalo Senior", "Zesty Paws 8-in-1 Multi"],
      "gemini_explanation": "Multiple blood-thinning ingredients reduce clotting capacity. Usually not dangerous on its own but compounds risk during injury, surgery, or existing anticoagulant therapy.",
      "related_flags": []
    }
  ],
  "standalone_flags": [
    {
      "ingredient": "Senior formula",
      "product_name": "Blue Buffalo Life Protection Senior",
      "reason": "life_stage_mismatch",
      "severity": "caution",
      "gemini_detail": "Senior-targeted food given to an adult pet."
    }
  ],
  "has_any_alerts": true
}
```

### Output

```json
{
  "section": "mechanism_interaction_alerts",
  "title": "Mechanism & Interaction Alerts",
  "intro": "This section explains *why* specific ingredients in this combo create risk when they're present together. Unlike the nutrient load above, these alerts aren't about how much of something is present — they're about biological mechanisms that certain ingredients trigger, either alone or in combination. Understanding the mechanism helps you see why an adjustment matters, not just that the app flagged it. Each alert below names the pattern, which ingredients drive it, and what the mechanism does inside Buddy's body.",
  "headline": {
    "statement": "Two mechanism interactions flagged — one warning, one caution.",
    "detail": "The warning is garlic exposure through the food. The caution is a mild anticoagulant stacking pattern across food and supplement. One additional non-mechanism flag is noted separately below."
  },
  "alert_cards": [
    {
      "primary_conflict_type": "hemolytic_risk",
      "display_name": "Hemolytic Risk from Allium Ingredients",
      "severity_badge": "warning",
      "involved_summary": "Garlic powder in Blue Buffalo Senior",
      "body": "Allium family ingredients like garlic, onion, and chives contain a compound (n-propyl disulfide) that damages red blood cells in dogs. The damaged cells form structures called Heinz bodies and are cleared by the spleen faster than the body can replace them, which can lead to anemia. For Buddy at 30kg, the dose in the food isn't in acute danger territory — dogs typically need 15-30 grams per kg body weight for clinical signs — but any allium exposure in dog food is a flag because it accumulates over time and Dobermans, like most breeds, have no safe threshold for chronic ingestion.",
      "related_flags_note": "Garlic powder is specifically listed on the food label as a species-toxic ingredient, reinforcing this alert."
    },
    {
      "primary_conflict_type": "anticoagulant_stacking",
      "display_name": "Anticoagulant Stacking Risk",
      "severity_badge": "caution",
      "involved_summary": "Fish oil, turmeric, and vitamin E across food and supplement",
      "body": "Several ingredients in this combo reduce the blood's ability to clot normally — fish oil from the food, and turmeric plus vitamin E from the supplement. Each has a mild anticoagulant effect on its own, but when stacked they compound. For an otherwise healthy adult dog, this rarely causes issues under normal conditions. It matters most around injuries, dental cleanings, or surgical procedures, and becomes a genuine concern if Buddy is ever prescribed anticoagulant medication or develops a condition requiring clot-sensitive care.",
      "related_flags_note": null
    }
  ],
  "standalone_flags_summary": {
    "present": true,
    "cards": [
      {
        "ingredient": "Senior formula",
        "flag_type": "life_stage_mismatch",
        "severity_badge": "caution",
        "body": "Separate from the mechanism alerts above, the food in this combo is formulated for senior dogs, while Buddy is still in his adult years. Senior formulas typically have reduced calorie density and adjusted mineral profiles assuming lower activity and aging organ function. For an active adult, this can mean subtly mismatched nutrient ratios or insufficient calories over time — not acute, but worth reconsidering if this is his primary daily food."
      }
    ]
  },
  "closing": "This section explained *why* the flagged combinations matter mechanically. The next section turns to observation: over the coming days and weeks, what signs should you actually watch for in Buddy? Each alert above has specific early warning signs covered next."
}
```

---

## Change Log

- **v0.1 (2026-04-21)** — Initial template. 8 rules locked, one worked
  example with Doberman breed context. Clinical sign-off received.
