import 'package:serverpod/serverpod.dart';
import 'package:tell_me_a_story_server/src/auth/local_mode.dart';
import 'package:test/test.dart';

ServerpodConfig _config(String runMode, {DatabaseConfig? database}) =>
    ServerpodConfig(
      runMode: runMode,
      apiServer: ServerConfig(
        port: 0,
        publicScheme: 'http',
        publicHost: 'localhost',
        publicPort: 0,
      ),
      database: database,
    );

final _embedded = PostgresDatabaseConfig.embedded(
  dataPath: '.serverpod/development/pgdata',
  name: 'db',
);

final _remote = PostgresDatabaseConfig(
  host: 'db.example.com',
  port: 5432,
  user: 'postgres',
  password: 'secret',
  name: 'db',
);

void main() {
  group('Given isLocalConfig', () {
    test('when development uses embedded Postgres then it is local', () {
      expect(
        isLocalConfig(
          _config(ServerpodRunMode.development, database: _embedded),
        ),
        isTrue,
      );
    });

    test('when test uses embedded Postgres then it is local', () {
      expect(
        isLocalConfig(_config(ServerpodRunMode.test, database: _embedded)),
        isTrue,
      );
    });

    test('when development uses a remote database then it is not local', () {
      expect(
        isLocalConfig(_config(ServerpodRunMode.development, database: _remote)),
        isFalse,
      );
    });

    test('when development has no database then it is not local', () {
      expect(isLocalConfig(_config(ServerpodRunMode.development)), isFalse);
    });

    test('when production uses embedded Postgres then it is not local', () {
      expect(
        isLocalConfig(
          _config(ServerpodRunMode.production, database: _embedded),
        ),
        isFalse,
      );
    });
  });
}
