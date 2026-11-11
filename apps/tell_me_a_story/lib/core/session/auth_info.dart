import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:serverpod_auth_core_flutter/serverpod_auth_core_flutter.dart';

part 'auth_info.g.dart';

/// The signed-in session. Overridden in `main.dart` with
/// `serverClient.auth.authInfoListenable`; null without a server.
@Riverpod(keepAlive: true)
ValueListenable<AuthSuccess?>? authInfo(Ref ref) => null;
