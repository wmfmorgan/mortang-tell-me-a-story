import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:tell_me_a_story/core/domain/app_exception.dart';
import 'package:tell_me_a_story/core/domain/profile_repository.dart';
import 'package:tell_me_a_story/core/session/profile_state.dart';

part 'profile_session.g.dart';

/// Process memory for the signed-in profile. Not kept across a restart.
@Riverpod(keepAlive: true)
class ProfileSession extends _$ProfileSession {
  String? _userId;
  var _started = false;

  @override
  ProfileState build() => const ProfileState();

  /// A different signed-in user drops the previous profile.
  void bindUser(String userId) {
    if (_userId != null && _userId != userId) {
      clear();
    }
    _userId = userId;
  }

  void clear() {
    _userId = null;
    _started = false;
    state = const ProfileState();
  }

  void apply({
    String? displayName,
    String? email,
    Uint8List? avatarBytes,
    bool keepAvatar = false,
  }) {
    state = ProfileState(
      displayName: displayName,
      email: email,
      avatarBytes: keepAvatar ? state.avatarBytes : avatarBytes,
    );
  }

  /// Loads once per signed-in user. A failed load is reported and retried
  /// on the next call.
  Future<void> ensureLoaded() async {
    if (_started) return;
    _started = true;
    final repository = ref.read(profileRepositoryProvider);
    try {
      final profile = await repository.loadOwn();
      if (profile == null) {
        _started = false;
        return;
      }
      if (!ref.mounted) return;
      final path = profile.avatarPath;
      final bytes = path == null ? null : await repository.downloadAvatar(path);
      if (!ref.mounted) return;
      state = ProfileState(
        displayName: profile.displayName,
        email: profile.email,
        avatarBytes: bytes,
      );
    } on AppException catch (error, stack) {
      _started = false;
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stack,
          library: 'profile session',
          context: ErrorDescription('while loading the signed-in profile'),
        ),
      );
    }
  }
}
