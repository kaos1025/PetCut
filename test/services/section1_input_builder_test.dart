// test/services/section1_input_builder_test.dart
//
// PetCut — Section1InputBuilder tests
// ----------------------------------------------------------------------------
// Verifies that the §1 input builder correctly formats the pet profile,
// derives sensitivity flags from species/breed/life-stage/weight, composes
// weight_display in the user's preferred unit, and summarizes scan context.
// ----------------------------------------------------------------------------

import 'package:flutter_test/flutter_test.dart';
import 'package:petcut/models/pet_profile.dart';
import 'package:petcut/models/petcut_analysis_result.dart';
import 'package:petcut/services/section1_input_builder.dart';

// ---------------------------------------------------------------------------
// Factory helpers — independent per-test fixtures
// ---------------------------------------------------------------------------

PetProfile _pet({
  String name = 'Test',
  Species species = Species.dog,
  String? breed = 'Mixed',
  LifeStage lifeStage = LifeStage.adult,
  double weight = 15.0,
  WeightUnit weightUnit = WeightUnit.kg,
}) =>
    PetProfile(
      name: name,
      species: species,
      breed: breed,
      weight: weight,
      weightUnit: weightUnit,
      lifeStage: lifeStage,
    );

PetcutAnalysisResult _result({
  List<PetcutProduct> products = const [],
}) =>
    PetcutAnalysisResult(
      products: products,
      comboAnalysis: const PetcutComboAnalysis(
        nutrientTotals: [],
        mechanismConflicts: [],
        exclusionRecommendations: [],
      ),
      overallStatus: 'safe',
      overallSummary: '',
    );

PetcutProduct _product({
  String productType = 'food',
}) =>
    PetcutProduct(
      productName: 'Test Product',
      productType: productType,
      ingredientsRaw: '',
      keyNutrients: const [],
      flaggedIngredients: const [],
    );

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('Section1InputBuilder.build — pet field formatting', () {
    test('(a) adult dog default fields serialize as expected', () {
      final result = Section1InputBuilder.build(
        geminiResult: _result(),
        pet: _pet(),
      );
      final pet = result['pet'] as Map<String, dynamic>;
      expect(pet['name'], 'Test');
      expect(pet['species'], 'dog');
      expect(pet['breed'], 'Mixed');
      expect(pet['life_stage'], 'adult');
      expect(pet['weight_kg'], 15.0);
    });

    test('(b) adultCat enum serializes to life_stage "adult" (not "adultCat")',
        () {
      final result = Section1InputBuilder.build(
        geminiResult: _result(),
        pet: _pet(
          species: Species.cat,
          lifeStage: LifeStage.adultCat,
        ),
      );
      final pet = result['pet'] as Map<String, dynamic>;
      expect(pet['species'], 'cat');
      expect(pet['life_stage'], 'adult');
    });

    test('(c) null breed passes through as null without wrapping', () {
      final result = Section1InputBuilder.build(
        geminiResult: _result(),
        pet: _pet(breed: null),
      );
      final pet = result['pet'] as Map<String, dynamic>;
      expect(pet['breed'], isNull);
    });
  });

  group('Section1InputBuilder.build — weight_display', () {
    test('(d) 30 kg user -> "30 kg (66 lbs)"', () {
      final result = Section1InputBuilder.build(
        geminiResult: _result(),
        pet: _pet(weight: 30.0, weightUnit: WeightUnit.kg),
      );
      expect((result['pet'] as Map)['weight_display'], '30 kg (66 lbs)');
    });

    test('(e) 66 lbs user -> "66 lbs (29.9 kg)" (current roundtrip loss)', () {
      // PetProfile auto-converts lbs -> kg internally using the 0.453592
      // factor: weightKg == 66 * 0.453592 == 29.937072, which the Builder
      // then rounds to 1 decimal for display (29.9).
      //
      // As a result, a whole-number lbs input surfaces in the display with
      // a .9 kg companion rather than an integer kg. Preserving integer
      // kg for whole-number lbs inputs is planned as a separate follow-up
      // commit: `fix(sprint2): preserve integer precision in weight_display`.
      final result = Section1InputBuilder.build(
        geminiResult: _result(),
        pet: _pet(weight: 66.0, weightUnit: WeightUnit.lbs),
      );
      expect((result['pet'] as Map)['weight_display'], '66 lbs (29.9 kg)');
    });

    test('(f) fractional kg weight formats with single decimal', () {
      final result = Section1InputBuilder.build(
        geminiResult: _result(),
        pet: _pet(weight: 4.5, weightUnit: WeightUnit.kg),
      );
      expect((result['pet'] as Map)['weight_display'], '4.5 kg (10 lbs)');
    });
  });

  group('Section1InputBuilder.build — sensitivity_flags', () {
    test('(g) Doberman adult -> copper_sensitive_breed only', () {
      final result = Section1InputBuilder.build(
        geminiResult: _result(),
        pet: _pet(
          breed: 'Doberman Pinscher',
          lifeStage: LifeStage.adult,
          weight: 30.0,
        ),
      );
      final flags = (result['sensitivity_flags'] as List).cast<Map>();
      expect(flags.length, 1);
      expect(flags.first['flag_key'], 'copper_sensitive_breed');
    });

    test('(h) Mixed breed adult dog -> no sensitivity flags', () {
      final result = Section1InputBuilder.build(
        geminiResult: _result(),
        pet: _pet(breed: 'Mixed', lifeStage: LifeStage.adult),
      );
      expect(result['sensitivity_flags'], isEmpty);
    });

    test(
        '(i-1) Labrador puppy at 25.0 kg -> copper + large_breed_puppy '
        '(boundary inclusive)', () {
      // Boundary value — Builder uses >= 25.0.
      final result = Section1InputBuilder.build(
        geminiResult: _result(),
        pet: _pet(
          breed: 'Labrador Retriever',
          lifeStage: LifeStage.puppy,
          weight: 25.0,
        ),
      );
      final flags = (result['sensitivity_flags'] as List).cast<Map>();
      expect(flags.length, 2);
      final keys = flags.map((f) => f['flag_key']).toSet();
      expect(keys, {'copper_sensitive_breed', 'large_breed_puppy'});
    });

    test(
        '(i-2) Labrador puppy at 24.9 kg -> copper only '
        '(below boundary; large_breed_puppy excluded)', () {
      // Below boundary — large_breed_puppy excluded.
      final result = Section1InputBuilder.build(
        geminiResult: _result(),
        pet: _pet(
          breed: 'Labrador Retriever',
          lifeStage: LifeStage.puppy,
          weight: 24.9,
        ),
      );
      final flags = (result['sensitivity_flags'] as List).cast<Map>();
      expect(flags.length, 1);
      final keys = flags.map((f) => f['flag_key']).toSet();
      expect(keys, {'copper_sensitive_breed'});
    });

    test('(j) Senior mixed-breed dog -> senior_pet', () {
      final result = Section1InputBuilder.build(
        geminiResult: _result(),
        pet: _pet(breed: 'Mixed', lifeStage: LifeStage.senior),
      );
      final flags = (result['sensitivity_flags'] as List).cast<Map>();
      expect(flags.length, 1);
      expect(flags.first['flag_key'], 'senior_pet');
    });

    test('(k) Senior cat via seniorCat enum -> senior_pet', () {
      final result = Section1InputBuilder.build(
        geminiResult: _result(),
        pet: _pet(
          species: Species.cat,
          breed: null,
          lifeStage: LifeStage.seniorCat,
        ),
      );
      final flags = (result['sensitivity_flags'] as List).cast<Map>();
      expect(flags.length, 1);
      expect(flags.first['flag_key'], 'senior_pet');
    });

    test(
        '(l) Adult cat with a copper-listed breed name -> empty '
        '(species != dog guard rejects copper flag)', () {
      final result = Section1InputBuilder.build(
        geminiResult: _result(),
        pet: _pet(
          species: Species.cat,
          breed: 'Doberman Pinscher',
          lifeStage: LifeStage.adultCat,
        ),
      );
      expect(result['sensitivity_flags'], isEmpty);
    });
  });

  group('Section1InputBuilder.build — scan_context', () {
    test('(m) 1 food + 1 supplement -> summary "1 food + 1 supplement"', () {
      final result = Section1InputBuilder.build(
        geminiResult: _result(
          products: [
            _product(productType: 'food'),
            _product(productType: 'supplement'),
          ],
        ),
        pet: _pet(),
      );
      final scan = result['scan_context'] as Map<String, dynamic>;
      expect(scan['products_count'], 2);
      expect(scan['products_summary'], '1 food + 1 supplement');
    });

    test('(n) two supplements -> plural form "2 supplements"', () {
      final result = Section1InputBuilder.build(
        geminiResult: _result(
          products: [
            _product(productType: 'supplement'),
            _product(productType: 'supplement'),
          ],
        ),
        pet: _pet(),
      );
      final scan = result['scan_context'] as Map<String, dynamic>;
      expect(scan['products_count'], 2);
      expect(scan['products_summary'], '2 supplements');
    });

    test('(o) empty products -> "no products identified" and count 0', () {
      final result = Section1InputBuilder.build(
        geminiResult: _result(products: const []),
        pet: _pet(),
      );
      final scan = result['scan_context'] as Map<String, dynamic>;
      expect(scan['products_count'], 0);
      expect(scan['products_summary'], 'no products identified');
    });
  });

  group('Section1InputBuilder.build — edge cases', () {
    test(
        '(p) Senior Cocker Spaniel -> copper + senior_pet '
        '(maximum concurrent = 2; puppy and senior cannot coexist)', () {
      final result = Section1InputBuilder.build(
        geminiResult: _result(),
        pet: _pet(
          breed: 'Cocker Spaniel',
          lifeStage: LifeStage.senior,
        ),
      );
      final flags = (result['sensitivity_flags'] as List).cast<Map>();
      expect(flags.length, 2);
      final keys = flags.map((f) => f['flag_key']).toSet();
      expect(keys, {'copper_sensitive_breed', 'senior_pet'});
    });

    test('(q) top-level and nested keys use order-independent set equality',
        () {
      final result = Section1InputBuilder.build(
        geminiResult: _result(
          products: [_product(productType: 'food')],
        ),
        pet: _pet(),
      );
      expect(
        result.keys.toSet(),
        {'section', 'pet', 'sensitivity_flags', 'scan_context'},
      );
      expect(result['section'], 'pet_risk_profile');
      expect(
        (result['pet'] as Map).keys.toSet(),
        {
          'name',
          'species',
          'breed',
          'life_stage',
          'weight_kg',
          'weight_display',
        },
      );
      expect(
        (result['scan_context'] as Map).keys.toSet(),
        {'products_count', 'products_summary'},
      );
    });
  });
}
