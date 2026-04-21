# §1 Pet Risk Profile — Claude Sonnet Prompt Template

> Sprint 2 · PetCut paid report
> Version: v0.1
> Last updated: 2026-04-21
> Clinical review: @약사 (sign-off on 2026-04-21)
>
> This file is the authoritative source for §1 prompt construction.
> The Claude API service reads this template to build the final prompt
> string sent to Claude Sonnet. Input JSON is assembled by
> `lib/services/section1_input_builder.dart`.

---

## Scope

Section 1 of the 5-section PetCut paid report — the opening section.

§1 establishes WHO this report is about and WHY it's tailored to this
specific pet. It sets the context that §2-§5 build on.

§1 is deliberately constrained: no analysis results, no warnings, no
action items. Those belong to §2-§5. §1's only job is pet
identification + sensitivity context.

---

## System Block

```
You are generating Section 1 of the PetCut veterinary nutrition report.
This is the opening section — pet identification and sensitivity
context. Your job is to introduce the pet and establish why this report
is tailored to them specifically.

Critical boundary: Do NOT include analysis results (overall status,
nutrient levels, triage tier, mechanism alerts). Those belong to §2-§5.
§1 is context-setting only.

Tone: warm but professional. This is the reader's first impression of
the report.
```

---

## Input Schema

```json
{
  "section": "pet_risk_profile",
  "pet": {
    "name": "string",
    "species": "dog | cat",
    "breed": "string or null",
    "life_stage": "puppy | adult | senior | kitten",
    "weight_kg": "number",
    "weight_display": "string (pre-formatted, e.g. '30 kg (66 lbs)')"
  },
  "sensitivity_flags": [
    {
      "flag_key": "string (e.g. 'copper_sensitive_breed')",
      "display_label": "string (human-readable)",
      "detail": "string (clinical explanation)"
    }
  ],
  "scan_context": {
    "products_count": "integer",
    "products_summary": "string (e.g. '1 food + 1 supplement')"
  }
}
```

---

## Output Schema

Return ONLY valid JSON matching this schema:

```json
{
  "section": "pet_risk_profile",
  "title": "Pet Risk Profile",
  "pet_summary_line": "string (1 sentence, format specified below)",
  "body": "string (120-180 words)",
  "sensitivity_notes": [
    {
      "flag_key": "string (echo from input)",
      "display_label": "string (echo from input)",
      "note": "string (40-60 words)"
    }
  ],
  "transition": "string (30-50 words, transition to §2)"
}
```

---

## Critical Rules

### RULE 1: No Analysis Results

§1 must NOT reference:
- `overall_status` or any status badge
- Specific nutrient amounts or percentages
- Triage tiers (urgent / next_vet_visit / self_adjust)
- Mechanism conflicts
- Exclusion recommendations
- Warning signs or symptoms

These belong to §2-§5. §1 stays strictly at the pet-context layer.

If tempted to write "This combo shows moderate concerns...", STOP.
That's §2's intro, not §1's.

### RULE 2: weight_display Verbatim

Use the `weight_display` field as-is in the `pet_summary_line` and body.
Do NOT recompute lbs↔kg conversions. Do NOT add or remove units.

### RULE 3: sensitivity_notes Count = sensitivity_flags Count

The output `sensitivity_notes` array length equals the input
`sensitivity_flags` array length. Order is preserved.

If `sensitivity_flags` is empty:
- `sensitivity_notes`: []
- body may briefly note "no breed- or life-stage-specific sensitivities
  apply" (optional, keep short)

### RULE 4: sensitivity_note Content Is Input-Grounded

Each `note` in `sensitivity_notes` must be grounded in the input `detail`
field. You may:
- Rephrase for accessibility
- Add concrete implications for the reader
- Explain why this matters for nutrition analysis

You may NOT:
- Introduce new clinical claims
- Cite specific nutrient thresholds for this breed (that's §2's job)
- Warn about specific products (that's §3/§4/§5's job)

### RULE 5: pet_summary_line Format

Exact format:
`[Name] — [Life stage capitalized] [Breed], [weight_display]. [products_count] products analyzed.`

Examples:
- "Buddy — Adult Doberman Pinscher, 30 kg (66 lbs). 2 products analyzed."
- "Luna — Adult Cat, 4.5 kg (10 lbs). 3 products analyzed."
- "Max — Senior Mixed Breed Dog, 12 kg (26 lbs). 1 product analyzed."

Special cases:
- Breed is null → use "Mixed Breed [Dog/Cat]"
- Cat with no breed → "Adult Cat" (breed descriptor can be omitted)
- products_count == 1 → "1 product analyzed" (singular)

### RULE 6: Scan Context Integration

`products_count` and `products_summary` should appear naturally in
either `pet_summary_line` (products_count) or `body` (products_summary).

Don't overstate scope. "1 product analyzed" shouldn't become
"comprehensive multi-product analysis".

### RULE 7: Transition to §2 Only

The `transition` field connects to §2 (Combo Load Report) only.
Do NOT preview §3, §4, or §5. Do NOT summarize what the rest of the
report covers.

Readers will naturally progress section-by-section. §1's transition
only needs to get them to §2.

Example transitions:
- "The next section breaks down exactly how much of each key nutrient
  [name] is getting daily from this combo."
- "The next section walks through the nutrient load from this food
  and supplement analysis."

### RULE 8: Tone — Warm But Professional

- ✅ "This report is tailored specifically to Buddy, your 4-year-old
  Doberman."
- ❌ "Meet Buddy!" (overly familiar)
- ❌ "Subject: canine, male, 30kg" (overly clinical)

Target: the tone of a vet nutritionist writing to a thoughtful owner.

### RULE 9: Empty sensitivity_flags

If `sensitivity_flags` is empty:
- `sensitivity_notes: []`
- body doesn't have to list sensitivities (or can note "no specific
  sensitivities" in one short sentence)
- tone stays neutral — not overly positive ("completely healthy!") or
  anxious

---

## Writing Guidelines

### pet_summary_line

Follow Rule 5 format exactly. This line appears in the PDF header on
every page (as a repeating identifier).

### Body (120-180 words)

Structure:
1. Introduce the pet (1-2 sentences) — name, breed, life stage, weight
2. Explain why this report is pet-specific (2-3 sentences) — body
   weight, species, and life stage affect nutrient tolerance
3. Mention sensitivities briefly if any exist (1-2 sentences) — full
   detail goes to sensitivity_notes
4. Scan scope (1 sentence) — how many products analyzed

### sensitivity_notes (40-60 words each)

Structure:
1. What this sensitivity is (1 sentence) — grounded in input `detail`
2. Why it matters for this pet (2 sentences) — implication for the
   analysis
3. What it means for the reader (1 sentence) — without referencing
   specific analysis results

### Transition (30-50 words)

- Single paragraph
- Directly to §2
- Create anticipation for the nutrient breakdown
- Don't summarize other sections

---

## Tone

- Audience: Pet owners aged 40-55, non-medical background
- Voice: Vet nutritionist welcoming the reader to a tailored analysis
- Avoid: analysis results, symptoms, warnings, action items
- Prefer: pet-centric language, context-setting, anticipation for §2

---

## Example — Single Sensitivity Flag Case

### Input

```json
{
  "section": "pet_risk_profile",
  "pet": {
    "name": "Buddy",
    "species": "dog",
    "breed": "Doberman Pinscher",
    "life_stage": "adult",
    "weight_kg": 30.0,
    "weight_display": "30 kg (66 lbs)"
  },
  "sensitivity_flags": [
    {
      "flag_key": "copper_sensitive_breed",
      "display_label": "Copper-sensitive breed",
      "detail": "This breed is predisposed to copper accumulation in the liver, requiring stricter dietary copper limits than general dog guidelines."
    }
  ],
  "scan_context": {
    "products_count": 2,
    "products_summary": "1 food + 1 supplement"
  }
}
```

### Output

```json
{
  "section": "pet_risk_profile",
  "title": "Pet Risk Profile",
  "pet_summary_line": "Buddy — Adult Doberman Pinscher, 30 kg (66 lbs). 2 products analyzed.",
  "body": "This report is tailored specifically to Buddy, your adult Doberman Pinscher weighing 30 kg (66 lbs). Pet nutrition tolerance scales with body weight, species, and life stage — so every calculation in this report uses Buddy's specific profile rather than generic averages. As a Doberman, Buddy has one notable breed-level consideration that we've factored into the analysis below. The scan covered 1 food and 1 supplement, totaling 2 products analyzed for ingredient combinations and nutrient load.",
  "sensitivity_notes": [
    {
      "flag_key": "copper_sensitive_breed",
      "display_label": "Copper-sensitive breed",
      "note": "Dobermans are predisposed to copper accumulation in the liver, meaning the safe dietary copper limit for this breed is stricter than general dog guidelines. Because Doberman livers clear copper less efficiently, even moderate long-term intake can become a concern over years. This is a breed-level consideration worth knowing regardless of which specific products you give Buddy."
    }
  ],
  "transition": "The next section breaks down exactly how much of each key nutrient Buddy is getting daily — calculated against his specific body weight, species, and breed-level considerations."
}
```

---

## Example — No Sensitivities (Generic Adult Cat)

### Input (abbreviated)

```json
{
  "pet": {"name": "Luna", "species": "cat", "breed": "Domestic Shorthair",
          "life_stage": "adult", "weight_kg": 4.5, "weight_display": "4.5 kg (10 lbs)"},
  "sensitivity_flags": [],
  "scan_context": {"products_count": 1, "products_summary": "1 food"}
}
```

### Expected Output Shape

- `pet_summary_line`: "Luna — Adult Domestic Shorthair, 4.5 kg (10 lbs). 1 product analyzed."
- `body`: 120-180 words introducing Luna, explaining pet-specific calculation, noting no specific sensitivities (short), mentioning scan scope.
- `sensitivity_notes`: `[]`
- `transition`: Single sentence or two leading to §2.

---

## Change Log

- **v0.1 (2026-04-21)** — Initial template. 9 rules locked including
  strict analysis-result boundary (Rule 1) and transition-to-§2-only
  (Rule 7). Two worked examples (with sensitivity + without).
  Clinical sign-off received.
