import 'package:serverpod/serverpod.dart';

/// Whether [pod] runs as a local developer or test server.
///
/// See [isLocalConfig].
bool isLocalPod(Serverpod pod) => isLocalConfig(pod.config);

/// Whether [config] describes a local developer or test server: run mode
/// development or test AND an embedded Postgres (`database.dataPath` set).
///
/// Only a local server may use the fixed dev login code and log login codes
/// instead of emailing them. Requiring the embedded database means a
/// misconfigured run mode against a real database still fails closed.
bool isLocalConfig(ServerpodConfig config) {
  final mode = config.runMode;
  if (mode != ServerpodRunMode.development && mode != ServerpodRunMode.test) {
    return false;
  }
  final database = config.database;
  final dataPath = database is PostgresDatabaseConfig
      ? database.dataPath?.trim()
      : null;
  return dataPath != null && dataPath.isNotEmpty;
}
