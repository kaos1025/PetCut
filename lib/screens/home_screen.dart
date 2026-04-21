import 'package:flutter/material.dart';

import '../core/route_observer.dart';
import '../core/service_locator.dart';
import '../models/pet_profile.dart';
import '../models/scan_history_entry.dart';
import '../services/pet_profile_service.dart';
import '../services/scan_history_service.dart';
import '../theme/petcut_tokens.dart';
import 'pet_profile_screen.dart';
import 'scan_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with RouteAware {
  PetProfile? _activeProfile;
  List<ScanHistoryEntry>? _recentScans;

  @override
  void initState() {
    super.initState();
    _loadInitial();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route is PageRoute) {
      routeObserver.subscribe(this, route);
    }
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    super.dispose();
  }

  @override
  void didPopNext() {
    // 다른 route가 pop되어 Home이 다시 top으로 복귀 — Recent 재로드
    _loadRecent();
  }

  Future<void> _loadInitial() async {
    await Future.wait([
      _loadActiveProfile(),
      _loadRecent(),
    ]);
  }

  Future<void> _loadActiveProfile() async {
    final profile = await getIt<PetProfileService>().getActiveProfile();
    if (mounted) setState(() => _activeProfile = profile);
  }

  Future<void> _loadRecent() async {
    final scans = await getIt<ScanHistoryService>().getRecent(3);
    if (!mounted) return;
    setState(() => _recentScans = scans);
  }

  Future<void> _openProfileScreen({PetProfile? existing}) async {
    final result = await Navigator.push<PetProfile>(
      context,
      MaterialPageRoute(
        builder: (_) => PetProfileScreen(existingProfile: existing),
      ),
    );
    if (result != null) _loadActiveProfile();
  }

  Future<void> _openScan() {
    return Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ScanScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('PetCut', style: PcText.h1),
        centerTitle: true,
      ),
      body: SafeArea(
        child: _activeProfile == null ? _buildWelcome() : _buildHome(),
      ),
    );
  }

  // --- 프로필 없음: Welcome ---
  Widget _buildWelcome() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: PcSpace.xxl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.pets, size: 80, color: PcColors.brand),
            const SizedBox(height: PcSpace.lg),
            const Text('Welcome to PetCut', style: PcText.display),
            const SizedBox(height: PcSpace.sm),
            Text(
              'AI Pet Food + Supplement Analyzer',
              style: PcText.body.copyWith(color: PcColors.textSec),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: PcSpace.xxl),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: FilledButton.icon(
                onPressed: () => _openProfileScreen(),
                style: FilledButton.styleFrom(
                  backgroundColor: PcColors.ink,
                  foregroundColor: PcColors.surface,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(PcRadius.md),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: PcSpace.xl,
                    vertical: PcSpace.lg,
                  ),
                  textStyle: const TextStyle(
                    fontFamily: 'Pretendard',
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                icon: const Icon(Icons.add, size: 20),
                label: const Text('Add Your Pet'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- 프로필 있음: Home ---
  Widget _buildHome() {
    final profile = _activeProfile!;
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: PcSpace.lg,
        vertical: PcSpace.lg,
      ),
      child: ListView(
        children: [
          _buildProfileCard(profile),
          const SizedBox(height: PcSpace.xxl),

          _buildHero(),
          const SizedBox(height: PcSpace.xl),

          _buildScanLabelsButton(),

          // 헤더+섹션은 로딩 완료 후에만 동시 등장 (SharedPreferences I/O <50ms)
          if (_recentScans != null) ...[
            const SizedBox(height: PcSpace.xl),
            _buildSectionHeader(),
            const SizedBox(height: PcSpace.sm),
            _buildRecentSection(),
          ],
        ],
      ),
    );
  }

  Widget _buildHero() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const Text(
          'Ready to scan',
          style: PcText.display,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: PcSpace.xs),
        Text(
          'Food + supplements together',
          style: PcText.body.copyWith(color: PcColors.textSec),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildScanLabelsButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: FilledButton.icon(
        onPressed: _openScan,
        style: FilledButton.styleFrom(
          backgroundColor: PcColors.ink,
          foregroundColor: PcColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(PcRadius.md),
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: PcSpace.xl,
            vertical: PcSpace.lg,
          ),
          textStyle: const TextStyle(
            fontFamily: 'Pretendard',
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
        ),
        icon: const Icon(Icons.camera_alt, size: 20),
        label: const Text('Scan Labels'),
      ),
    );
  }

  Widget _buildSectionHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          'RECENT SCANS',
          style: PcText.label.copyWith(color: PcColors.textSec),
        ),
        // TODO(sprint-2): InkWell로 감싸고 전체 History 스크린 네비게이션 연결
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'See all',
              style: PcText.caption.copyWith(
                fontWeight: FontWeight.w500,
                color: PcColors.textTer,
              ),
            ),
            const SizedBox(width: 2),
            const Icon(
              Icons.chevron_right,
              size: 14,
              color: PcColors.textTer,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildRecentSection() {
    final scans = _recentScans;
    if (scans == null) {
      // 로컬 I/O는 매우 빠름, 섹션을 잠깐 숨겼다 나타내는 게 자연스러움
      return const SizedBox.shrink();
    }
    if (scans.isEmpty) return _buildEmptyStateCard();
    return Column(
      children: [
        for (var i = 0; i < scans.length; i++) ...[
          if (i > 0) const SizedBox(height: PcSpace.sm),
          _buildRecentCard(scans[i]),
        ],
      ],
    );
  }

  Widget _buildRecentCard(ScanHistoryEntry entry) {
    final dotColor = switch (entry.overallStatus) {
      'perfect' => PcColors.okAccent,
      'warning' => PcColors.dangerAccent,
      _ => PcColors.warnAccent,
    };

    final title = _formatProductTitle(entry.productNames);
    final timeLabel = _formatRelativeTime(entry.scannedAt);
    final summary = _buildSummaryLabel(
      conflicts: entry.conflictCount,
      cautions: entry.cautionCount,
    );

    return Material(
      color: PcColors.surface,
      shape: RoundedRectangleBorder(
        side: const BorderSide(color: PcColors.border, width: 0.5),
        borderRadius: BorderRadius.circular(PcRadius.md),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(PcRadius.md),
        // TODO(sprint-2): 해당 scan의 Result 스크린 재진입
        onTap: () {},
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: dotColor,
                ),
              ),
              const SizedBox(width: PcSpace.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: PcText.body.copyWith(fontWeight: FontWeight.w500),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$timeLabel · $summary',
                      style: PcText.caption.copyWith(color: PcColors.textSec),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right,
                size: 18,
                color: PcColors.textTer,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyStateCard() {
    return Container(
      decoration: BoxDecoration(
        color: PcColors.surface,
        border: Border.all(color: PcColors.border, width: 0.5),
        borderRadius: BorderRadius.circular(PcRadius.md),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          const Icon(
            Icons.bookmark_add_outlined,
            size: 20,
            color: PcColors.textTer,
          ),
          const SizedBox(width: PcSpace.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Your scans will appear here',
                  style: PcText.body.copyWith(
                    fontWeight: FontWeight.w500,
                    color: PcColors.textSec,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Tap Scan Labels above to start',
                  style: PcText.caption.copyWith(color: PcColors.textTer),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileCard(PetProfile profile) {
    final weightText =
        '${profile.weight.toStringAsFixed(1)} ${profile.weightUnit.displayName}';
    final details = [
      if (profile.breed != null && profile.breed!.isNotEmpty) profile.breed!,
      weightText,
      profile.lifeStage.displayName,
    ].join(' · ');

    return Card(
      elevation: 0,
      color: PcColors.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        side: const BorderSide(color: PcColors.border, width: 0.5),
        borderRadius: BorderRadius.circular(PcRadius.md),
      ),
      margin: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(PcRadius.md),
        onTap: () => _openProfileScreen(existing: profile),
        child: Padding(
          // DS 7.8 spec: 10 (4pt grid 밖 허용 예외)
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: PcColors.brandTint,
                child: const Icon(
                  Icons.pets,
                  size: 24,
                  color: PcColors.brand,
                ),
              ),
              const SizedBox(width: PcSpace.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      profile.name,
                      style: PcText.body.copyWith(fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: PcSpace.xs),
                    Text(
                      details,
                      style: PcText.caption.copyWith(color: PcColors.textSec),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.edit,
                size: 20,
                color: PcColors.textSec,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // === Helpers ===============================================================

  String _formatProductTitle(List<String> names) {
    if (names.isEmpty) return 'Scan';
    if (names.length == 1) return names[0];
    if (names.length == 2) return '${names[0]} + ${names[1]}';
    return '${names[0]} + ${names.length - 1} more';
  }

  String _formatRelativeTime(DateTime when) {
    final now = DateTime.now();
    final sameDay =
        now.year == when.year && now.month == when.month && now.day == when.day;
    if (sameDay) return 'Today';

    final yesterday = now.subtract(const Duration(days: 1));
    final isYesterday = yesterday.year == when.year &&
        yesterday.month == when.month &&
        yesterday.day == when.day;
    if (isYesterday) return 'Yesterday';

    final diff = now.difference(when);
    if (diff.inDays < 30) return '${diff.inDays}d ago';

    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[when.month - 1]} ${when.day}';
  }
  // TODO(sprint-2): 같은 날 여러 스캔이 전부 "Today"로 표시되는 모호성 →
  // "Today 11:23 AM" 형식으로 확장 예정.

  String _buildSummaryLabel({
    required int conflicts,
    required int cautions,
  }) {
    if (conflicts == 0 && cautions == 0) return 'All clear';
    if (conflicts == 0) {
      return '$cautions caution${cautions > 1 ? 's' : ''}';
    }
    if (cautions == 0) {
      return '$conflicts conflict${conflicts > 1 ? 's' : ''}';
    }
    return '$conflicts conflict${conflicts > 1 ? 's' : ''} · '
        '$cautions caution${cautions > 1 ? 's' : ''}';
  }
}
