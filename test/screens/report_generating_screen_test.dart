// test/screens/report_generating_screen_test.dart
//
// PetCut — generating screen smoke tests
// ----------------------------------------------------------------------------
// Sprint 2 Chunk 7b. Two assertions:
//   1. The loading state renders the V2 lock-in copy verbatim plus the
//      brand-coloured spinner.
//   2. PopScope blocks BackButton (V3 lock-in: only OS-level kill exits;
//      the recoverPendingPurchases hook is the safety net).
// ----------------------------------------------------------------------------

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petcut/models/pet_profile.dart';
import 'package:petcut/models/petcut_analysis_result.dart';
import 'package:petcut/models/report_purchase_result.dart';
import 'package:petcut/screens/report_generating_screen.dart';

PetProfile _pet() => PetProfile(
      name: 'Buddy',
      species: Species.dog,
      weight: 30,
      weightUnit: WeightUnit.kg,
    );

PetcutAnalysisResult _gemini() => const PetcutAnalysisResult(
      products: [],
      comboAnalysis: PetcutComboAnalysis(
        nutrientTotals: [],
        mechanismConflicts: [],
        exclusionRecommendations: [],
      ),
      overallStatus: 'caution',
      overallSummary: '',
    );

void main() {
  testWidgets('renders the V2 generating copy and a brand spinner',
      (tester) async {
    final completer = Completer<ReportPurchaseResult>();
    addTearDown(() {
      if (!completer.isCompleted) completer.complete(const PurchaseCanceledByUser());
    });

    await tester.pumpWidget(
      MaterialApp(
        home: ReportGeneratingScreen(
          runOrchestration: () => completer.future,
          petProfile: _pet(),
          analysisResult: _gemini(),
          scanId: 'scan_X',
        ),
      ),
    );
    // Initial frame.
    await tester.pump();

    expect(find.text('Generating your detailed report'), findsOneWidget);
    expect(
      find.text(
        'This usually takes 60-90 seconds.\nPlease keep this screen open.',
      ),
      findsOneWidget,
    );
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('blocks back navigation via PopScope(canPop: false)',
      (tester) async {
    final completer = Completer<ReportPurchaseResult>();
    addTearDown(() {
      if (!completer.isCompleted) completer.complete(const PurchaseCanceledByUser());
    });

    await tester.pumpWidget(
      MaterialApp(
        home: ReportGeneratingScreen(
          runOrchestration: () => completer.future,
          petProfile: _pet(),
          analysisResult: _gemini(),
          scanId: 'scan_X',
        ),
      ),
    );
    await tester.pump();

    final popScope = tester.widget<PopScope>(find.byType(PopScope));
    expect(popScope.canPop, isFalse);
  });
}
