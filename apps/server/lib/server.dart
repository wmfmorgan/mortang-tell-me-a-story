import 'src/auth/auth_config.dart';
import 'src/auth/local_mode.dart';
import 'src/db/constraints.dart';
import 'src/future_calls/schedule.dart';
import 'src/generated/serverpod.dart';

/// The starting point of the Serverpod server.
void run(List<String> args) async {
  final pod = Serverpod(args);

  final local = isLocalPod(pod);
  if (!local &&
      (pod.getPassword('resendApiKey') == null ||
          pod.getPassword('resendFrom') == null)) {
    throw StateError(
      'resendApiKey and resendFrom must be set in config/passwords.yaml '
      '(or SERVERPOD_PASSWORD_* env vars) unless running locally with '
      'embedded Postgres',
    );
  }

  configureAuth(useDevLoginCode: local);
  installAuthenticationHandler(pod);

  pod.addCloudStorage(DatabaseCloudStorage('private'));

  await pod.start();
  await applyConstraints(pod);
  await scheduleMaintenance(pod.futureCalls);
}
