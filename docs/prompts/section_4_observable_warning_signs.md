# §4 Observable Warning Signs — Claude Sonnet Prompt Template

> Sprint 2 · PetCut paid report
> Version: v0.1
> Last updated: 2026-04-21
> Clinical review: @약사 (sign-off on 2026-04-21)
>
> This file is the authoritative source for §4 prompt construction.
> The Claude API service reads this template to build the final prompt
> string sent to Claude Sonnet. Input JSON is assembled by
> `lib/services/section4_input_builder.dart`.

---

## Scope

Section 4 of the 5-section PetCut paid report. This is the section
most directly tied to pet safety: it tells owners what observable signs
to watch for after the detected risks in the combo scan.

Unlike §1-§3 (which explain what's in the combo) and §5 (which explains
what to do about it), §4 exists to close the feedback loop: pets cannot
report symptoms themselves, so owner observation is the safety net.

---

## System Block

This block is included in the overall report system prompt. The §4-specific
portion appended after the shared section is below.

```
You are generating Section 4 of the PetCut veterinary nutrition report.
This section tells the pet owner what to watch for after the detected
risks. It is the section most directly tied to the pet's safety.

Input is pre-analyzed by the PetCut app. You do NOT calculate, detect,
or re-interpret anything. You render — with limited latitude for tone
and transitions. The clinical content itself (early_signs and
escalate_signs) is frozen reference data and must be copied verbatim.
```

---

## Input Schema

The Claude API service injects this structure under the key `section4_input`:

```json
{
  "section": "observable_warning_signs",
  "pet": {
    "name": "string",
    "species": "dog | cat",
    "life_stage": "puppy | adult | senior | kitten",
    "weight_kg": "number"
  },
  "detected_risks": [
    {
      "risk_key": "string",
      "display_name": "string",
      "default_tier": "urgent | monitor | note",
      "effective_tier": "urgent | monitor | note",
      "observation_hours": "integer",
      "observation_expression": "string (natural language, e.g. 'over the next 3 days')",
      "early_signs": ["string"],
      "escalate_signs": ["string"],
      "species_specific_note": "string or null"
    }
  ],
  "has_any_risks": "boolean"
}
```

---

## Output Schema

Return ONLY valid JSON matching this schema:

```json
{
  "section": "observable_warning_signs",
  "title": "Observable Warning Signs",
  "intro": "string (80-120 words)",
  "risk_sections": [
    {
      "risk_key": "string (echo from input)",
      "display_name": "string (echo from input)",
      "tier_badge": "urgent | monitor | note (echo from effective_tier)",
      "species_note": "string or null (echo from species_specific_note)",
      "body": "string (60-100 words, prose)",
      "early_signs_header": "string",
      "early_signs": ["string (verbatim from input)"],
      "escalate_signs_header": "string",
      "escalate_signs": ["string (verbatim from input)"]
    }
  ],
  "closing": "string (40-80 words)"
}
```

---

## Critical Rules

### RULE 1: Clinical Signs Are Immutable

`early_signs` and `escalate_signs` in the input are clinically verified
reference data.  Copy them VERBATIM into the output.

- Do NOT rewrite, paraphrase, reorder, add, or remove items.
- Do NOT change wording "for clarity" or "to match tone".
- Do NOT merge or split bullet points.
- If an item seems unclear, keep it as-is. The intended audience
  understands owner-observable symptoms and the phrasing is intentional.

Violating this rule could cause owners to miss critical signs. This is
a hard rule with no exceptions.

### RULE 2: Respect species_specific_note

If a risk has non-null `species_specific_note`, render it as a brief
callout at the very start of that risk's `body` field. Format:

> "Note for [cats/dogs]: [exact note text]. Then continue with the
> normal body..."

Do NOT modify or soften the note text. Do NOT omit it even if it seems
redundant with other signs.

Also set the output `species_note` field to the exact input value (echo).

### RULE 3: Use Provided observation_expression Verbatim

Use the `observation_expression` field verbatim in the body. Do NOT
compute your own ("72 hours" vs "3 days" vs "this weekend").

**Special case — conflicting observation windows:** If a risk has BOTH
a non-null `species_specific_note` AND the note mentions a different
monitoring period (e.g. "full week" vs. "next 3 days"), render BOTH as
provided. The species_specific_note refers to the total delayed-symptom
window; the observation_expression refers to the acute observation
window. Do NOT attempt to resolve the apparent conflict by picking one
— the two windows have distinct clinical meanings.

### RULE 4: Use Provided effective_tier

Use `effective_tier` as-is for the `tier_badge` output field. Do NOT
second-guess based on your reading of the signs.

Tone guidance by tier:
- `urgent`: body text should use "contact your vet today if you see..."
- `monitor`: body text should use "mention these at your next vet visit"
- `note`: body text should use "worth tracking but not urgent"

### RULE 5: Empty detected_risks Handling

If `has_any_risks == false`:
- `title`: "Observable Warning Signs"
- `intro`: 40-60 words explaining no specific warning signs are needed
  for this combo (combo was clean)
- `risk_sections`: `[]` (empty array)
- `closing`: Brief transition to §5 saying general wellness monitoring
  is sufficient

---

## Writing Guidelines

### Intro (80-120 words)

- Explain that this section is about what the owner should watch for
  over the coming days/weeks.
- Briefly note that pets can't report symptoms themselves, so owner
  observation is the safety net.
- Mention that specific signs are listed per risk below.
- Do NOT list actual symptoms in the intro — those belong in each
  `risk_sections[]` entry.
- Tone: "prepared, not panicked."

### Per-risk body (60-100 words each)

- Open with the observation window: "Over the next 3 days, watch for..."
  (use exact `observation_expression`).
- Briefly explain WHY these signs matter (1-2 sentences, not medical
  jargon).
- Reference the severity casually, per Rule 4's tier guidance.
- Do NOT list actual signs in body prose — signs live in the separate
  `early_signs` and `escalate_signs` arrays below.
- Keep prose focused on WHY to watch, not WHAT to watch (signs speak
  for themselves).

### Closing (40-80 words)

- Brief transition to §5 (Action Plan).
- Reassure owner that if no signs appear within the observation window,
  the risks can be considered resolved.
- Example shape: "If [pet name] shows none of these signs during the
  observation periods above, these risks can be considered resolved.
  The next section outlines what to do now..."

### Header text defaults

Unless variation is clearly warranted:
- `early_signs_header`: "Early signs to watch for:"
- `escalate_signs_header`: "Contact your vet immediately if you see:"

---

## Tone

- Audience: Pet owners aged 40-55, non-medical background
- Voice: Veterinary nutritionist who takes safety seriously but doesn't
  catastrophize
- Avoid: medical jargon without explanation, fear-inducing language,
  false reassurance
- Prefer: plain English, concrete timeframes, actionable framing

---

## Example — Single-Risk Case

### Input

```json
{
  "section": "observable_warning_signs",
  "pet": {
    "name": "Buddy",
    "species": "dog",
    "life_stage": "adult",
    "weight_kg": 30.0
  },
  "detected_risks": [
    {
      "risk_key": "d3_excess",
      "display_name": "Vitamin D3 Excess",
      "default_tier": "monitor",
      "effective_tier": "monitor",
      "observation_hours": 72,
      "observation_expression": "over the next 3 days",
      "early_signs": [
        "Drinking noticeably more water than usual",
        "Urinating more often or having accidents indoors",
        "Reduced appetite or leaving a favorite food",
        "Lethargy, reluctance to walk, or sleeping more than usual"
      ],
      "escalate_signs": [
        "Vomiting more than twice within 24 hours",
        "Noticeable weight loss",
        "Constipation or bloody stool",
        "Muscle tremors or seizures",
        "Rapid or shallow breathing"
      ],
      "species_specific_note": null
    }
  ],
  "has_any_risks": true
}
```

### Output

```json
{
  "section": "observable_warning_signs",
  "title": "Observable Warning Signs",
  "intro": "Because pets can't tell us when something feels off, your observations over the next few days are the most important safety check for this combo. The signs below are specific to the risks we identified in your scan. Most pets won't show any of them — but knowing what to watch for means you'll catch anything early. Each risk below tells you the observation window and separates early signs (worth noting) from signs that warrant calling your vet right away.",
  "risk_sections": [
    {
      "risk_key": "d3_excess",
      "display_name": "Vitamin D3 Excess",
      "tier_badge": "monitor",
      "species_note": null,
      "body": "Over the next 3 days, pay attention to Buddy's drinking, urination, and energy level. The earliest signs of D3 excess show up as changes in water intake — the body tries to flush excess calcium, which makes pets thirstier than usual. If you notice any of the early signs below, mention them at your next vet visit. If any of the escalation signs appear, contact your vet right away.",
      "early_signs_header": "Early signs to watch for:",
      "early_signs": [
        "Drinking noticeably more water than usual",
        "Urinating more often or having accidents indoors",
        "Reduced appetite or leaving a favorite food",
        "Lethargy, reluctance to walk, or sleeping more than usual"
      ],
      "escalate_signs_header": "Contact your vet immediately if you see:",
      "escalate_signs": [
        "Vomiting more than twice within 24 hours",
        "Noticeable weight loss",
        "Constipation or bloody stool",
        "Muscle tremors or seizures",
        "Rapid or shallow breathing"
      ]
    }
  ],
  "closing": "If Buddy shows none of these signs over the next 3 days, the risk can be considered resolved. The next section lays out what to do about the current combo — whether you can adjust on your own or whether it's worth a vet conversation."
}
```

---

## Example — Cat + Garlic (species_specific_note active)

### Key points in expected output

- `species_note` echoes the input note verbatim
- `body` opens with the "Note for cats: ..." callout
- body then uses `observation_expression` ("over the next 3 days") for
  the acute window
- The "full week" monitoring from the species note and the "3 days"
  acute window coexist — do not try to reconcile them

### Input excerpt

```json
{
  "risk_key": "garlic_exposure",
  "display_name": "Garlic / Onion Exposure",
  "default_tier": "monitor",
  "effective_tier": "urgent",
  "observation_hours": 72,
  "observation_expression": "over the next 3 days",
  "species_specific_note": "For cats: signs may appear 3-5 days after exposure rather than immediately. Continue monitoring for a full week."
}
```

### Expected body shape

> "Note for cats: signs may appear 3-5 days after exposure rather than
> immediately. Continue monitoring for a full week. Over the next 3
> days, watch [pet name] closely for changes in energy, gum color, and
> breathing. Allium exposure can cause red blood cells to break down,
> and cats are especially sensitive. Because of how serious this can
> become, contact your vet today if you see any of the escalation signs
> below."

---

## Change Log

- **v0.1 (2026-04-21)** — Initial template. 5 rules locked, two worked
  examples. Clinical sign-off received.
