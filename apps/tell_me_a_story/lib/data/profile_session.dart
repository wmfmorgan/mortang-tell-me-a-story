import 'dart:typed_data';

import 'package:flutter/foundation.dart';

import 'package:tell_me_a_story/data/profile_api.dart';

/// Process memory for the signed-in profile. Not kept across a restart.
class ProfileSession extends ChangeNotifier {
  ProfileSession._();

  static final ProfileSession instance = ProfileSession._();

  /// Set from `main` after the server client starts. Tests leave this null.
  static Future<OwnProfile?> Function()? loadOwn;

  /// Set from `main`. Downloads `{uid}/avatar.jpg` when a path is stored.
  static Future<Uint8List?> Function(String path)? downloadAvatar;

  String? _userId;
  String? displayName;
  String? email;
  Uint8List? avatarBytes;
  Future<void>? _loading;
  var _loaded = false;

  /// True once the signed-in user's profile loaded successfully.
  bool get loaded => _loaded;

  /// A different signed-in user drops the previous profile. Any load made
  /// before this user was bound (for example while signed out) no longer
  /// counts.
  void bindUser(String userId) {
    if (_userId == userId) return;
    if (_userId != null) clear();
    _loading = null;
    _loaded = false;
    _userId = userId;
  }

  void clear() {
    _userId = null;
    displayName = null;
    email = null;
    avatarBytes = null;
    _loading = null;
    _loaded = false;
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

  /// Loads once per signed-in user; concurrent callers share one request.
  /// A null [loadOwn] does nothing.
  Future<void> ensureLoaded() {
    final loader = loadOwn;
    if (loader == null) return Future<void>.value();
    return _loading ??= _load(loader);
  }

  Future<void> _load(Future<OwnProfile?> Function() loader) async {
    final userId = _userId;
    try {
      final profile = await loader();
      if (_userId != userId) return;
      if (profile == null) return;
      Uint8List? bytes;
      final path = profile.avatarPath;
      final download = downloadAvatar;
      if (path != null && download != null) {
        bytes = await download(path);
        if (_userId != userId) return;
      }
      displayName = profile.displayName;
      email = profile.email;
      avatarBytes = bytes;
      _loaded = true;
      notifyListeners();
    } catch (_) {
      // Not loaded: the header shows initials and the welcome gate stays
      // open; the next call retries.
      if (_userId == userId) _loading = null;
    }
  }
}
