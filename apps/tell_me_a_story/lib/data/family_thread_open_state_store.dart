import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'current_session.dart';
import 'family_thread_open_state.dart';
import 'uuid.dart';

class FamilyThreadOpenStateStore {
  FamilyThreadOpenStateStore({
    Future<SharedPreferences> Function()? preferences,
    String? Function()? currentUserId,
  }) : _preferences = preferences ?? SharedPreferences.getInstance,
       _currentUserId = currentUserId ?? (() => CurrentSession.userId);

  static const keyPrefix = 'family_thread.v1.';

  final Future<SharedPreferences> Function() _preferences;
  final String? Function() _currentUserId;

  Future<FamilyThreadOpenState?> read({required String familyId}) {
    return _use(familyId, (prefs, key) async {
      final raw = prefs.getString(key);
      if (raw == null) return null;
      return FamilyThreadOpenState.tryDecode(raw);
    });
  }

  Future<void> write({
    required String familyId,
    required FamilyThreadOpenState state,
  }) async {
    await _use(familyId, (prefs, key) async {
      await prefs.setString(key, state.encode());
      return null;
    });
  }

  Future<void> remove({required String familyId}) async {
    await _use(familyId, (prefs, key) async {
      await prefs.remove(key);
      return null;
    });
  }

  Future<T?> _use<T>(
    String familyId,
    Future<T?> Function(SharedPreferences prefs, String key) body,
  ) async {
    final key = _key(familyId);
    if (key == null) return null;
    try {
      return await body(await _preferences(), key);
    } on PlatformException {
      return null;
    } on FormatException {
      return null; // Spec O-01: catch FormatException by name.
    }
  }

  String? _key(String familyId) {
    final userId = _currentUserId();
    if (userId == null || !isUuid(userId)) return null;
    if (!isUuid(familyId)) return null;
    return '$keyPrefix$userId.$familyId';
  }
}
