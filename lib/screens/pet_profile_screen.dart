import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/service_locator.dart';
import '../models/pet_profile.dart';
import '../services/pet_profile_service.dart';
import '../utils/life_stage_calculator.dart';

/// 펫 프로필 입력/편집 화면
/// 신규: PetProfileScreen()
/// 편집: PetProfileScreen(existingProfile: profile)
class PetProfileScreen extends StatefulWidget {
  final PetProfile? existingProfile;

  const PetProfileScreen({super.key, this.existingProfile});

  @override
  State<PetProfileScreen> createState() => _PetProfileScreenState();
}

class _PetProfileScreenState extends State<PetProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _breedController = TextEditingController();
  final _weightController = TextEditingController();
  final _ageController = TextEditingController();

  Species _species = Species.dog;
  WeightUnit _weightUnit = WeightUnit.lbs;
  LifeStage? _lifeStage;
  bool _lifeStageManuallySet = false;
  bool _saving = false;

  bool get _isEditing => widget.existingProfile != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      final p = widget.existingProfile!;
      _nameController.text = p.name;
      _breedController.text = p.breed ?? '';
      _weightController.text = p.weight > 0 ? p.weight.toString() : '';
      _ageController.text =
          p.ageYears != null ? p.ageYears!.toStringAsFixed(1) : '';
      _species = p.species;
      _weightUnit = p.weightUnit;
      _lifeStage = p.lifeStage;
    } else {
      _recalculateLifeStage();
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _breedController.dispose();
    _weightController.dispose();
    _ageController.dispose();
    super.dispose();
  }

  double? get _parsedWeight {
    final text = _weightController.text.trim();
    if (text.isEmpty) return null;
    return double.tryParse(text);
  }

  double? get _parsedAge {
    final text = _ageController.text.trim();
    if (text.isEmpty) return null;
    return double.tryParse(text);
  }

  double? get _weightKg {
    final w = _parsedWeight;
    if (w == null) return null;
    return _weightUnit == WeightUnit.lbs ? w * 0.453592 : w;
  }

  bool get _isLargeBreed =>
      _species == Species.dog &&
      (_weightKg ?? 0) >= LifeStageCalculator.largeBreedThresholdKg;

  void _recalculateLifeStage() {
    if (_lifeStageManuallySet) return;
    setState(() {
      _lifeStage = LifeStageCalculator.calculate(
        species: _species,
        ageYears: _parsedAge,
        weightKg: _weightKg,
      );
    });
  }

  void _onSpeciesChanged(Species species) {
    setState(() {
      _species = species;
      _lifeStageManuallySet = false;
    });
    _recalculateLifeStage();
  }

  void _onWeightUnitChanged(WeightUnit unit) {
    setState(() {
      _weightUnit = unit;
    });
    _recalculateLifeStage();
  }

  void _onLifeStageSelected(LifeStage stage) {
    setState(() {
      _lifeStage = stage;
      _lifeStageManuallySet = true;
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);

    try {
      final profile = PetProfile(
        id: widget.existingProfile?.id,
        name: _nameController.text.trim(),
        species: _species,
        breed: _breedController.text.trim().isEmpty
            ? null
            : _breedController.text.trim(),
        weight: _parsedWeight ?? 0,
        weightUnit: _weightUnit,
        ageYears: _parsedAge,
        lifeStage: _lifeStage,
        createdAt: widget.existingProfile?.createdAt,
      );

      final service = getIt<PetProfileService>();
      await service.saveProfile(profile);

      if (mounted) Navigator.pop(context, profile);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save profile: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Pet Profile' : 'New Pet Profile'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            children: [
              // --- Pet Name ---
              _buildSectionLabel('Pet Name'),
              const SizedBox(height: 8),
              TextFormField(
                controller: _nameController,
                style: const TextStyle(fontSize: 18),
                decoration: const InputDecoration(
                  hintText: 'e.g. Buddy',
                  border: OutlineInputBorder(),
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                ),
                textCapitalization: TextCapitalization.words,
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Name is required' : null,
              ),
              const SizedBox(height: 24),

              // --- Species ---
              _buildSectionLabel('Species'),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: SegmentedButton<Species>(
                  segments: const [
                    ButtonSegment(
                      value: Species.dog,
                      label: Text('Dog', style: TextStyle(fontSize: 18)),
                      icon: Icon(Icons.pets),
                    ),
                    ButtonSegment(
                      value: Species.cat,
                      label: Text('Cat', style: TextStyle(fontSize: 18)),
                      icon: Icon(Icons.pets),
                    ),
                  ],
                  selected: {_species},
                  onSelectionChanged: (s) => _onSpeciesChanged(s.first),
                  style: ButtonStyle(
                    minimumSize:
                        WidgetStatePropertyAll(const Size(0, 52)),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // --- Breed ---
              _buildSectionLabel('Breed (optional)'),
              const SizedBox(height: 8),
              TextFormField(
                controller: _breedController,
                style: const TextStyle(fontSize: 18),
                decoration: const InputDecoration(
                  hintText: 'e.g. Golden Retriever',
                  border: OutlineInputBorder(),
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                ),
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 24),

              // --- Weight ---
              _buildSectionLabel('Weight'),
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 3,
                    child: TextFormField(
                      controller: _weightController,
                      style: const TextStyle(fontSize: 18),
                      decoration: const InputDecoration(
                        hintText: '0.0',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(
                            horizontal: 16, vertical: 16),
                      ),
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                            RegExp(r'^\d*\.?\d*')),
                      ],
                      onChanged: (_) => _recalculateLifeStage(),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return 'Required';
                        }
                        final n = double.tryParse(v.trim());
                        if (n == null || n <= 0) return 'Invalid weight';
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: SegmentedButton<WeightUnit>(
                      segments: const [
                        ButtonSegment(
                          value: WeightUnit.lbs,
                          label: Text('lbs', style: TextStyle(fontSize: 16)),
                        ),
                        ButtonSegment(
                          value: WeightUnit.kg,
                          label: Text('kg', style: TextStyle(fontSize: 16)),
                        ),
                      ],
                      selected: {_weightUnit},
                      onSelectionChanged: (s) => _onWeightUnitChanged(s.first),
                      style: ButtonStyle(
                        minimumSize:
                            WidgetStatePropertyAll(const Size(0, 52)),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // --- Large Breed Banner ---
              if (_isLargeBreed) ...[
                Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade50,
                    border: Border.all(color: Colors.amber.shade700),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.warning_amber_rounded,
                          color: Colors.amber.shade800, size: 24),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'Large breed detected. Stricter calcium limits will be applied.',
                          style: TextStyle(fontSize: 15),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
              ],

              // --- Age ---
              _buildSectionLabel('Age (years)'),
              const SizedBox(height: 8),
              TextFormField(
                controller: _ageController,
                style: const TextStyle(fontSize: 18),
                decoration: const InputDecoration(
                  hintText: 'e.g. 3.5',
                  border: OutlineInputBorder(),
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                ),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                ],
                onChanged: (_) => _recalculateLifeStage(),
              ),
              const SizedBox(height: 24),

              // --- Life Stage ---
              _buildSectionLabel('Life Stage'),
              const SizedBox(height: 4),
              Text(
                _lifeStageManuallySet
                    ? 'Manually selected'
                    : 'Auto-calculated (tap to override)',
                style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 10,
                children: LifeStage.forSpecies(_species).map((stage) {
                  final selected = _lifeStage == stage;
                  return ChoiceChip(
                    label: Text(
                      stage.displayName,
                      style: TextStyle(
                        fontSize: 16,
                        color: selected ? Colors.white : null,
                      ),
                    ),
                    selected: selected,
                    onSelected: (_) => _onLifeStageSelected(stage),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                  );
                }).toList(),
              ),
              const SizedBox(height: 32),

              // --- Save Button ---
              SizedBox(
                width: double.infinity,
                height: 56,
                child: FilledButton(
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          _isEditing ? 'Update Profile' : 'Save Profile',
                          style: const TextStyle(fontSize: 18),
                        ),
                ),
              ),
              const SizedBox(height: 24),

              // --- Disclaimer ---
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

  Widget _buildSectionLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}
