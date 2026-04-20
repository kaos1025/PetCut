import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../core/service_locator.dart';
import '../models/pet_profile.dart';
import '../models/petcut_analysis_result.dart';
import '../services/gemini_analysis_service.dart';
import 'analysis_result_screen.dart';

/// Gemini 분석 로딩 화면
class AnalysisLoadingScreen extends StatefulWidget {
  final List<Uint8List> imageBytesList;
  final PetProfile petProfile;

  const AnalysisLoadingScreen({
    super.key,
    required this.imageBytesList,
    required this.petProfile,
  });

  @override
  State<AnalysisLoadingScreen> createState() => _AnalysisLoadingScreenState();
}

class _AnalysisLoadingScreenState extends State<AnalysisLoadingScreen> {
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _runAnalysis();
  }

  Future<void> _runAnalysis() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final service = getIt<GeminiAnalysisService>();
      final result = await service.analyzeImage(
        widget.imageBytesList,
        petProfile: widget.petProfile,
      );

      if (!mounted) return;

      _navigateToResult(result);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  void _navigateToResult(PetcutAnalysisResult result) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => AnalysisResultScreen(
          result: result,
          petProfile: widget.petProfile,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Analyzing'),
        centerTitle: true,
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: _loading ? _buildLoading() : _buildError(),
          ),
        ),
      ),
    );
  }

  Widget _buildLoading() {
    return const Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        CircularProgressIndicator(),
        SizedBox(height: 24),
        Text(
          'Analyzing your pet\'s nutrition...',
          style: TextStyle(fontSize: 18),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildError() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.error_outline, size: 64, color: Colors.red.shade300),
        const SizedBox(height: 16),
        const Text(
          'Analysis Failed',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          _error ?? 'Unknown error',
          style: TextStyle(fontSize: 15, color: Colors.grey.shade600),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 32),
        SizedBox(
          width: double.infinity,
          height: 56,
          child: FilledButton.icon(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back, size: 24),
            label: const Text(
              'Try Again',
              style: TextStyle(fontSize: 18),
            ),
          ),
        ),
      ],
    );
  }
}
