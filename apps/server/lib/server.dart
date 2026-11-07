import 'src/auth/auth_config.dart';
import 'src/db/constraints.dart';
import 'src/generated/serverpod.dart';

/// The starting point of the Serverpod server.
void run(List<String> args) async {
  final pod = Serverpod(args);

  configureAuth(
    useDevLoginCode: pod.runMode == ServerpodRunMode.development ||
        pod.runMode == ServerpodRunMode.test,
  );

  pod.addCloudStorage(DatabaseCloudStorage('private'));

  await pod.start();
  await applyConstraints(pod);
}
