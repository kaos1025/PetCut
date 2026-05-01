// test/screens/paid_report_screen_test.dart
//
// PetCut — paid report screen smoke tests
// ----------------------------------------------------------------------------
// Sprint 2 Chunk 7b. Loads the canonical Claude success fixture through the
// shared helper and verifies:
//   1. All five section titles surface as headers in the list.
//   2. The pet profile card surfaces the pet identity line.
//   3. The status banner label routes correctly for the three overall
//      statuses (perfect / caution / warning).
// ----------------------------------------------------------------------------

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petcut/models/claude_report_response.dart';
import 'package:petcut/models/pet_profile.dart';
import 'package:petcut/models/petcut_analysis_result.dart';
import 'package:petcut/screens/paid_report_screen.dart';

import '../helpers/load_claude_fixture.dart';

PetProfile _pet() => PetProfile(
      name: 'Buddy',
      species: Species.dog,
      weight: 30,
      weightUnit: WeightUnit.kg,
    );

PetcutAnalysisResult _gemini(String overallStatus) => PetcutAnalysisResult(
      products: const [],
      comboAnalysis: const PetcutComboAnalysis(
        nutrientTotals: [],
        mechanismConflicts: [],
        exclusionRecommendations: [],
      ),
      overallStatus: overallStatus,
      overallSummary: '',
    );

Future<void> _pumpScreen(
  WidgetTester tester, {
  required ClaudeReportResponse report,
  required String overallStatus,
}) async {
  // Tall surface so all five section cards live in the viewport
  // simultaneously — ListView lazy-loads off-screen children, which
  // would otherwise hide sections 2-5 from `find.text`.
  await tester.binding.setSurfaceSize(const Size(800, 4000));
  addTearDown(() => tester.binding.setSurfaceSize(null));

  await tester.pumpWidget(
    MaterialApp(
      home: PaidReportScreen(
        report: report,
        petProfile: _pet(),
        analysisResult: _gemini(overallStatus),
      ),
    ),
  );
}

void main() {
  testWidgets('renders all five section titles from success_full fixture',
      (tester) async {
    final report = loadClaudeFixture('success_full');

    await _pumpScreen(tester, report: report, overallStatus: 'caution');
    await tester.pumpAndSettle();

    // Each section's title is the canonical header rendered in the card.
    expect(find.text(report.section1.title), findsOneWidget);
    expect(find.text(report.section2.title), findsOneWidget);
    expect(find.text(report.section3.title), findsOneWidget);
    expect(find.text(report.section4.title), findsOneWidget);
    expect(find.text(report.section5.title), findsOneWidget);

    // Disclaimer footer is present.
    expect(
      find.text('This is informational only. Consult your veterinarian.'),
      findsOneWidget,
    );
  });

  testWidgets('pet profile card surfaces pet identity line', (tester) async {
    final report = loadClaudeFixture('success_full');

    await _pumpScreen(tester, report: report, overallStatus: 'caution');
    await tester.pumpAndSettle();

    expect(find.text('Buddy · 30.0 kg · Adult'), findsOneWidget);
  });

  testWidgets('status banner label routes correctly per overallStatus',
      (tester) async {
    final report = loadClaudeFixture('success_full');

    // perfect → All Clear
    await _pumpScreen(tester, report: report, overallStatus: 'perfect');
    await tester.pumpAndSettle();
    expect(find.text('All Clear'), findsOneWidget);

    // caution → Caution
    await _pumpScreen(tester, report: report, overallStatus: 'caution');
    await tester.pumpAndSettle();
    expect(find.text('Caution'), findsOneWidget);

    // warning → Warning
    await _pumpScreen(tester, report: report, overallStatus: 'warning');
    await tester.pumpAndSettle();
    expect(find.text('Warning'), findsOneWidget);
  });
}
