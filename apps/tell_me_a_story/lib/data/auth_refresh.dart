import 'package:flutter/foundation.dart';
import 'package:serverpod_auth_core_flutter/serverpod_auth_core_flutter.dart';

import 'package:tell_me_a_story/data/family_selection.dart';
import 'package:tell_me_a_story/data/profile_session.dart';

/// Notifies [GoRouter] when the signed-in user changes.
///
/// [authInfo] is `serverClient.auth.authInfoListenable` in the app. On
/// sign-in it binds [ProfileSession] and [FamilySelection] to the user; on
/// sign-out it clears them.
class AuthRefresh extends ChangeNotifier {
  AuthRefresh({
    ValueListenable<AuthSuccess?>? authInfo,
    bool? initiallySignedIn,
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
  bool _signedIn;
  bool _signedInThisRun;

  bool get isSignedIn => _signedIn;

  /// Whether any user signed in since the app started; a sign-out then must
  /// not carry the old page to the next sign-in.
  bool get signedInThisRun => _signedInThisRun;

  void _onAuthInfo() {
    final info = _authInfo!.value;
    _bind(info);
    final next = info != null;
    if (next != _signedIn) {
      _signedIn = next;
      if (next) _signedInThisRun = true;
      notifyListeners();
    }
  }

  static void _bind(AuthSuccess? info) {
    if (info == null) {
      FamilySelection.clear();
      ProfileSession.instance.clear();
      return;
    }
    final userId = info.authUserId.toString();
    ProfileSession.instance.bindUser(userId);
    FamilySelection.bindUser(userId);
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
