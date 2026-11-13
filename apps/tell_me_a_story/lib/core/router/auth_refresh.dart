import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/family_selection.dart';
import '../../data/profile_session.dart';

/// Notifies [GoRouter] when auth session changes.
class AuthRefresh extends ChangeNotifier {
  AuthRefresh({Stream<AuthState>? authStateChanges, bool? initiallySignedIn})
    : _signedIn = initiallySignedIn ?? false {
    if (authStateChanges != null) {
      _subscription = authStateChanges.listen((state) {
        final next = state.session != null;
        if (!next) {
          FamilySelection.clear();
          ProfileSession.instance.clear();
        }
        if (next != _signedIn) {
          _signedIn = next;
          notifyListeners();
        }
      });
    }
  }

  StreamSubscription<AuthState>? _subscription;
  bool _signedIn;

  bool get isSignedIn => _signedIn;

  /// Test helper to flip session without Supabase.
  @visibleForTesting
  void setSignedIn(bool value) {
    if (value == _signedIn) return;
    _signedIn = value;
    notifyListeners();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
