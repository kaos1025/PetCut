import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../core/service_locator.dart';
import '../services/pet_profile_service.dart';
import 'analysis_loading_screen.dart';
import 'pet_profile_screen.dart';

/// 사료/보충제 라벨 사진 촬영 및 선택 화면
class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  static const _maxImages = 5;
  final _picker = ImagePicker();
  final List<Uint8List> _images = [];

  Future<void> _pickImage(ImageSource source) async {
    if (_images.length >= _maxImages) {
      _showSnackBar('Maximum $_maxImages images allowed');
      return;
    }

    try {
      if (source == ImageSource.gallery) {
        final picks = await _picker.pickMultiImage(imageQuality: 85);
        final remaining = _maxImages - _images.length;
        final toAdd = picks.take(remaining);
        for (final pick in toAdd) {
          final bytes = await pick.readAsBytes();
          _images.add(bytes);
        }
      } else {
        final pick = await _picker.pickImage(
          source: source,
          imageQuality: 85,
        );
        if (pick == null) return;
        final bytes = await pick.readAsBytes();
        _images.add(bytes);
      }
      setState(() {});
    } catch (e) {
      _showSnackBar('Failed to pick image: $e');
    }
  }

  void _removeImage(int index) {
    setState(() => _images.removeAt(index));
  }

  Future<void> _analyze() async {
    final profile = await getIt<PetProfileService>().getActiveProfile();

    if (!mounted) return;

    if (profile == null) {
      _showSnackBar('Add your pet first');
      final result = await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const PetProfileScreen()),
      );
      if (result != null && mounted) {
        // 프로필 생성 후 다시 analyze 시도
        _analyze();
      }
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AnalysisLoadingScreen(
          imageBytesList: List.unmodifiable(_images),
          petProfile: profile,
        ),
      ),
    );
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan Labels'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            children: [
              // --- Pick buttons ---
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 56,
                      child: OutlinedButton.icon(
                        onPressed: () => _pickImage(ImageSource.camera),
                        icon: const Icon(Icons.camera_alt, size: 24),
                        label: const Text(
                          'Take Photo',
                          style: TextStyle(fontSize: 16),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: SizedBox(
                      height: 56,
                      child: OutlinedButton.icon(
                        onPressed: () => _pickImage(ImageSource.gallery),
                        icon: const Icon(Icons.photo_library, size: 24),
                        label: const Text(
                          'Gallery',
                          style: TextStyle(fontSize: 16),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '${_images.length} / $_maxImages images',
                style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 16),

              // --- Image thumbnails ---
              Expanded(
                child: _images.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.add_photo_alternate,
                                size: 64, color: Colors.grey.shade300),
                            const SizedBox(height: 12),
                            Text(
                              'Add photos of pet food or\nsupplement labels',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey.shade500,
                              ),
                            ),
                          ],
                        ),
                      )
                    : GridView.builder(
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          crossAxisSpacing: 8,
                          mainAxisSpacing: 8,
                        ),
                        itemCount: _images.length,
                        itemBuilder: (context, index) {
                          return Stack(
                            fit: StackFit.expand,
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.memory(
                                  _images[index],
                                  fit: BoxFit.cover,
                                ),
                              ),
                              Positioned(
                                top: 4,
                                right: 4,
                                child: GestureDetector(
                                  onTap: () => _removeImage(index),
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: const BoxDecoration(
                                      color: Colors.black54,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.close,
                                      size: 18,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
              ),
              const SizedBox(height: 16),

              // --- Analyze button ---
              SizedBox(
                width: double.infinity,
                height: 56,
                child: FilledButton.icon(
                  onPressed: _images.isNotEmpty ? _analyze : null,
                  icon: const Icon(Icons.science, size: 24),
                  label: const Text(
                    'Analyze',
                    style: TextStyle(fontSize: 18),
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}
