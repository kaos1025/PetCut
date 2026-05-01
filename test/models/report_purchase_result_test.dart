// test/models/report_purchase_result_test.dart
//
// PetCut — ReportPurchaseResult sealed hierarchy tests
// ----------------------------------------------------------------------------
// Sprint 2 Chunk 2b — verifies construction, data carrying, and
// switch-exhaustiveness across both the top-level Result hierarchy and
// the nested Failure umbrella. Pattern matching coverage here is what
// guarantees the IAP service (Chunk 4) cannot silently drop a new
// terminal branch when the model evolves.
// ----------------------------------------------------------------------------

import 'package:flutter_test/flutter_test.dart';
import 'package:petcut/models/claude_report_response.dart';
import 'package:petcut/models/report_purchase_result.dart';

import '../helpers/load_claude_fixture.dart';

/// Returns a real `ClaudeReportResponse` parsed from the canonical
/// success fixture. Sprint 2 Chunk 5 followup: replaces the prior
/// `noSuchMethod`-based section stubs with the shared fixture loader so
/// schema regressions surface here too.
ClaudeReportResponse _stubReport() => loadClaudeFixture('success_full');

void main() {
  group('ReportPurchaseResult subtype construction', () {
    test('Success carries the ClaudeReportResponse', () {
      final report = _stubReport();
      final result = ReportPurchaseSuccess(report: report);

      expect(result, isA<ReportPurchaseResult>());
      expect(result, isA<ReportPurchaseSuccess>());
      expect(result.report, same(report));
    });

    test('FreeRetryGranted carries the purchase token', () {
      const token = 'GPA.1234-5678-9012-34567';
      const result = ReportPurchaseFreeRetryGranted(purchaseToken: token);

      expect(result, isA<ReportPurchaseResult>());
      expect(result, isA<ReportPurchaseFreeRetryGranted>());
      expect(result.purchaseToken, token);
    });

    test('PurchaseCanceledByUser is a Failure with no payload', () {
      const result = PurchaseCanceledByUser();

      expect(result, isA<ReportPurchaseResult>());
      expect(result, isA<ReportPurchaseFailure>());
      expect(result, isA<PurchaseCanceledByUser>());
    });

    test('PaymentError carries plain-English details', () {
      const result = PaymentError(details: 'Play Store unavailable');

      expect(result, isA<ReportPurchaseFailure>());
      expect(result.details, 'Play Store unavailable');
    });

    test('ClaudeApiError carries token and message', () {
      const result = ClaudeApiError(
        purchaseToken: 'GPA.token',
        message: 'HTTP 503',
      );

      expect(result, isA<ReportPurchaseFailure>());
      expect(result.purchaseToken, 'GPA.token');
      expect(result.message, 'HTTP 503');
    });

    test('UnknownError carries the original cause object', () {
      final cause = Exception('boom');
      final result = UnknownError(cause: cause);

      expect(result, isA<ReportPurchaseFailure>());
      expect(result.cause, same(cause));
    });
  });

  group('ReportPurchaseResult exhaustive switch (top-level)', () {
    String classify(ReportPurchaseResult r) => switch (r) {
          ReportPurchaseSuccess() => 'success',
          ReportPurchaseFreeRetryGranted() => 'free_retry',
          ReportPurchaseFailure() => 'failure',
        };

    test('routes Success', () {
      expect(classify(ReportPurchaseSuccess(report: _stubReport())),
          'success');
    });

    test('routes FreeRetryGranted', () {
      expect(
        classify(const ReportPurchaseFreeRetryGranted(
          purchaseToken: 'GPA.token',
        )),
        'free_retry',
      );
    });

    test('routes every Failure subtype to the umbrella branch', () {
      final failures = <ReportPurchaseFailure>[
        const PurchaseCanceledByUser(),
        const PaymentError(details: 'x'),
        const ClaudeApiError(purchaseToken: 't', message: 'm'),
        UnknownError(cause: Exception('boom')),
      ];

      for (final f in failures) {
        expect(classify(f), 'failure');
      }
    });
  });

  group('ReportPurchaseFailure exhaustive switch (nested)', () {
    String label(ReportPurchaseFailure f) => switch (f) {
          PurchaseCanceledByUser() => 'canceled',
          PaymentError() => 'payment',
          ClaudeApiError() => 'claude',
          UnknownError() => 'unknown',
        };

    test('routes each Failure subtype to its own branch', () {
      expect(label(const PurchaseCanceledByUser()), 'canceled');
      expect(label(const PaymentError(details: 'x')), 'payment');
      expect(
        label(const ClaudeApiError(purchaseToken: 't', message: 'm')),
        'claude',
      );
      expect(label(UnknownError(cause: Exception('boom'))), 'unknown');
    });
  });
}
