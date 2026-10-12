// flutter_web_plugins ships with the Flutter SDK and is not a pub package.
// ignore: depend_on_referenced_packages
import 'package:flutter_web_plugins/url_strategy.dart';

/// Invite and app links use `/invite/:token`, not a hash.
void configureUrlStrategy() {
  usePathUrlStrategy();
}
