// PetCut — IAP report-generating screen.
// ----------------------------------------------------------------------------
// Sprint 2 Chunk 7b. Sits between ReportPurchaseScreen and the terminal
// destination (PaidReportScreen / ReportFailureScreen / pop). Owns the
// orchestrator call so the previous screen can pushReplacement and tear
// down before the long-running Claude request begins.
//
// Pattern D safety:
//   * BackButton is blocked via PopScope(canPop: false). The platform-level
//     OS kill is the only way out; the Chunk 6.5 recoverPendingPurchases
//     hook is the safety net for that case.
//   * No Cancel control. Pricing is locked in by Play Billing the moment
//     the purchase event reaches awaitingClaude — adding a cancel button
//     here would imply consume() rollback semantics we do not support.
// ----------------------------------------------------------------------------

import 'package:flutter/material.dart';

import '../models/pet_profile.dart';
import '../models/petcut_analysis_result.dart';
import '../models/report_purchase_result.dart';
import '../theme/petcut_tokens.dart';
import 'paid_report_screen.dart';
import 'report_failure_screen.dart';

typedef OrchestrationCallback = Future<ReportPurchaseResult> Function();

class ReportGeneratingScreen extends StatefulWidget {
  /// Closure that performs the orchestrator call. Captured here so the
  /// previous screen can pushReplacement and exit the tree before the
  /// long-running Claude request starts.
  final OrchestrationCallback runOrchestration;
  final PetProfile petProfile;
  final PetcutAnalysisResult analysisResult;
  final String scanId;

  const ReportGeneratingScreen({
    super.key,
    required this.runOrchestration,
    required this.petProfile,
    required this.analysisResult,
    required this.scanId,
  });

  @override
  State<ReportGeneratingScreen> createState() =>
      _ReportGeneratingScreenState();
}

class _ReportGeneratingScreenState extends State<ReportGeneratingScreen> {
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    // Defer to first frame so Navigator transitions complete before the
    // orchestrator's stream subscription fires.
    WidgetsBinding.instance.addPostFrameCallback((_) => _run());
  }

  Future<void> _run() async {
    final navigator = Navigator.of(context);

    ReportPurchaseResult result;
    try {
      result = await widget.runOrchestration();
    } catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = 'Something went wrong. Please try again.');
      return;
    }

    if (!mounted) return;

    switch (result) {
      case ReportPurchaseSuccess(:final report):
        navigator.pushReplacement(
          MaterialPageRoute<void>(
            builder: (_) => PaidReportScreen(
              report: report,
              petProfile: widget.petProfile,
              analysisResult: widget.analysisResult,
            ),
          ),
        );
      case ReportPurchaseFreeRetryGranted():
        navigator.pushReplacement(
          MaterialPageRoute<void>(
            builder: (_) => ReportFailureScreen(
              petProfile: widget.petProfile,
              analysisResult: widget.analysisResult,
              scanId: widget.scanId,
            ),
          ),
        );
      case PurchaseCanceledByUser():
        // Silent: drop back to whatever was before the purchase entry.
        navigator.pop();
      case PaymentError(:final details):
        setState(() => _errorMessage = details);
      case ClaudeApiError(:final message):
        setState(() => _errorMessage = message);
      case UnknownError():
        setState(() => _errorMessage = 'Something went wrong.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: PcColors.surface,
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(PcSpace.xl),
              child:
                  _errorMessage != null ? _buildError() : _buildLoading(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoading() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const CircularProgressIndicator(color: PcColors.brand),
        const SizedBox(height: PcSpace.xl),
        Text(
          'Generating your detailed report',
          style: PcText.h1.copyWith(color: PcColors.ink),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: PcSpace.md),
        Text(
          'This usually takes 60-90 seconds.\nPlease keep this screen open.',
          style: PcText.body.copyWith(color: PcColors.textSec),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildError() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Icon(
          Icons.error_outline,
          color: PcColors.dangerAccent,
          size: 32,
        ),
        const SizedBox(height: PcSpace.md),
        Text(
          _errorMessage!,
          style: PcText.body.copyWith(color: PcColors.ink),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: PcSpace.xl),
        SizedBox(
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
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close', style: PcText.h2),
          ),
        ),
      ],
    );
  }
}
