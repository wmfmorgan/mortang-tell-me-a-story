import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:tell_me_a_story/core/server/app_session.dart';

part 'app_session_provider.g.dart';

/// Who is signed in, and how to sign out. Tests override it with a fake
/// [AppSession]; the app uses the Serverpod-backed session.
@Riverpod(keepAlive: true)
AppSession appSession(Ref ref) => const ServerAppSession();
