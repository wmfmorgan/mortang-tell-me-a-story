import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:serverpod_auth_core_flutter/serverpod_auth_core_flutter.dart';

import 'package:tell_me_a_story/core/session/auth_info.dart';
import 'package:tell_me_a_story/core/session/family_selection.dart';
import 'package:tell_me_a_story/core/session/profile_session.dart';

part 'auth_refresh.g.dart';

/// Notifies [GoRouter] when the signed-in user changes.
///
/// [authInfo] is `serverClient.auth.authInfoListenable` in the app. On
/// sign-in it calls [onSignedIn] with the user id; on sign-out [onSignedOut].
class AuthRefresh extends ChangeNotifier {
  AuthRefresh({
    ValueListenable<AuthSuccess?>? authInfo,
    bool? initiallySignedIn,
    this._onSignedIn,
    this._onSignedOut,
  }) : _authInfo = authInfo,
       _signedIn = initiallySignedIn ?? (authInfo?.value != null),
       _signedInThisRun = initiallySignedIn ?? (authInfo?.value != null) {
    final info = authInfo;
    if (info == null) return;
    final current = info.value;
    if (current != null) _bind(current);
    info.addListener(_onAuthInfo);
  }

  final ValueListenable<AuthSuccess?>? _authInfo;
  final void Function(String userId)? _onSignedIn;
  final VoidCallback? _onSignedOut;
  bool _signedIn;
  bool _signedInThisRun;

  bool get isSignedIn => _signedIn;

  /// Whether any user signed in since the app started; a sign-out then must
  /// not carry the old page to the next sign-in.
  bool get signedInThisRun => _signedInThisRun;

  void _onAuthInfo() {
    final info = _authInfo?.value;
    _bind(info);
    final next = info != null;
    if (next != _signedIn) {
      _signedIn = next;
      if (next) _signedInThisRun = true;
      notifyListeners();
    }
  }

  void _bind(AuthSuccess? info) {
    if (info == null) {
      _onSignedOut?.call();
      return;
    }
    _onSignedIn?.call(info.authUserId.toString());
  }

  /// Test helper to flip the session without a server.
  @visibleForTesting
  void setSignedIn(bool value) {
    if (value == _signedIn) return;
    _signedIn = value;
    if (value) _signedInThisRun = true;
    notifyListeners();
  }

  @override
  void dispose() {
    _authInfo?.removeListener(_onAuthInfo);
    super.dispose();
  }
}

/// The router's refresh listenable: binds [ProfileSession] and
/// [FamilySelection] to the signed-in user and clears them on sign-out.
@Riverpod(keepAlive: true)
AuthRefresh authRefresh(Ref ref) {
  final refresh = AuthRefresh(
    authInfo: ref.watch(authInfoProvider),
    onSignedIn: (userId) {
      ref.read(profileSessionProvider.notifier).bindUser(userId);
      ref.read(familySelectionProvider.notifier).bindUser(userId);
    },
    onSignedOut: () {
      ref.read(familySelectionProvider.notifier).clear();
      ref.read(profileSessionProvider.notifier).clear();
    },
  );
  ref.onDispose(refresh.dispose);
  return refresh;
}
