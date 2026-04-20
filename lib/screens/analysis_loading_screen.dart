import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';

import '../core/service_locator.dart';
import '../models/pet_profile.dart';
import '../models/petcut_analysis_result.dart';
import '../services/gemini_analysis_service.dart';
import '../theme/petcut_tokens.dart';
import 'analysis_result_screen.dart';

/// 네트워크/분석 에러를 구분하기 위한 사설 예외.
class _NetworkException implements Exception {
  final String message;
  const _NetworkException(this.message);
}

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
      // 사전 네트워크 체크 — 비행기 모드/오프라인이면 즉시 에러
      final connectivity = await Connectivity().checkConnectivity();
      if (connectivity == ConnectivityResult.none) {
        throw const _NetworkException('No internet connection');
      }

      // 일부 기기(Samsung One UI 등)는 비행기 모드에서 connectivity_plus가
      // 캐시된 interface 상태를 반환해 .none이 아님. 실제 DNS lookup으로 보강.
      try {
        await InternetAddress.lookup('generativelanguage.googleapis.com')
            .timeout(const Duration(seconds: 3));
      } on SocketException {
        throw const _NetworkException('No internet connection');
      } on TimeoutException {
        throw const _NetworkException('Network timeout');
      }

      final service = getIt<GeminiAnalysisService>();
      final result = await service.analyzeImage(
        widget.imageBytesList,
        petProfile: widget.petProfile,
      );

      if (!mounted) return;
      _navigateToResult(result);
    } on _NetworkException catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'network';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'general';
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
      backgroundColor: PcColors.surface,
      appBar: AppBar(
        title: const Text('Analyzing'),
        centerTitle: true,
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: _loading ? _buildLoading() : _buildError(),
      ),
    );
  }

  // --- DS §7.14 Full-screen Loading State ---
  Widget _buildLoading() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: PcSpace.xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(
              width: 40,
              height: 40,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                valueColor: AlwaysStoppedAnimation(PcColors.brand),
              ),
            ),
            const SizedBox(height: PcSpace.xl),
            const Text('Analyzing...', style: PcText.h2),
            const SizedBox(height: PcSpace.sm),
            Text(
              'Checking food + supplement combos',
              style: PcText.body.copyWith(color: PcColors.textSec),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // --- DS §7.15 Full-screen Error State ---
  Widget _buildError() {
    final isNetwork = _error == 'network';
    final icon = isNetwork ? Icons.wifi_off : Icons.error_outline;
    final title = isNetwork ? 'Connection error' : 'Analysis failed';
    final body = isNetwork
        ? 'Check your internet connection and try again.'
        : 'Something went wrong. Please try again.';

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: PcSpace.xxl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(icon, size: 48, color: PcColors.textTer),
            const SizedBox(height: PcSpace.lg),
            Text(title, style: PcText.h1, textAlign: TextAlign.center),
            const SizedBox(height: PcSpace.sm),
            Text(
              body,
              style: PcText.body.copyWith(color: PcColors.textSec),
              textAlign: TextAlign.center,
              maxLines: 3,
            ),
            const SizedBox(height: PcSpace.xl),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  height: 48,
                  child: FilledButton(
                    onPressed: _runAnalysis,
                    style: FilledButton.styleFrom(
                      backgroundColor: PcColors.ink,
                      foregroundColor: PcColors.surface,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(PcRadius.md),
                      ),
                      padding:
                          const EdgeInsets.symmetric(horizontal: PcSpace.xl),
                      textStyle: const TextStyle(
                        fontFamily: 'Pretendard',
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    child: const Text('Try again'),
                  ),
                ),
                const SizedBox(width: PcSpace.md),
                SizedBox(
                  height: 48,
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      backgroundColor: PcColors.surface,
                      foregroundColor: PcColors.ink,
                      side: const BorderSide(
                        color: PcColors.border,
                        width: 0.5,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(PcRadius.md),
                      ),
                      padding:
                          const EdgeInsets.symmetric(horizontal: PcSpace.xl),
                      textStyle: const TextStyle(
                        fontFamily: 'Pretendard',
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    child: const Text('Back'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
