import 'package:flutter/material.dart';

import '../core/service_locator.dart';
import '../models/pet_profile.dart';
import '../models/petcut_analysis_result.dart';
import '../models/scan_history_entry.dart';
import '../services/scan_history_service.dart';
import '../theme/petcut_tokens.dart';

/// Gemini 분석 결과 표시 화면
class AnalysisResultScreen extends StatefulWidget {
  final PetcutAnalysisResult result;
  final PetProfile petProfile;

  const AnalysisResultScreen({
    super.key,
    required this.result,
    required this.petProfile,
  });

  @override
  State<AnalysisResultScreen> createState() => _AnalysisResultScreenState();
}

class _AnalysisResultScreenState extends State<AnalysisResultScreen> {
  bool _isSaved = false;

  // TODO(sprint-2): history에서 재진입 시 원본 scanId 주입 받도록
  // 생성자에 optional String? existingScanId 추가 예정
  late final String _scanId = 'scan_${DateTime.now().millisecondsSinceEpoch}';

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _isSaved,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        await _showUnsavedDialog();
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Analysis Result'),
          centerTitle: true,
        ),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            children: [
              // 1. Overall Status Banner
              _buildStatusBanner(),
              const SizedBox(height: 12),

              // 1.5 Save scan button (DS §7.9)
              Align(
                alignment: Alignment.centerLeft,
                child: _buildSaveButton(),
              ),
              const SizedBox(height: 16),

              // 2. Pet Profile Card
              _buildPetProfileCard(),
              const SizedBox(height: 16),

              // 3. Products
              if (widget.result.products.isNotEmpty) ...[
                _buildSectionTitle('Products'),
                const SizedBox(height: 8),
                ...widget.result.products.map(_buildProductCard),
                const SizedBox(height: 16),
              ],

              // 4. Nutrient Totals
              if (widget.result.comboAnalysis.nutrientTotals.isNotEmpty) ...[
                _buildSectionTitle('Nutrient Totals'),
                const SizedBox(height: 8),
                ...widget.result.comboAnalysis.nutrientTotals
                    .map(_buildNutrientRow),
                const SizedBox(height: 16),
              ],

              // 5. Mechanism Conflicts
              if (widget
                  .result.comboAnalysis.mechanismConflicts.isNotEmpty) ...[
                _buildSectionTitle('Mechanism Conflicts'),
                const SizedBox(height: 8),
                ...widget.result.comboAnalysis.mechanismConflicts
                    .map(_buildConflictCard),
                const SizedBox(height: 16),
              ],

              // 6. Exclusion Recommendations
              if (widget.result.comboAnalysis.exclusionRecommendations
                  .isNotEmpty) ...[
                _buildSectionTitle('Recommendations'),
                const SizedBox(height: 8),
                ...widget.result.comboAnalysis.exclusionRecommendations
                    .map(_buildExclusionCard),
                const SizedBox(height: 16),
              ],

              // 7. Disclaimer
              const SizedBox(height: 8),
              Text(
                'Not a substitute for professional veterinary advice.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade500,
                  fontStyle: FontStyle.italic,
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  // === Save flow (DS §7.9 / §7.10) ==========================================

  Widget _buildSaveButton() {
    final active = !_isSaved;
    return SizedBox(
      height: 40,
      child: OutlinedButton(
        onPressed: active ? () => _saveScan() : null,
        style: OutlinedButton.styleFrom(
          backgroundColor: PcColors.surface,
          foregroundColor: active ? PcColors.ink : PcColors.brand,
          disabledForegroundColor: PcColors.brand,
          disabledBackgroundColor: PcColors.surface,
          side: BorderSide(
            color: active ? PcColors.border : PcColors.brand,
            width: 0.5,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(PcRadius.md),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          animationDuration: const Duration(milliseconds: 150),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(active ? Icons.bookmark_border : Icons.bookmark, size: 18),
            const SizedBox(width: 6),
            Text(
              active ? 'Save scan' : 'Saved',
              style: PcText.body.copyWith(fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveScan({bool showSnackbar = true}) async {
    // cautionCount = nutrient(status==caution) + flagged_ingredient(severity==caution).
    // mechanism conflicts는 severity 상관없이 전부 conflictCount로 분류 (UX 판단).
    final entry = ScanHistoryEntry(
      id: _scanId,
      scannedAt: DateTime.now(),
      productNames: widget.result.products.map((p) => p.productName).toList(),
      overallStatus: widget.result.overallStatus,
      conflictCount: widget.result.comboAnalysis.mechanismConflicts.length,
      cautionCount: _computeCautionCount(),
      petId: widget.petProfile.id,
    );

    await getIt<ScanHistoryService>().add(entry);
    if (!mounted) return;
    setState(() => _isSaved = true);

    if (!showSnackbar) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Saved to history',
          style: PcText.body.copyWith(
            color: PcColors.surface,
            fontSize: 14,
          ),
        ),
        backgroundColor: PcColors.ink,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(PcRadius.md),
        ),
        margin: const EdgeInsets.all(PcSpace.lg),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  int _computeCautionCount() {
    final n = widget.result.comboAnalysis.nutrientTotals
        .where((x) => x.status == 'caution')
        .length;
    final f = widget.result.products
        .expand((p) => p.flaggedIngredients)
        .where((x) => x.severity == 'caution')
        .length;
    return n + f;
  }

  Future<void> _showUnsavedDialog() async {
    final screenNavigator = Navigator.of(context);

    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: PcColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(PcRadius.lg),
        ),
        titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
        contentPadding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
        actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        title: const Text('Save this scan?', style: PcText.h2),
        content: Text(
          'You can review it later in Recent scans.',
          style: PcText.body.copyWith(color: PcColors.textSec),
        ),
        actionsAlignment: MainAxisAlignment.end,
        actions: [
          TextButton(
            style: TextButton.styleFrom(foregroundColor: PcColors.textSec),
            onPressed: () {
              Navigator.pop(dialogContext);
              screenNavigator.pop();
            },
            child: const Text('Discard'),
          ),
          const SizedBox(width: 8),
          SizedBox(
            height: 40,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: PcColors.ink,
                foregroundColor: PcColors.surface,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(PcRadius.md),
                ),
              ),
              onPressed: () async {
                await _saveScan(showSnackbar: false);
                if (!dialogContext.mounted) return;
                Navigator.pop(dialogContext);
                screenNavigator.pop();
              },
              child: const Text('Save'),
            ),
          ),
        ],
      ),
    );
  }

  // === Existing renderers (로직/스타일 불변, widget.* 접두어만 추가) ========

  // --- 1. Overall Status Banner ---
  Widget _buildStatusBanner() {
    final Color bgColor;
    final Color borderColor;
    final Color iconColor;
    final IconData icon;
    final String label;

    switch (widget.result.overallStatus) {
      case 'perfect':
        bgColor = Colors.green.shade50;
        borderColor = Colors.green.shade400;
        iconColor = Colors.green.shade700;
        icon = Icons.check_circle;
        label = 'All Clear';
      case 'warning':
        bgColor = Colors.red.shade50;
        borderColor = Colors.red.shade400;
        iconColor = Colors.red.shade700;
        icon = Icons.error;
        label = 'Warning';
      default: // caution
        bgColor = Colors.amber.shade50;
        borderColor = Colors.amber.shade400;
        iconColor = Colors.amber.shade800;
        icon = Icons.warning;
        label = 'Caution';
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bgColor,
        border: Border.all(color: borderColor),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: iconColor, size: 28),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: iconColor,
                ),
              ),
            ],
          ),
          if (widget.result.overallSummary.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              widget.result.overallSummary,
              style: const TextStyle(fontSize: 16),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }

  // --- 2. Pet Profile Card ---
  Widget _buildPetProfileCard() {
    final weightText =
        '${widget.petProfile.weight.toStringAsFixed(1)} ${widget.petProfile.weightUnit.displayName}';
    final ageText = widget.petProfile.ageYears != null
        ? '${widget.petProfile.ageYears!.toStringAsFixed(1)} yrs'
        : 'Age unknown';

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: Colors.green.shade50,
              child: const Icon(Icons.pets, size: 24, color: Colors.green),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                '${widget.petProfile.name} · $weightText · $ageText · ${widget.petProfile.lifeStage.displayName}',
                style: const TextStyle(fontSize: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- 3. Product Card ---
  Widget _buildProductCard(PetcutProduct product) {
    return Card(
      elevation: 1,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    product.productName,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                _buildSourceBadge(product),
              ],
            ),
            if (product.brand != null && product.brand!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                product.brand!,
                style: TextStyle(fontSize: 15, color: Colors.grey.shade600),
              ),
            ],
            if (product.flaggedIngredients.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children:
                    product.flaggedIngredients.map(_buildFlaggedChip).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSourceBadge(PetcutProduct product) {
    // source 필드가 모델에 없으므로 productType 기반으로 표시
    final color =
        product.productType == 'supplement' ? Colors.blue : Colors.green;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.shade300),
      ),
      child: Text(
        product.productType,
        style: TextStyle(fontSize: 12, color: color.shade700),
      ),
    );
  }

  Widget _buildFlaggedChip(FlaggedIngredient flag) {
    final MaterialColor chipColor;
    switch (flag.severity) {
      case 'critical':
        chipColor = Colors.red;
      case 'warning':
        chipColor = Colors.orange;
      default:
        chipColor = Colors.amber;
    }

    return Tooltip(
      message: flag.detail,
      child: Chip(
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        label: Text(
          flag.ingredient,
          style: TextStyle(fontSize: 13, color: chipColor.shade900),
        ),
        backgroundColor: chipColor.shade50,
        side: BorderSide(color: chipColor.shade300),
        padding: const EdgeInsets.symmetric(horizontal: 4),
      ),
    );
  }

  // --- 4. Nutrient Total Row ---
  Widget _buildNutrientRow(NutrientTotal nutrient) {
    final MaterialColor barColor;
    switch (nutrient.status) {
      case 'critical':
        barColor = Colors.red;
      case 'warning':
        barColor = Colors.orange;
      case 'caution':
        barColor = Colors.amber;
      default:
        barColor = Colors.green;
    }

    final percent = nutrient.percentOfLimit;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  nutrient.nutrient,
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
              Text(
                '${nutrient.totalDailyIntake.toStringAsFixed(2)} ${nutrient.unit}',
                style: const TextStyle(fontSize: 15),
              ),
            ],
          ),
          if (percent != null) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: (percent / 100).clamp(0.0, 1.0),
                      minHeight: 10,
                      backgroundColor: Colors.grey.shade200,
                      valueColor: AlwaysStoppedAnimation(barColor),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${percent.toStringAsFixed(0)}%',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: barColor.shade700,
                  ),
                ),
              ],
            ),
          ],
          if (nutrient.sources.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              nutrient.sources.join(', '),
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
            ),
          ],
        ],
      ),
    );
  }

  // --- 5. Mechanism Conflict Card ---
  Widget _buildConflictCard(MechanismConflict conflict) {
    final Color borderColor;
    switch (conflict.severity) {
      case 'critical':
        borderColor = Colors.red;
      case 'warning':
        borderColor = Colors.orange;
      default:
        borderColor = Colors.amber;
    }

    return Card(
      elevation: 1,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: borderColor, width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              conflict.conflictType,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              conflict.explanation,
              style: const TextStyle(fontSize: 15),
            ),
            if (conflict.involvedIngredients.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: conflict.involvedIngredients
                    .map((ing) => Chip(
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                          label:
                              Text(ing, style: const TextStyle(fontSize: 13)),
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                        ))
                    .toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // --- 6. Exclusion Recommendation Card ---
  Widget _buildExclusionCard(ExclusionRecommendation rec) {
    final String tierIcon;
    switch (rec.tier) {
      case 1:
        tierIcon = '\u{1F534}'; // 🔴
      case 2:
        tierIcon = '\u{1F7E0}'; // 🟠
      case 3:
        tierIcon = '\u{1F7E1}'; // 🟡
      default:
        tierIcon = '\u{2139}\u{FE0F}'; // ℹ️
    }

    return Card(
      elevation: 1,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(tierIcon, style: const TextStyle(fontSize: 24)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    rec.targetProduct,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    rec.action,
                    style: TextStyle(
                      fontSize: 15,
                      color: Colors.grey.shade700,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    rec.reason,
                    style: const TextStyle(fontSize: 15),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- Helpers ---
  Widget _buildSectionTitle(String text) {
    return Text(
      text,
      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
    );
  }
}
