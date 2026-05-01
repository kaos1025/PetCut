// PetCut — paid Claude report screen.
// ----------------------------------------------------------------------------
// Sprint 2 Chunk 7b. Renders the five-section ClaudeReportResponse as a
// scrollable list of DS v0.4 §7.1 cards. v1 keeps the per-section render
// pragmatic: every section card surfaces `title` + the most readable
// summary text the section model exposes (intro / body / closing).
// Severity coloring is applied to the top-level overall status banner
// only — per-section severity surfaces (alertCards, riskSections,
// triageBanner.tier) are not yet exploded into UI in this chunk.
// ----------------------------------------------------------------------------

import 'package:flutter/material.dart';

import '../models/claude_report_response.dart';
import '../models/pet_profile.dart';
import '../models/petcut_analysis_result.dart';
import '../theme/petcut_tokens.dart';

class PaidReportScreen extends StatelessWidget {
  final ClaudeReportResponse report;
  final PetProfile petProfile;
  final PetcutAnalysisResult analysisResult;

  const PaidReportScreen({
    super.key,
    required this.report,
    required this.petProfile,
    required this.analysisResult,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PcColors.surface2,
      appBar: AppBar(
        backgroundColor: PcColors.surface,
        elevation: 0,
        foregroundColor: PcColors.ink,
        title: const Text('Detailed Report', style: PcText.h2),
        centerTitle: true,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(PcSpace.lg),
          children: [
            _buildStatusBanner(analysisResult.overallStatus),
            const SizedBox(height: PcSpace.lg),
            _buildPetProfileCard(petProfile),
            const SizedBox(height: PcSpace.lg),
            _buildSection1Card(report.section1),
            const SizedBox(height: PcSpace.md),
            _buildSection2Card(report.section2),
            const SizedBox(height: PcSpace.md),
            _buildSection3Card(report.section3),
            const SizedBox(height: PcSpace.md),
            _buildSection4Card(report.section4),
            const SizedBox(height: PcSpace.md),
            _buildSection5Card(report.section5),
            const SizedBox(height: PcSpace.xl),
            _buildDisclaimerFooter(),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBanner(String status) {
    final Color bg;
    final Color accent;
    final Color text;
    final IconData icon;
    final String label;
    switch (status) {
      case 'perfect':
        bg = PcColors.okBg;
        accent = PcColors.okAccent;
        text = PcColors.okText;
        icon = Icons.check_circle;
        label = 'All Clear';
      case 'warning':
        bg = PcColors.dangerBg;
        accent = PcColors.dangerAccent;
        text = PcColors.dangerText;
        icon = Icons.error;
        label = 'Warning';
      default:
        bg = PcColors.warnBg;
        accent = PcColors.warnAccent;
        text = PcColors.warnText;
        icon = Icons.warning;
        label = 'Caution';
    }

    return Container(
      padding: const EdgeInsets.all(PcSpace.lg),
      decoration: BoxDecoration(
        color: bg,
        border: Border.all(color: accent),
        borderRadius: BorderRadius.circular(PcRadius.md),
      ),
      child: Row(
        children: [
          Icon(icon, color: accent, size: 28),
          const SizedBox(width: PcSpace.md),
          Text(label, style: PcText.h2.copyWith(color: text)),
        ],
      ),
    );
  }

  Widget _buildPetProfileCard(PetProfile pet) {
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

  Widget _sectionCard({required String title, required String body}) {
    return Container(
      padding: const EdgeInsets.all(PcSpace.lg),
      decoration: BoxDecoration(
        color: PcColors.surface,
        border: Border.all(color: PcColors.border),
        borderRadius: BorderRadius.circular(PcRadius.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: PcText.h2.copyWith(color: PcColors.ink)),
          const SizedBox(height: PcSpace.md),
          Text(body, style: PcText.body.copyWith(color: PcColors.ink)),
        ],
      ),
    );
  }

  Widget _buildSection1Card(Section1Output s) {
    final body = '${s.petSummaryLine}\n\n${s.body}';
    return _sectionCard(title: s.title, body: body);
  }

  Widget _buildSection2Card(Section2Output s) {
    final body = '${s.intro}\n\n${s.headline.statement}\n${s.headline.detail}'
        '\n\n${s.closing}';
    return _sectionCard(title: s.title, body: body);
  }

  Widget _buildSection3Card(Section3Output s) {
    final body = '${s.intro}\n\n${s.headline.statement}\n${s.headline.detail}'
        '\n\n${s.closing}';
    return _sectionCard(title: s.title, body: body);
  }

  Widget _buildSection4Card(Section4Output s) {
    final body = '${s.intro}\n\n${s.closing}';
    return _sectionCard(title: s.title, body: body);
  }

  Widget _buildSection5Card(Section5Output s) {
    final body = '${s.intro}\n\n'
        '${s.triageBanner.tierDisplay} — ${s.triageBanner.statement}\n\n'
        '${s.closing}';
    return _sectionCard(title: s.title, body: body);
  }

  Widget _buildDisclaimerFooter() {
    return Text(
      'This is informational only. Consult your veterinarian.',
      style: PcText.caption.copyWith(color: PcColors.textSec),
      textAlign: TextAlign.center,
    );
  }
}
