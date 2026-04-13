# PetCut 데이터 모델 & 독성 계산 로직

> 작성일: 2026-04-02
> 용도: SuppleCut 프로덕션 전 병렬 설계 작업
> 상태: 초안 v0.2 (약사 검증 반영)
> 변경 이력:
>   v0.1 (04/02) — @Tech 초안
>   v0.2 (04/02) — @약사 검증 8건 반영
>     🔴 D3 만성 vs 급성 구분 추가 (chronic_toxic 필드)
>     🔴 Iron 이원 판단 체계 (diet-based + acute)
>     🔴 대형견 강아지 칼슘 >1.2% caution 구간 추가
>     🟡 Puppy MER multiplier 월령 세분화 주석
>     🟡 간독성 조합(hepatotoxic_combo) 기전 충돌 추가
>     🟡 구리 민감 품종 3개 추가 (Dalmatian, Skye Terrier, Cocker Spaniel)
>     🟢 D3 AAFCO vs NRC 출처 분리 (고양이 max 보정)
>     🟢 Xylitol 고양이 → "insufficient data, flag as caution"

---

## 1. 펫 프로필 데이터 모델

### 1.1 Core Schema (Dart-style)

```
PetProfile {
  id: String (UUID)
  name: String                    // "Buddy", "Mochi"
  species: Species                // dog | cat
  breed: String?                  // nullable — 믹스견/묘 허용
  weight: double                  // 숫자만 저장
  weightUnit: WeightUnit          // kg | lbs (내부 계산은 항상 kg)
  weightKg: double                // computed: lbs면 자동 변환
  birthDate: DateTime?            // nullable — 나이 직접 입력도 허용
  ageYears: double?               // birthDate 없으면 수동 입력
  lifeStage: LifeStage            // computed from age + species
  isNeutered: bool?               // nullable — 칼로리 계산에 영향 (v2)
  knownAllergies: List<String>    // 사용자 직접 입력 (v2)
  currentMedications: List<String> // 약물-보충제 상호작용용 (v2)
  createdAt: DateTime
  updatedAt: DateTime
}
```

### 1.2 Enums

```
Species { dog, cat }

WeightUnit { kg, lbs }

LifeStage {
  // Dogs
  puppy,        // < 1 year (소형견) / < 2 years (대형견)
  adult,        // 1~7 years (소형견) / 2~5 years (대형견)  
  senior,       // 7+ (소형견) / 5+ (대형견)
  
  // Cats
  kitten,       // < 1 year
  adultCat,     // 1~10 years
  seniorCat     // 10+ years
}
```

### 1.3 LifeStage 자동 계산 로직

```
getLifeStage(species, ageYears, weightKg):
  if species == cat:
    if ageYears < 1    → kitten
    if ageYears < 10   → adultCat
    else                → seniorCat
  
  if species == dog:
    // 대형견 기준: 25kg 이상
    isLargeBreed = weightKg >= 25
    
    if isLargeBreed:
      if ageYears < 2  → puppy
      if ageYears < 5  → adult
      else              → senior
    else:
      if ageYears < 1  → puppy
      if ageYears < 7  → adult
      else              → senior
```

### 1.4 MVP vs v2 필드 구분

| 필드 | MVP (v1) | v2 | 비고 |
|------|:--------:|:--:|------|
| name | ✅ | | |
| species | ✅ | | dog/cat 선택 |
| breed | ✅ | | 텍스트 입력 (자동완성 v2) |
| weight + unit | ✅ | | kg/lbs 토글 |
| age (years) | ✅ | | 숫자 입력 |
| lifeStage | ✅ | | 자동 계산 (편집 가능) |
| isNeutered | | ✅ | 칼로리 가이드라인 |
| knownAllergies | | ✅ | 커스텀 알레르겐 |
| currentMedications | | ✅ | 약물 상호작용 |
| profilePhoto | | ✅ | 펫 사진 (감성) |

---

## 2. 체중별 독성 역치 계산 로직 (의사코드)

### 2.1 독성 역치 기준표

```
TOXICITY_THRESHOLDS = {
  // 출처: Merck Veterinary Manual, NRC 2006, ASPCA, AAFCO 2024
  
  // ==========================================
  // 체중 기준 독성 (mg/kg body weight/day)
  // ==========================================

  "vitamin_d3": {
    // ⚠️ PetCut 핵심 시나리오 — 만성 vs 급성 구분 필수
    dog: {
      safe_max: 0.005,           // mg/kg BW/day (= 5 mcg/kg/day = 200 IU/kg BW/day)
      chronic_toxic: 0.01,       // mg/kg BW/day — 이 이상 지속 시 고칼슘혈증 (NRC 2006)
      acute_toxic: 0.1,          // mg/kg BW (single dose)
      unit: "mg/kg BW/day",
      note: "PetCut은 만성 일일 섭취 합산이므로 chronic_toxic이 primary threshold",
      unit_conversion: "1 mcg D3 = 40 IU. Always normalize to IU before calculation."
    },
    cat: {
      safe_max: 0.005,
      chronic_toxic: 0.01,
      acute_toxic: 0.1,
      unit: "mg/kg BW/day",
      note: "Similar sensitivity to dogs"
    },
    // 사료 내 함량 기준 (AAFCO) — 별도 트랙
    diet_based: {
      aafco_min: 500,            // IU/kg food (DM)
      aafco_max: 3000,           // IU/kg food (DM) — AAFCO (dogs & cats 동일)
      nrc_sul: 3200,             // IU/kg food (DM) — NRC (dogs)
      nrc_sul_cat: 10000,        // IU/kg food (DM) — NRC (cats) ← AAFCO보다 느슨
      primary_reference: "AAFCO" // 더 보수적인 AAFCO를 기본 기준으로 사용
    }
  },

  "iron": {
    // ⚠️ 이원 판단 체계 — 사료 기준 + 급성 독성 기준 병행
    dog: {
      // Track 1: 사료 내 함량 기준 (일상적 급여 판단용)
      diet_based_max: 3000,      // mg/kg food (DM) — AAFCO max
      diet_based_min: 80,        // mg/kg food (DM) — AAFCO min
      diet_unit: "mg/kg_food_DM",
      // Track 2: 체중 기준 급성 독성 (보충제 과량 시나리오)
      acute_toxic_dose: 20,      // mg/kg BW (single ingestion → GI symptoms)
      acute_lethal: 60,          // mg/kg BW (severe toxicity)
      acute_unit: "mg/kg_BW",
      note: "일일 사료+보충제 합산은 Track 1 기준. Track 2는 보충제 단독 과량 시 적용."
    },
    cat: {
      diet_based_max: 3000,
      diet_based_min: 80,
      diet_unit: "mg/kg_food_DM",
      acute_toxic_dose: 20,
      acute_lethal: 60,
      acute_unit: "mg/kg_BW",
      note: "Similar to dogs"
    }
  },

  "calcium": {
    dog: {
      safe_max_pct_diet: 1.8,        // % of diet (DM) — AAFCO adult max
      nrc_max_pct_diet: 2.5,         // % of diet (DM) — NRC adult max
      puppy_large_breed_max: 1.5,    // % of diet (DM) — AAFCO large breed puppy
      puppy_large_breed_caution: 1.2, // % of diet (DM) — 🔴 약사 추가: >1.2%면 caution
      unit: "% of diet (DM)",
      note: "대형견 강아지(성견 예상체중 >70lbs): 1.2% 이상이면 caution, 1.5% 이상이면 warning"
    },
    cat: {
      safe_max_pct_diet: 1.0,
      unit: "% of diet (DM)"
    }
  },

  "zinc": {
    dog: {
      safe_max: 10,              // mg/kg BW/day
      toxic_threshold: 25,       // mg/kg BW/day
      unit: "mg/kg BW/day"
    },
    cat: {
      safe_max: 8,
      toxic_threshold: 20,
      unit: "mg/kg BW/day"
    }
  },

  "copper": {
    dog: {
      safe_max: 0.5,             // mg/kg BW/day
      toxic_threshold: 1.0,      // mg/kg BW/day (breed-dependent)
      // 🟡 약사 수정: 민감 품종 리스트 확장
      breed_sensitive: [
        "Bedlington Terrier",          // 가장 심각 — copper storage disease
        "West Highland White Terrier",
        "Doberman Pinscher",
        "Labrador Retriever",
        "Dalmatian",                   // 추가
        "Skye Terrier",               // 추가
        "Cocker Spaniel"              // 추가 — American Cocker 특히
      ],
      sensitive_max: 0.25,       // 민감 품종은 safe_max의 절반
      unit: "mg/kg BW/day"
    },
    cat: {
      safe_max: 0.5,
      toxic_threshold: 1.0,
      unit: "mg/kg BW/day"
    }
  },

  // ==========================================
  // 이진 독성 (존재 여부 체크 — 역치 계산 아님)
  // ==========================================
  
  "garlic": {
    dog: { toxic_dose: 15.0, unit: "g/kg BW", note: "15-30 g/kg causes hemolysis. Flag ANY amount detected." },
    cat: { toxic_dose: 5.0, unit: "g/kg BW", note: "Much more sensitive than dogs. Flag ANY amount." }
  },
  
  "xylitol": {
    dog: { toxic_dose: 0.1, unit: "g/kg BW", note: "0.1 g/kg → hypoglycemia, 0.5 g/kg → liver failure" },
    // 🟢 약사 수정: "avoid" → "insufficient data, flag as caution"
    cat: { toxic_dose: null, unit: "g/kg BW", note: "Insufficient toxicity data — flag as caution if detected" }
  }
}
```

### 2.2 핵심 계산 함수

```
/// 메인 분석 함수
analyzeCombo(petProfile, products[]):

  results = {
    nutrient_totals: [],
    alerts: [],
    exclusion_recs: []
  }

  // Step 1: 각 제품에서 일일 섭취량 계산
  for product in products:
    product.daily_nutrients = convertToDailyIntake(product, petProfile)

  // Step 2: 영양소별 합산
  nutrient_map = {}   // { "vitamin_d3": { total: 0, sources: [] } }

  for product in products:
    for nutrient in product.daily_nutrients:
      if nutrient.name not in nutrient_map:
        nutrient_map[nutrient.name] = { total: 0, sources: [] }
      nutrient_map[nutrient.name].total += nutrient.daily_amount
      nutrient_map[nutrient.name].sources.append({
        product: product.name,
        amount: nutrient.daily_amount
      })

  // Step 3: 체중 기준 독성 체크
  for nutrient_name, data in nutrient_map:
    threshold = TOXICITY_THRESHOLDS[nutrient_name][petProfile.species]
    
    if threshold is null:
      continue  // 역치 데이터 없으면 스킵
    
    // === 🔴 약사 수정: 영양소별 판단 분기 ===
    
    if nutrient_name == "iron":
      // Iron: 이원 판단 체계
      // Track 1: 사료 내 함량 기준 (mg/kg food DM)
      //   → 사료의 iron 함량을 AAFCO max (3000 mg/kg DM)와 비교
      //   → 이건 Gemini가 사료 라벨에서 직접 판단 (per_kg 단위 그대로)
      // Track 2: 보충제 단독 과량 (mg/kg BW) 
      //   → 보충제의 iron per serving / petProfile.weightKg
      //   → acute_toxic_dose (20 mg/kg BW)와 비교
      supplement_iron_per_kg_bw = getSuplementOnlyAmount(data, "supplement") / petProfile.weightKg
      if supplement_iron_per_kg_bw >= threshold.acute_toxic_dose:
        status = "critical"
      elif supplement_iron_per_kg_bw >= threshold.acute_toxic_dose * 0.5:
        status = "warning"
      else:
        status = "safe"
      // Track 1은 Gemini 프롬프트가 사료 라벨 자체에서 AAFCO 범위 대비 판단
    
    elif nutrient_name == "calcium":
      // Calcium: % of diet 기준 (체중 기준이 아님)
      // 🔴 약사 수정: 대형견 강아지 >1.2%면 caution
      combined_ca_pct = estimateCombinedDietPercentage(data, petProfile)
      if petProfile.lifeStage == "puppy" and petProfile.weightKg >= 25:
        // 대형견 강아지 — 더 엄격한 기준
        if combined_ca_pct >= threshold.puppy_large_breed_max:  // 1.5%
          status = "warning"
        elif combined_ca_pct >= threshold.puppy_large_breed_caution:  // 1.2%
          status = "caution"
        else:
          status = "safe"
      else:
        if combined_ca_pct >= threshold.safe_max_pct_diet:  // 1.8% (dog) / 1.0% (cat)
          status = "warning"
        elif combined_ca_pct >= threshold.safe_max_pct_diet * 0.8:
          status = "caution"
        else:
          status = "safe"
    
    elif nutrient_name == "vitamin_d3":
      // 🔴 약사 수정: 만성 기준(chronic_toxic)이 primary threshold
      per_kg_intake = data.total / petProfile.weightKg
      
      effective_max = threshold.safe_max              // 0.005 mg/kg/day
      chronic_danger = threshold.chronic_toxic         // 0.01 mg/kg/day
      
      if per_kg_intake >= chronic_danger:
        status = "critical"    // 🔴 만성 독성 수준 — 고칼슘혈증 위험
      elif per_kg_intake >= effective_max:
        status = "warning"     // 🔴 안전 상한 초과
      elif per_kg_intake >= effective_max * 0.8:
        status = "caution"     // 🟡 안전 상한 80%+
      else:
        status = "safe"
    
    else:
      // 기본 로직: 체중 기준 비교
      per_kg_intake = data.total / petProfile.weightKg
      
      // 품종 민감도 체크
      effective_max = threshold.safe_max
      if threshold.breed_sensitive and petProfile.breed in threshold.breed_sensitive:
        effective_max = threshold.sensitive_max
      
      status = calculateStatus(per_kg_intake, effective_max, threshold)
    
    results.nutrient_totals.append({
      nutrient: nutrient_name,
      total_daily: data.total,
      per_kg_body_weight: data.total / petProfile.weightKg,
      safe_max: effective_max if defined else null,
      percent_of_limit: calculatePercentOfLimit(nutrient_name, data, petProfile),
      status: status,
      sources: data.sources
    })
    
    // 경고 생성
    if status in ["warning", "critical"]:
      results.alerts.append(generateAlert(nutrient_name, status, data))
      results.exclusion_recs.append(generateExclusion(nutrient_name, data))

  // Step 4: 기전 충돌 체크 (별도 함수)
  results.mechanism_conflicts = checkMechanismConflicts(products, petProfile)

  return results


/// 일일 섭취량 변환
convertToDailyIntake(product, petProfile):
  daily_nutrients = []

  for nutrient in product.key_nutrients:
    daily_amount = null

    switch nutrient.source_basis:
      case "per_serving":
        // 보충제: 라벨 서빙 그대로
        daily_amount = nutrient.amount  // assumes 1 serving/day
      
      case "per_kg":
        // 사료: per kg of food → 일일 급여량 기준 변환
        daily_food_kg = estimateDailyFoodIntake(petProfile)
        daily_amount = nutrient.amount * daily_food_kg
      
      case "percentage":
        // 사료: % of diet → 일일 급여량 기준 변환
        daily_food_g = estimateDailyFoodIntake(petProfile) * 1000
        daily_amount = (nutrient.amount / 100) * daily_food_g
      
      case "per_day":
        daily_amount = nutrient.amount

    daily_nutrients.append({
      name: nutrient.nutrient,
      daily_amount: daily_amount,
      unit: normalizeUnit(nutrient.unit),
      source_product: product.product_name
    })

  return daily_nutrients


/// 일일 사료 급여량 추정 (kg)
estimateDailyFoodIntake(petProfile):
  // RER (Resting Energy Requirement) 기반 추정
  // RER = 70 * (weightKg ^ 0.75) kcal/day
  
  rer = 70 * pow(petProfile.weightKg, 0.75)
  
  // MER (Maintenance Energy Requirement)
  // 🟡 약사 노트: puppy는 월령에 따라 큰 차이 (4개월 미만 3.0, 4~12개월 2.0)
  // MVP에서는 2.0 통일, v2에서 월령 세분화 검토
  multiplier = switch petProfile.lifeStage:
    puppy    → 2.0    // 성장기 (NOTE: <4mo=3.0, 4-12mo=2.0 — v2에서 세분화)
    adult    → 1.6    // 활동적 성견
    senior   → 1.2    // 노령견
    kitten   → 2.5    // 성장기 고양이
    adultCat → 1.4    // 실내 고양이
    seniorCat → 1.1
  
  if petProfile.isNeutered:
    multiplier *= 0.85
  
  mer = rer * multiplier   // kcal/day
  
  // 평균 건사료 열량: ~3,500 kcal/kg
  // 평균 습식사료: ~1,000 kcal/kg
  // 기본값: 건사료 가정
  food_kcal_per_kg = 3500
  
  daily_food_kg = mer / food_kcal_per_kg
  return daily_food_kg


/// 상태 판정
calculateStatus(per_kg_intake, safe_max, threshold):
  ratio = per_kg_intake / safe_max
  
  if threshold.toxic_threshold exists:
    if per_kg_intake >= threshold.toxic_threshold:
      return "critical"    // 🔴 독성 수준
  
  if ratio >= 1.5:
    return "warning"       // 🔴 상한선 150%+
  if ratio >= 1.0:
    return "caution"       // 🟡 상한선 도달
  if ratio >= 0.8:
    return "monitor"       // 🟡 상한선 80%+
  return "safe"            // 🟢


/// 기전 충돌 체크
checkMechanismConflicts(products, petProfile):
  conflicts = []
  all_ingredients = flatMap(products, p → p.ingredients)
  
  // 항응고 기전 스택 (SuppleCut GABAergic 7중 분석 대응)
  anticoagulants = filter(all_ingredients, i → 
    i in ["fish_oil", "omega_3", "ginkgo", "ginseng", "turmeric", "curcumin",
           "vitamin_e_high_dose", "garlic"])
  
  if anticoagulants.length >= 2:
    conflicts.append({
      type: "anticoagulant_stacking",
      ingredients: anticoagulants,
      severity: anticoagulants.length >= 3 ? "warning" : "caution",
      note: "Multiple blood-thinning ingredients may increase bleeding risk"
    })
  
  // 갑상선 충돌 (요오드 소스 중복)
  thyroid_disruptors = filter(all_ingredients, i →
    i in ["kelp", "seaweed", "iodine", "bladderwrack"])
  
  if thyroid_disruptors.length >= 2:
    conflicts.append({
      type: "thyroid_disruption",
      ingredients: thyroid_disruptors,
      severity: "warning",
      note: "Multiple iodine sources may cause thyroid dysfunction"
    })
  
  // 마늘 + 양파 용혈 리스크 (특히 고양이)
  hemolytic = filter(all_ingredients, i →
    i in ["garlic", "garlic_powder", "onion", "onion_powder", "chives", "leek"])
  
  if hemolytic.length >= 1:
    severity = petProfile.species == "cat" ? "critical" : "warning"
    conflicts.append({
      type: "hemolytic_risk",
      ingredients: hemolytic,
      severity: severity,
      note: "Allium family ingredients cause hemolytic anemia" +
            (petProfile.species == "cat" ? " — cats are extremely sensitive" : "")
    })
  
  // 🟡 약사 추가: 간독성 조합 (hepatotoxic_combo)
  hepatotoxic = filter(all_ingredients, i →
    i in ["comfrey", "pennyroyal", "kava", "germander", 
           "black_cohosh", "chaparral", "greater_celandine"])
  
  if hepatotoxic.length >= 2:
    conflicts.append({
      type: "hepatotoxic_combo",
      ingredients: hepatotoxic,
      severity: "warning",
      note: "Multiple hepatotoxic herbs compound liver damage risk. " +
            "Pyrrolizidine alkaloids (comfrey) are especially dangerous."
    })
  elif hepatotoxic.length == 1 and "comfrey" in hepatotoxic:
    // Comfrey는 단독으로도 flag — 펫 관절 보충제에 간혹 포함
    conflicts.append({
      type: "hepatotoxic_combo",
      ingredients: hepatotoxic,
      severity: "caution",
      note: "Comfrey contains pyrrolizidine alkaloids — hepatotoxic even alone. " +
            "Sometimes found in pet joint supplements."
    })
  
  // 칼슘:인 비율 체크 (대형견 강아지 특히 중요)
  // ... (합산 후 비율 계산)

  // v2 TODO: 칼슘-약물 흡수 저해 (absorption_interference)
  // 고칼슘 제품 + 테트라사이클린계 항생제 → 흡수 저해
  // 고칼슘 제품 + levothyroxine (갑상선 약물) → 흡수 저해
  // → currentMedications 필드 활성화 후 구현

  return conflicts
```

### 2.3 SuppleCut 4티어 제외 시스템 → PetCut 매핑

```
generateExclusion(nutrient_name, data):
  // 가장 많이 기여하는 제품을 제외 대상으로 선정
  sorted_sources = data.sources.sortBy(s → s.amount, descending)
  top_contributor = sorted_sources[0]
  
  // 티어 결정
  tier = switch:
    status == "critical"  → 1   // 즉시 제거
    status == "warning"   → 2   // 강력 권고
    status == "caution"   → 3   // 고려
    status == "monitor"   → 4   // 모니터링
  
  return {
    tier: tier,
    action: tier <= 2 ? "remove" : "reduce",
    target_product: top_contributor.product,
    reason: "{nutrient_name} contributes {pct}% from this product. " +
            "Removing it brings total to {new_pct}% of safe limit.",
    monthly_savings_usd: null  // 가격 정보 없으면 null
  }
```

---

## 3. 설계 노트

### SuppleCut과의 핵심 차이점

| 구분 | SuppleCut | PetCut |
|------|----------|--------|
| UL 기준 | 인체 Tolerable Upper Intake Level | 동물 체중별 독성 역치 |
| 단위 체계 | per serving (보충제 동일) | per_kg(사료) + per_serving(보충제) 혼재 |
| 급여량 추정 | 불필요 (1 serving = 1 serving) | 체중 기반 RER/MER 급여량 추정 필요 |
| 종별 차이 | 없음 (인체 단일) | 개 vs 고양이 독성 역치 상이 |
| 품종 민감도 | 없음 | 특정 품종 구리/특정 성분 민감 |
| 이진 독성 | 없음 | 마늘/자일리톨/포도 등 존재 자체가 위험 |

### Gemini에 위임 vs 앱에서 계산

| 항목 | Gemini (프롬프트) | 앱 (Dart) |
|------|-----------------|----------|
| OCR + 파싱 | ✅ | |
| 단위 변환 | ✅ (conversion_note로 추적) | |
| 급여량 추정 | ✅ (RER/MER 공식 프롬프트에 포함) | 🔄 검증용 |
| 독성 역치 비교 | ✅ | |
| 기전 충돌 | ✅ | |
| 상태 판정 | ✅ (overall_status) | |
| UI 매핑 | | ✅ (JSON → 위젯) |
| 체중 단위 변환 | | ✅ (lbs → kg) |

> **원칙**: SuppleCut과 동일하게 **"Decisions by Gemini, Display by App"**.
> 앱은 Gemini JSON을 신뢰하고 UI에 매핑만 한다.
> 단, PoC에서 Gemini 계산 정확도가 낮으면 앱 사이드 검증 로직 추가 검토.
