// PetCut — report-failure screen.
// ----------------------------------------------------------------------------
// Sprint 2 Chunk 7a. Reached on the Pattern D-1 refund branch:
// `purchaseAndAnalyze` returned `ReportPurchaseFreeRetryGranted`. The screen
// surfaces the D6 lock-in copy and offers a free retry through
// `Orchestrator.retryWithFreeToken`.
// ----------------------------------------------------------------------------

import 'package:flutter/material.dart';

import '../core/service_locator.dart';
import '../models/pet_profile.dart';
import '../models/petcut_analysis_result.dart';
import '../models/report_purchase_result.dart';
import '../services/report_purchase_orchestrator.dart';
import '../theme/petcut_tokens.dart';
import '../widgets/refund_policy_disclaimer.dart';

class ReportFailureScreen extends StatefulWidget {
  final PetProfile petProfile;
  final PetcutAnalysisResult analysisResult;
  final String scanId;

  const ReportFailureScreen({
    super.key,
    required this.petProfile,
    required this.analysisResult,
    required this.scanId,
  });

  @override
  State<ReportFailureScreen> createState() => _ReportFailureScreenState();
}

class _ReportFailureScreenState extends State<ReportFailureScreen> {
  bool _retrying = false;

  /// Verbatim D6 lock-in. Do not edit without legal review.
  static const String _refundCopy =
      'Your payment will be refunded automatically by Google Play '
      'within 3 days, and one free retry has been granted to your account.';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PcColors.surface,
      appBar: AppBar(
        backgroundColor: PcColors.surface,
        elevation: 0,
        title: const Text('Report Failed', style: PcText.h2),
        centerTitle: true,
        foregroundColor: PcColors.ink,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(PcSpace.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildStatusBanner(),
              const SizedBox(height: PcSpace.xl),
              Text(
                _refundCopy,
                style: PcText.body.copyWith(color: PcColors.ink),
              ),
              const Spacer(),
              _buildRetryButton(),
              const SizedBox(height: PcSpace.md),
              _buildCloseButton(),
              const SizedBox(height: PcSpace.lg),
              const RefundPolicyDisclaimer(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBanner() {
    return Container(
      padding: const EdgeInsets.all(PcSpace.lg),
      decoration: BoxDecoration(
        color: PcColors.dangerBg,
        border: Border.all(color: PcColors.dangerAccent),
        borderRadius: BorderRadius.circular(PcRadius.md),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.error_outline,
            color: PcColors.dangerAccent,
            size: 32,
          ),
          const SizedBox(height: PcSpace.sm),
          Text(
            'Report generation failed',
            style: PcText.h2.copyWith(color: PcColors.dangerText),
          ),
        ],
      ),
    );
  }

  Widget _buildRetryButton() {
    return SizedBox(
      height: 56,
      child: FilledButton(
        style: FilledButton.styleFrom(
          backgroundColor: PcColors.infoAccent,
          foregroundColor: PcColors.surface,
          disabledBackgroundColor: PcColors.infoAccent,
          disabledForegroundColor: PcColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(PcRadius.md),
          ),
        ),
        onPressed: _retrying ? null : _onRetry,
        child: _retrying
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  color: PcColors.surface,
                  strokeWidth: 2,
                ),
              )
            : const Text('Retry Now (Free)', style: PcText.h2),
      ),
    );
  }

  Widget _buildCloseButton() {
    return SizedBox(
      height: 56,
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          backgroundColor: PcColors.surface,
          foregroundColor: PcColors.ink,
          side: const BorderSide(color: PcColors.border, width: 0.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(PcRadius.md),
          ),
        ),
        onPressed: _retrying ? null : () => Navigator.of(context).pop(),
        child: const Text('Close', style: PcText.h2),
      ),
    );
  }

  Future<void> _onRetry() async {
    setState(() => _retrying = true);

    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    ReportPurchaseResult result;
    try {
      result = await getIt<ReportPurchaseOrchestrator>().retryWithFreeToken(
        geminiResult: widget.analysisResult,
        pet: widget.petProfile,
        scanId: widget.scanId,
      );
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('Retry error: $e')),
      );
      setState(() => _retrying = false);
      return;
    }

    if (!mounted) return;

    if (result is ReportPurchaseSuccess) {
      // Chunk 7b will replace with a push to PaidReportScreen.
      navigator.pop(result);
      return;
    }

    messenger.showSnackBar(
      const SnackBar(
        content: Text('Retry failed. Please try again later.'),
      ),
    );
    setState(() => _retrying = false);
  }
}
