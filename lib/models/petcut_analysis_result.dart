// PetCut Gemini 분석 결과 모델 (SuppleCut OnestopAnalysisResult 패턴 기반)

class PetcutAnalysisResult {
  final List<PetcutProduct> products;
  final PetcutComboAnalysis comboAnalysis;
  final String overallStatus;
  final String overallSummary;

  const PetcutAnalysisResult({
    required this.products,
    required this.comboAnalysis,
    required this.overallStatus,
    required this.overallSummary,
  });

  factory PetcutAnalysisResult.fromJson(Map<String, dynamic> json) {
    final result = PetcutAnalysisResult(
      products: (json['products'] as List<dynamic>? ?? [])
          .map((e) => PetcutProduct.fromJson(e as Map<String, dynamic>))
          .toList(),
      comboAnalysis: PetcutComboAnalysis.fromJson(
          json['combo_analysis'] as Map<String, dynamic>? ?? {}),
      overallStatus: json['overall_status'] as String? ?? 'caution',
      overallSummary: json['overall_summary'] as String? ?? '',
    );
    return result._enforceOverallStatus();
  }

  PetcutAnalysisResult _enforceOverallStatus() {
    final hasWarning =
        comboAnalysis.mechanismConflicts.any((c) => c.severity == 'critical') ||
            comboAnalysis.nutrientTotals.any((n) => n.status == 'critical') ||
            products.any((p) =>
                p.flaggedIngredients.any((f) => f.severity == 'critical'));

    if (hasWarning && overallStatus != 'warning') {
      return PetcutAnalysisResult(
        products: products,
        comboAnalysis: comboAnalysis,
        overallStatus: 'warning',
        overallSummary: overallSummary,
      );
    }

    final hasCaution = comboAnalysis.mechanismConflicts.isNotEmpty ||
        comboAnalysis.nutrientTotals
            .any((n) => n.status == 'caution' || n.status == 'warning') ||
        comboAnalysis.exclusionRecommendations.isNotEmpty;

    if (hasCaution && overallStatus == 'perfect') {
      return PetcutAnalysisResult(
        products: products,
        comboAnalysis: comboAnalysis,
        overallStatus: 'caution',
        overallSummary: overallSummary,
      );
    }
    return this;
  }

  Map<String, dynamic> toJson() => {
        'products': products.map((e) => e.toJson()).toList(),
        'combo_analysis': comboAnalysis.toJson(),
        'overall_status': overallStatus,
        'overall_summary': overallSummary,
      };
}

class PetcutProduct {
  final String productName;
  final String productType;
  final String? brand;
  final String ingredientsRaw;
  final List<KeyNutrient> keyNutrients;
  final List<FlaggedIngredient> flaggedIngredients;

  const PetcutProduct({
    required this.productName,
    required this.productType,
    this.brand,
    required this.ingredientsRaw,
    required this.keyNutrients,
    required this.flaggedIngredients,
  });

  factory PetcutProduct.fromJson(Map<String, dynamic> json) => PetcutProduct(
        productName: json['product_name'] as String? ?? 'Unknown',
        productType: json['product_type'] as String? ?? 'food',
        brand: json['brand'] as String?,
        ingredientsRaw: json['ingredients_raw'] as String? ?? '',
        keyNutrients: (json['key_nutrients'] as List<dynamic>? ?? [])
            .map((e) => KeyNutrient.fromJson(e as Map<String, dynamic>))
            .toList(),
        flaggedIngredients:
            (json['flagged_ingredients'] as List<dynamic>? ?? [])
                .map(
                    (e) => FlaggedIngredient.fromJson(e as Map<String, dynamic>))
                .toList(),
      );

  Map<String, dynamic> toJson() => {
        'product_name': productName,
        'product_type': productType,
        if (brand != null) 'brand': brand,
        'ingredients_raw': ingredientsRaw,
        'key_nutrients': keyNutrients.map((e) => e.toJson()).toList(),
        'flagged_ingredients':
            flaggedIngredients.map((e) => e.toJson()).toList(),
      };
}

class KeyNutrient {
  final String nutrient;
  final double amount;
  final String unit;
  final String sourceBasis;
  final String? conversionNote;

  const KeyNutrient({
    required this.nutrient,
    required this.amount,
    required this.unit,
    required this.sourceBasis,
    this.conversionNote,
  });

  factory KeyNutrient.fromJson(Map<String, dynamic> json) => KeyNutrient(
        nutrient: json['nutrient'] as String? ?? '',
        amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
        unit: json['unit'] as String? ?? '',
        sourceBasis: json['source_basis'] as String? ?? 'per_serving',
        conversionNote: (json['daily_intake_converted']
            as Map<String, dynamic>?)?['conversion_note'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'nutrient': nutrient,
        'amount': amount,
        'unit': unit,
        'source_basis': sourceBasis,
      };
}

class FlaggedIngredient {
  final String ingredient;
  final String reason;
  final String severity;
  final String detail;

  const FlaggedIngredient({
    required this.ingredient,
    required this.reason,
    required this.severity,
    required this.detail,
  });

  factory FlaggedIngredient.fromJson(Map<String, dynamic> json) =>
      FlaggedIngredient(
        ingredient: json['ingredient'] as String? ?? '',
        reason: json['reason'] as String? ?? '',
        severity: json['severity'] as String? ?? 'caution',
        detail: json['detail'] as String? ?? '',
      );

  Map<String, dynamic> toJson() => {
        'ingredient': ingredient,
        'reason': reason,
        'severity': severity,
        'detail': detail,
      };
}

class PetcutComboAnalysis {
  final List<NutrientTotal> nutrientTotals;
  final List<MechanismConflict> mechanismConflicts;
  final List<ExclusionRecommendation> exclusionRecommendations;

  const PetcutComboAnalysis({
    required this.nutrientTotals,
    required this.mechanismConflicts,
    required this.exclusionRecommendations,
  });

  factory PetcutComboAnalysis.fromJson(Map<String, dynamic> json) =>
      PetcutComboAnalysis(
        nutrientTotals: (json['nutrient_totals'] as List<dynamic>? ?? [])
            .map((e) => NutrientTotal.fromJson(e as Map<String, dynamic>))
            .toList(),
        mechanismConflicts:
            (json['mechanism_conflicts'] as List<dynamic>? ?? [])
                .map((e) =>
                    MechanismConflict.fromJson(e as Map<String, dynamic>))
                .toList(),
        exclusionRecommendations:
            (json['exclusion_recommendations'] as List<dynamic>? ?? [])
                .map((e) => ExclusionRecommendation.fromJson(
                    e as Map<String, dynamic>))
                .toList(),
      );

  Map<String, dynamic> toJson() => {
        'nutrient_totals': nutrientTotals.map((e) => e.toJson()).toList(),
        'mechanism_conflicts':
            mechanismConflicts.map((e) => e.toJson()).toList(),
        'exclusion_recommendations':
            exclusionRecommendations.map((e) => e.toJson()).toList(),
      };
}

class NutrientTotal {
  final String nutrient;
  final double totalDailyIntake;
  final String unit;
  final List<String> sources;
  final double? percentOfLimit;
  final String status;

  const NutrientTotal({
    required this.nutrient,
    required this.totalDailyIntake,
    required this.unit,
    required this.sources,
    this.percentOfLimit,
    required this.status,
  });

  factory NutrientTotal.fromJson(Map<String, dynamic> json) => NutrientTotal(
        nutrient: json['nutrient'] as String? ?? '',
        totalDailyIntake:
            (json['total_daily_intake'] as num?)?.toDouble() ?? 0.0,
        unit: json['unit'] as String? ?? '',
        sources: (json['sources'] as List<dynamic>? ?? [])
            .map((e) => e as String)
            .toList(),
        percentOfLimit: (json['percent_of_limit'] as num?)?.toDouble(),
        status: json['status'] as String? ?? 'safe',
      );

  Map<String, dynamic> toJson() => {
        'nutrient': nutrient,
        'total_daily_intake': totalDailyIntake,
        'unit': unit,
        'sources': sources,
        if (percentOfLimit != null) 'percent_of_limit': percentOfLimit,
        'status': status,
      };
}

class MechanismConflict {
  final String conflictType;
  final List<String> involvedIngredients;
  final List<String> involvedProducts;
  final String severity;
  final String explanation;

  const MechanismConflict({
    required this.conflictType,
    required this.involvedIngredients,
    required this.involvedProducts,
    required this.severity,
    required this.explanation,
  });

  factory MechanismConflict.fromJson(Map<String, dynamic> json) =>
      MechanismConflict(
        conflictType: json['conflict_type'] as String? ?? '',
        involvedIngredients:
            (json['involved_ingredients'] as List<dynamic>? ?? [])
                .map((e) => e as String)
                .toList(),
        involvedProducts: (json['involved_products'] as List<dynamic>? ?? [])
            .map((e) => e as String)
            .toList(),
        severity: json['severity'] as String? ?? 'caution',
        explanation: json['explanation'] as String? ?? '',
      );

  Map<String, dynamic> toJson() => {
        'conflict_type': conflictType,
        'involved_ingredients': involvedIngredients,
        'involved_products': involvedProducts,
        'severity': severity,
        'explanation': explanation,
      };
}

class ExclusionRecommendation {
  final int tier;
  final String action;
  final String targetProduct;
  final String reason;
  final double? monthlySavingsUsd;

  const ExclusionRecommendation({
    required this.tier,
    required this.action,
    required this.targetProduct,
    required this.reason,
    this.monthlySavingsUsd,
  });

  factory ExclusionRecommendation.fromJson(Map<String, dynamic> json) =>
      ExclusionRecommendation(
        tier: (json['tier'] as num?)?.toInt() ?? 4,
        action: json['action'] as String? ?? 'monitor',
        targetProduct: json['target_product'] as String? ?? '',
        reason: json['reason'] as String? ?? '',
        monthlySavingsUsd:
            (json['monthly_savings_usd'] as num?)?.toDouble(),
      );

  Map<String, dynamic> toJson() => {
        'tier': tier,
        'action': action,
        'target_product': targetProduct,
        'reason': reason,
        if (monthlySavingsUsd != null)
          'monthly_savings_usd': monthlySavingsUsd,
      };
}
