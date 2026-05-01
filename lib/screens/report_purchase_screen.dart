// PetCut — IAP entry screen for the paid Claude detailed report.
// ----------------------------------------------------------------------------
// Sprint 2 Chunk 7a. Renders the "Get Detailed Report" CTA, the D8 fine
// print, and routes the orchestrator result:
//   * ReportPurchaseSuccess           → push paid-report placeholder
//                                       (Chunk 7b replaces with the real
//                                       PaidReportScreen)
//   * ReportPurchaseFreeRetryGranted  → push ReportFailureScreen
//   * PurchaseCanceledByUser          → silent dismiss (stay on screen)
//   * PaymentError / ClaudeApiError /
//     UnknownError                    → inline SnackBar
//
// Pricing is rendered from `ProductDetails.price` (Play Billing
// formattedPrice) — never hardcoded. If a free-retry token is already
// active (Pattern D-1 mid-flow), the CTA flips to "Use Free Retry" and
// the price is hidden per U6.
// ----------------------------------------------------------------------------

import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import '../constants/iap_product_ids.dart';
import '../core/service_locator.dart';
import '../models/entitlement_token.dart';
import '../models/pet_profile.dart';
import '../models/petcut_analysis_result.dart';
import '../models/report_purchase_result.dart';
import '../services/iap_billing_service.dart';
import '../services/iap_entitlement_service.dart';
import '../services/report_purchase_orchestrator.dart';
import '../theme/petcut_tokens.dart';
import '../widgets/refund_policy_disclaimer.dart';
import 'report_failure_screen.dart';

class ReportPurchaseScreen extends StatefulWidget {
  final PetProfile petProfile;
  final PetcutAnalysisResult analysisResult;
  final String scanId;

  const ReportPurchaseScreen({
    super.key,
    required this.petProfile,
    required this.analysisResult,
    required this.scanId,
  });

  @override
  State<ReportPurchaseScreen> createState() => _ReportPurchaseScreenState();
}

class _ReportPurchaseScreenState extends State<ReportPurchaseScreen> {
  bool _loading = true;
  bool _processing = false;
  String? _loadError;
  ProductDetails? _productDetails;
  EntitlementToken? _activeToken;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    try {
      final responses = await Future.wait(<Future<Object?>>[
        getIt<IapBillingService>().queryProductDetails(),
        getIt<IapEntitlementService>().getActiveToken(),
      ]);
      final productResponse = responses[0]! as ProductDetailsResponse;
      final token = responses[1] as EntitlementToken?;

      ProductDetails? product;
      for (final p in productResponse.productDetails) {
        if (p.id == petcutReportStandardV1) {
          product = p;
          break;
        }
      }

      if (!mounted) return;
      setState(() {
        _productDetails = product;
        _activeToken = token;
        _loadError = (product == null && token == null)
            ? 'This report is not available right now. Please try again later.'
            : null;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = 'Failed to load report option.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PcColors.surface,
      appBar: AppBar(
        backgroundColor: PcColors.surface,
        elevation: 0,
        foregroundColor: PcColors.ink,
        title: const Text('Detailed Report', style: PcText.h2),
        centerTitle: true,
      ),
      body: SafeArea(
        child: _loading
            ? const Center(
                child: CircularProgressIndicator(color: PcColors.brand),
              )
            : _loadError != null
                ? _buildError(_loadError!)
                : _buildBody(),
      ),
    );
  }

  Widget _buildError(String message) {
    return Padding(
      padding: const EdgeInsets.all(PcSpace.xl),
      child: Center(
        child: Text(
          message,
          style: PcText.body.copyWith(color: PcColors.dangerText),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  Widget _buildBody() {
    final hasActiveToken = _activeToken != null;
    return Padding(
      padding: const EdgeInsets.all(PcSpace.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildHeader(),
          const SizedBox(height: PcSpace.lg),
          _buildIncludesCard(),
          const Spacer(),
          if (!hasActiveToken && _productDetails != null)
            _buildPriceLine(_productDetails!),
          if (!hasActiveToken && _productDetails != null)
            const SizedBox(height: PcSpace.sm),
          _buildPrimaryCta(hasActiveToken: hasActiveToken),
          const SizedBox(height: PcSpace.sm),
          const RefundPolicyDisclaimer(),
          const SizedBox(height: PcSpace.lg),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    final pet = widget.petProfile;
    final weightText = '${pet.weight.toStringAsFixed(1)} '
        '${pet.weightUnit.displayName}';
    return Container(
      padding: const EdgeInsets.all(PcSpace.lg),
      decoration: BoxDecoration(
        color: PcColors.brandTint,
        borderRadius: BorderRadius.circular(PcRadius.md),
      ),
      child: Row(
        children: [
          const Icon(Icons.pets, color: PcColors.brand, size: 24),
          const SizedBox(width: PcSpace.md),
          Expanded(
            child: Text(
              '${pet.name} · $weightText · ${pet.lifeStage.displayName}',
              style: PcText.body.copyWith(color: PcColors.ink),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIncludesCard() {
    return Container(
      padding: const EdgeInsets.all(PcSpace.lg),
      decoration: BoxDecoration(
        color: PcColors.surface2,
        border: Border.all(color: PcColors.border),
        borderRadius: BorderRadius.circular(PcRadius.md),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Detailed report includes', style: PcText.h2),
          SizedBox(height: PcSpace.md),
          _IncludeRow(text: 'Pet-specific risk profile'),
          _IncludeRow(text: 'Combo nutrient load report'),
          _IncludeRow(text: 'Mechanism interaction alerts'),
          _IncludeRow(text: 'Observable warning signs to watch'),
          _IncludeRow(text: 'Action plan with vet escalation triggers'),
        ],
      ),
    );
  }

  Widget _buildPriceLine(ProductDetails product) {
    return Text(
      product.price,
      style: PcText.h1.copyWith(color: PcColors.ink),
      textAlign: TextAlign.center,
    );
  }

  Widget _buildPrimaryCta({required bool hasActiveToken}) {
    final label = hasActiveToken ? 'Use Free Retry' : 'Get Detailed Report';
    final disabled = _processing ||
        (!hasActiveToken && _productDetails == null);
    return SizedBox(
      height: 56,
      child: FilledButton(
        style: FilledButton.styleFrom(
          backgroundColor: PcColors.brand,
          foregroundColor: PcColors.surface,
          disabledBackgroundColor: PcColors.brand,
          disabledForegroundColor: PcColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(PcRadius.md),
          ),
        ),
        onPressed: disabled ? null : _onPrimaryTap,
        child: _processing
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  color: PcColors.surface,
                  strokeWidth: 2,
                ),
              )
            : Text(label, style: PcText.h2),
      ),
    );
  }

  Future<void> _onPrimaryTap() async {
    setState(() => _processing = true);

    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    ReportPurchaseResult result;
    try {
      if (_activeToken != null) {
        result = await getIt<ReportPurchaseOrchestrator>().retryWithFreeToken(
          geminiResult: widget.analysisResult,
          pet: widget.petProfile,
          scanId: widget.scanId,
        );
      } else {
        result = await getIt<ReportPurchaseOrchestrator>().purchaseAndAnalyze(
          productDetails: _productDetails!,
          geminiResult: widget.analysisResult,
          pet: widget.petProfile,
          scanId: widget.scanId,
        );
      }
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text('Error: $e')));
      setState(() => _processing = false);
      return;
    }

    if (!mounted) return;

    switch (result) {
      case ReportPurchaseSuccess():
        navigator.push(
          MaterialPageRoute<void>(
            builder: (_) => const _PaidReportPlaceholder(),
          ),
        );
      case ReportPurchaseFreeRetryGranted():
        navigator.push(
          MaterialPageRoute<void>(
            builder: (_) => ReportFailureScreen(
              petProfile: widget.petProfile,
              analysisResult: widget.analysisResult,
              scanId: widget.scanId,
            ),
          ),
        );
      case PurchaseCanceledByUser():
        // Silent dismiss — user cancelled the Play sheet.
        break;
      case PaymentError(:final details):
        messenger.showSnackBar(SnackBar(content: Text(details)));
      case ClaudeApiError(:final message):
        messenger.showSnackBar(
          SnackBar(content: Text('Report unavailable: $message')),
        );
      case UnknownError():
        messenger.showSnackBar(
          const SnackBar(content: Text('Something went wrong.')),
        );
    }

    if (mounted) {
      setState(() => _processing = false);
    }
  }
}

class _IncludeRow extends StatelessWidget {
  final String text;
  const _IncludeRow({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: PcSpace.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.check_circle_outline,
            color: PcColors.brand,
            size: 20,
          ),
          const SizedBox(width: PcSpace.sm),
          Expanded(
            child: Text(text, style: PcText.body.copyWith(color: PcColors.ink)),
          ),
        ],
      ),
    );
  }
}

/// Inline placeholder to be replaced by `PaidReportScreen` in Chunk 7b.
class _PaidReportPlaceholder extends StatelessWidget {
  const _PaidReportPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PcColors.surface,
      appBar: AppBar(
        backgroundColor: PcColors.surface,
        elevation: 0,
        foregroundColor: PcColors.ink,
        title: const Text('Detailed Report', style: PcText.h2),
        centerTitle: true,
      ),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(PcSpace.xl),
          child: Text(
            'Detailed report ready. (Chunk 7b will render the full report here.)',
            style: PcText.body,
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
