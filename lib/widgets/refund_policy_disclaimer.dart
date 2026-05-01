// PetCut — D8 refund-policy fine print, single source of truth.
// ----------------------------------------------------------------------------
// Sprint 2 Chunk 7a. Rendered identically below the purchase CTA and on the
// failure screen so the legal copy stays in lockstep across both surfaces.
// ----------------------------------------------------------------------------

import 'package:flutter/material.dart';

import '../theme/petcut_tokens.dart';

class RefundPolicyDisclaimer extends StatelessWidget {
  const RefundPolicyDisclaimer({super.key});

  /// Verbatim D8 lock-in text. Do not edit without legal review —
  /// `report_purchase_screen` and `report_failure_screen` both depend
  /// on this exact wording.
  static const String text =
      'If analysis fails, Google Play refunds your payment automatically '
      '(within 3 days), and you get one free retry. No additional charge.';

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: PcText.caption.copyWith(color: PcColors.textSec),
      textAlign: TextAlign.center,
    );
  }
}
