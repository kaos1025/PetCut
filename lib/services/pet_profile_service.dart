import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/pet_profile.dart';

/// SharedPreferences 기반 펫 프로필 CRUD + 활성 프로필 관리
class PetProfileService {
  static const _profilesKey = 'pet_profiles';
  static const _activeProfileIdKey = 'active_pet_profile_id';

  final SharedPreferences _prefs;

  PetProfileService(this._prefs);

  /// 저장된 모든 프로필 조회
  List<PetProfile> getAllProfiles() {
    final raw = _prefs.getString(_profilesKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((e) => PetProfile.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// 프로필 저장 (신규 추가 or 기존 업데이트, id로 판별)
  Future<void> saveProfile(PetProfile profile) async {
    final profiles = getAllProfiles();
    final index = profiles.indexWhere((p) => p.id == profile.id);

    if (index >= 0) {
      profiles[index] = profile;
    } else {
      profiles.add(profile);
    }

    await _persistProfiles(profiles);

    // 첫 프로필 저장 시 자동으로 active 설정
    if (profiles.length == 1) {
      await setActiveProfileId(profile.id);
    }
  }

  /// 프로필 삭제
  Future<void> deleteProfile(String id) async {
    final profiles = getAllProfiles();
    profiles.removeWhere((p) => p.id == id);
    await _persistProfiles(profiles);

    // 삭제된 프로필이 active였으면 첫 번째 프로필로 교체 (없으면 해제)
    if (getActiveProfileId() == id) {
      final newActiveId = profiles.isNotEmpty ? profiles.first.id : null;
      if (newActiveId != null) {
        await setActiveProfileId(newActiveId);
      } else {
        await _prefs.remove(_activeProfileIdKey);
      }
    }
  }

  /// 현재 분석에 사용할 활성 프로필 조회
  PetProfile? getActiveProfile() {
    final activeId = getActiveProfileId();
    if (activeId == null) return null;
    final profiles = getAllProfiles();
    try {
      return profiles.firstWhere((p) => p.id == activeId);
    } catch (_) {
      return null;
    }
  }

  /// 활성 프로필 ID 조회
  String? getActiveProfileId() {
    return _prefs.getString(_activeProfileIdKey);
  }

  /// 활성 프로필 ID 설정
  Future<void> setActiveProfileId(String id) async {
    await _prefs.setString(_activeProfileIdKey, id);
  }

  /// 프로필 리스트를 JSON 문자열로 저장
  Future<void> _persistProfiles(List<PetProfile> profiles) async {
    final json = jsonEncode(profiles.map((p) => p.toJson()).toList());
    await _prefs.setString(_profilesKey, json);
  }
}
