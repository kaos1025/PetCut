import 'package:flutter/material.dart';

import '../core/service_locator.dart';
import '../models/pet_profile.dart';
import '../services/pet_profile_service.dart';
import 'pet_profile_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  PetProfile? _activeProfile;

  @override
  void initState() {
    super.initState();
    _loadActiveProfile();
  }

  void _loadActiveProfile() {
    setState(() {
      _activeProfile = getIt<PetProfileService>().getActiveProfile();
    });
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('PetCut'),
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
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.pets, size: 80, color: Colors.green),
            const SizedBox(height: 16),
            const Text(
              'Welcome to PetCut',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'AI Pet Food + Supplement Analyzer',
              style: TextStyle(fontSize: 16, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: FilledButton.icon(
                onPressed: () => _openProfileScreen(),
                icon: const Icon(Icons.add, size: 24),
                label: const Text(
                  'Add Your Pet',
                  style: TextStyle(fontSize: 18),
                ),
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
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        children: [
          // 펫 프로필 카드
          _buildProfileCard(profile),
          const SizedBox(height: 32),

          // Scan Labels 버튼
          SizedBox(
            width: double.infinity,
            height: 56,
            child: FilledButton.icon(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Coming in Sprint 1')),
                );
              },
              icon: const Icon(Icons.camera_alt, size: 24),
              label: const Text(
                'Scan Labels',
                style: TextStyle(fontSize: 18),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileCard(PetProfile profile) {
    final speciesIcon =
        profile.species == Species.dog ? Icons.pets : Icons.pets;
    final weightText =
        '${profile.weight.toStringAsFixed(1)} ${profile.weightUnit.displayName}';
    final details = [
      if (profile.breed != null && profile.breed!.isNotEmpty) profile.breed!,
      weightText,
      profile.lifeStage.displayName,
    ].join(' · ');

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _openProfileScreen(existing: profile),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: Colors.green.shade50,
                child: Icon(speciesIcon, size: 28, color: Colors.green),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      profile.name,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      details,
                      style: TextStyle(
                        fontSize: 15,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.edit_outlined, color: Colors.grey.shade400),
            ],
          ),
        ),
      ),
    );
  }
}
