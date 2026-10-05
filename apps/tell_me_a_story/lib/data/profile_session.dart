import 'dart:typed_data';

import 'package:flutter/foundation.dart';

import 'profile_api.dart';

/// Process memory for the signed-in profile. Not kept across a restart.
class ProfileSession extends ChangeNotifier {
  ProfileSession._();

  static final ProfileSession instance = ProfileSession._();

  /// Set from `main` after Supabase starts. Tests leave this null.
  static Future<OwnProfile?> Function()? loadOwn;

  /// Set from `main`. Downloads `{uid}/avatar.jpg` when a path is stored.
  static Future<Uint8List?> Function(String path)? downloadAvatar;

  String? _userId;
  String? displayName;
  String? email;
  Uint8List? avatarBytes;
  var _started = false;

  /// A different signed-in user drops the previous profile.
  void bindUser(String userId) {
    if (_userId != null && _userId != userId) {
      clear();
    }
    _userId = userId;
  }

  void clear() {
    _userId = null;
    displayName = null;
    email = null;
    avatarBytes = null;
    _started = false;
    notifyListeners();
  }

  void apply({
    String? displayName,
    String? email,
    Uint8List? avatarBytes,
    bool keepAvatar = false,
  }) {
    this.displayName = displayName;
    this.email = email;
    if (!keepAvatar) this.avatarBytes = avatarBytes;
    notifyListeners();
  }

  /// Loads once per signed-in user. A null [loadOwn] does nothing.
  Future<void> ensureLoaded() async {
    final loader = loadOwn;
    if (_started || loader == null) return;
    _started = true;
    try {
      final profile = await loader();
      if (profile == null) return;
      Uint8List? bytes;
      final path = profile.avatarPath;
      final download = downloadAvatar;
      if (path != null && download != null) {
        bytes = await download(path);
      }
      displayName = profile.displayName;
      email = profile.email;
      avatarBytes = bytes;
      notifyListeners();
    } catch (_) {
      _started = false;
    }
  }
}
