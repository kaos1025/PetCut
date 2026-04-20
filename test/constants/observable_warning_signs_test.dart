import 'package:flutter_test/flutter_test.dart';
import 'package:petcut/constants/observable_warning_signs.dart';
import 'package:petcut/models/pet_enums.dart';

void main() {
  const allKeys = <String>{
    'd3_excess',
    'iron_excess',
    'calcium_excess_large_breed_puppy',
    'garlic_exposure',
    'xylitol_exposure',
  };

  Set<String> resolvedKeys({
    required List<String> detectedRiskKeys,
    required Species species,
    required LifeStage lifeStage,
    required double weightKg,
  }) {
    return ObservableWarningSigns.resolveForPet(
      detectedRiskKeys: detectedRiskKeys,
      petSpecies: species,
      petLifeStage: lifeStage,
      petWeightKg: weightKg,
    ).map((e) => e.riskKey).toSet();
  }

  group('ObservableWarningSigns', () {
    group('registry', () {
      test('(a) allRiskKeys has 5 registered keys', () {
        final keys = ObservableWarningSigns.allRiskKeys.toSet();
        expect(keys.length, 5);
        expect(keys, allKeys);
      });

      test('(b) byKey returns entry for each registered key and null for unknown',
          () {
        for (final key in allKeys) {
          final entry = ObservableWarningSigns.byKey(key);
          expect(entry, isNotNull, reason: 'byKey($key) should not be null');
          expect(entry!.riskKey, key);
        }
        expect(ObservableWarningSigns.byKey('nonexistent'), isNull);
      });
    });

    group('resolveForPet', () {
      test('(c) adult dog 30kg → 4 entries (exclude large_breed_puppy)', () {
        final keys = resolvedKeys(
          detectedRiskKeys: allKeys.toList(),
          species: Species.dog,
          lifeStage: LifeStage.adult,
          weightKg: 30.0,
        );
        expect(keys, {
          'd3_excess',
          'iron_excess',
          'garlic_exposure',
          'xylitol_exposure',
        });
        expect(keys.contains('calcium_excess_large_breed_puppy'), isFalse);
      });

      test('(d) large-breed puppy 30kg → all 5 entries', () {
        final keys = resolvedKeys(
          detectedRiskKeys: allKeys.toList(),
          species: Species.dog,
          lifeStage: LifeStage.puppy,
          weightKg: 30.0,
        );
        expect(keys, allKeys);
      });

      test('(e) small-breed puppy 5kg → 4 entries (exclude large_breed_puppy)',
          () {
        final keys = resolvedKeys(
          detectedRiskKeys: allKeys.toList(),
          species: Species.dog,
          lifeStage: LifeStage.puppy,
          weightKg: 5.0,
        );
        expect(keys, {
          'd3_excess',
          'iron_excess',
          'garlic_exposure',
          'xylitol_exposure',
        });
        expect(keys.contains('calcium_excess_large_breed_puppy'), isFalse);
      });

      test('(f) adult cat 5kg → 3 entries (d3/iron/garlic only)', () {
        final keys = resolvedKeys(
          detectedRiskKeys: allKeys.toList(),
          species: Species.cat,
          lifeStage: LifeStage.adultCat,
          weightKg: 5.0,
        );
        expect(keys, {
          'd3_excess',
          'iron_excess',
          'garlic_exposure',
        });
        expect(keys.contains('xylitol_exposure'), isFalse);
        expect(keys.contains('calcium_excess_large_breed_puppy'), isFalse);
      });

      test('(f-1) adult cat 5kg → xylitol alone is filtered as dog-only', () {
        final result = ObservableWarningSigns.resolveForPet(
          detectedRiskKeys: const ['xylitol_exposure'],
          petSpecies: Species.cat,
          petLifeStage: LifeStage.adultCat,
          petWeightKg: 5.0,
        );
        expect(result, isEmpty);
      });
    });

    group('entry fields', () {
      test('(g) speciesSpecificNote: only garlic_exposure is non-null', () {
        expect(
          ObservableWarningSigns.byKey('garlic_exposure')!.speciesSpecificNote,
          isNotNull,
        );
        for (final key in const [
          'd3_excess',
          'iron_excess',
          'calcium_excess_large_breed_puppy',
          'xylitol_exposure',
        ]) {
          expect(
            ObservableWarningSigns.byKey(key)!.speciesSpecificNote,
            isNull,
            reason: '$key.speciesSpecificNote should be null',
          );
        }
      });

      test(
          '(h) escalatedTier: d3 + garlic non-null; iron/xylitol/calcium null',
          () {
        expect(
          ObservableWarningSigns.byKey('d3_excess')!.escalatedTier,
          isNotNull,
        );
        expect(
          ObservableWarningSigns.byKey('garlic_exposure')!.escalatedTier,
          isNotNull,
        );
        expect(
          ObservableWarningSigns.byKey('iron_excess')!.escalatedTier,
          isNull,
        );
        expect(
          ObservableWarningSigns.byKey('xylitol_exposure')!.escalatedTier,
          isNull,
        );
        expect(
          ObservableWarningSigns
              .byKey('calcium_excess_large_breed_puppy')!
              .escalatedTier,
          isNull,
        );
      });
    });
  });
}
