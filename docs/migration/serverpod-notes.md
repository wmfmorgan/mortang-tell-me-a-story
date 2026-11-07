# Serverpod notes for Tell Me a Story (target: Serverpod 4.1.1)

Researched 2026-11-06 from pub.dev API and docs.serverpod.dev, which documents 4.x only.
Main decided: **4.1.1**, email OTP login via `EmailOtpIdpBaseEndpoint`. Postgres is Serverpod's embedded Postgres 16 in dev/test (`dataPath` in `config/*.yaml`; not mise) and managed Postgres ≥16 in prod. The external-PG config sketch in §3 below predates that decision.

## 1. Version, SDK, install
- pub.dev `serverpod` latest = **4.1.1** (published 2026-11-05), `environment.sdk: ^3.12.2`. Dart 3.13.5 satisfies this. The last 3.x release is 3.4.13 (2026-08-28, sdk ^3.8.0). Source: `https://pub.dev/api/packages/serverpod`.
- Why not 3.x: email one-time-code sign-in arrived in 4.1. "Projects created before Serverpod 4.1 extend `EmailIdpBaseEndpoint`, which supports password sign-in only" (docs …/providers/email/setup).
- 4.x requires Postgres ≥16 and Flutter ≥3.44.4 (docs /upgrading/upgrade-to-four). PG17 and Flutter 3.47.7 both meet this.
- `serverpod_auth_idp_server` and `serverpod_cloud_storage_s3` are both at 4.1.1. **Pin every `serverpod_*` package to the exact same version as the CLI** (no caret). `serverpod_test` pins `serverpod` exactly.
- CLI install (4.x docs use `dart install`; the 3.x form was `dart pub global activate`):
```bash
dart install serverpod_cli 4.1.1        # [UNVERIFIED] version arg on `dart install`; fallback:
dart pub global activate serverpod_cli 4.1.1
serverpod version
```
- mise: no serverpod plugin is assumed. Pin Dart/Flutter in mise and install the CLI in a `just setup` recipe with the command above. A mise `[tools]` entry like `"pub:serverpod_cli"` may exist, but whether the mise backend works is [UNVERIFIED]; check with `mise registry | grep -i serverpod` or `mise use pub:serverpod_cli@4.1.1`.

## 2. Layout and adding to an existing monorepo
`serverpod create x` produces one pub **workspace** (docs /concepts/server-fundamentals/your-serverpod-project):
```
x/pubspec.yaml            # workspace root (workspace: [x_server, x_client, x_flutter])
x_server/  bin/main.dart, lib/server.dart, lib/src/**, lib/src/generated/, config/, migrations/, web/, test/integration/test_tools/
x_client/  lib/src/protocol/   (generated, never edit)
x_flutter/
```
How to add this to the existing repo: do NOT run `serverpod create .` inside the repo, because it overwrites server.dart, config, and passwords.yaml (docs upgrade-to-four warning). Instead:
```bash
cd /tmp && serverpod create tell_me_a_story --no-interactive   # scaffold scratch copy
# copy the server and client packages in:
#   tmp/tell_me_a_story_server -> apps/server
#   tmp/tell_me_a_story_client -> packages/client  (or apps/server_client)
```
Then edit `apps/server/config/generator.yaml`:
```yaml
type: server
client_package_path: ../../packages/client     # relative to server pkg
server_test_tools_path: test/integration/test_tools
```
Flutter app `apps/tell_me_a_story/pubspec.yaml`:
```yaml
dependencies:
  serverpod_flutter: 4.1.1
  serverpod_auth_idp_flutter: 4.1.1
  tell_me_a_story_client:
    path: ../../packages/client
```
Root `pubspec.yaml` (optional, gives one `dart pub get` for the whole repo; every member then needs `resolution: workspace`):
```yaml
name: workspace
environment: { sdk: ^3.12.2 }
workspace: [apps/server, packages/client, apps/tell_me_a_story]
```
Regenerate after any model or endpoint change. This also regenerates the client and test tools:
```bash
cd apps/server && serverpod generate
```
To let `serverpod start` launch the existing app, add this to the server `pubspec.yaml` (docs running-your-server):
```yaml
serverpod:
  flutter_apps:
    tmas: { path: ../tell_me_a_story, auto_launch: true, device: chrome }
```

## 3. Config, native Postgres, no Redis, no Docker
`apps/server/config/development.yaml`:
```yaml
apiServer:      { port: 8080, publicHost: localhost, publicPort: 8080, publicScheme: http }
insightsServer: { port: 8081, publicHost: localhost, publicPort: 8081, publicScheme: http }
webServer:      { port: 8082, publicHost: localhost, publicPort: 8082, publicScheme: http }
database:
  host: localhost
  port: 5432            # mise/brew PG17
  name: tmas_dev
  user: tmas
  # no dataPath  => use the external PG; with dataPath it runs embedded PG instead
# no `redis:` section => Redis off (default when the section is absent)
maxRequestSize: 524288
```
`config/passwords.yaml` (gitignored; any key can be overridden with `SERVERPOD_PASSWORD_<key>`, or `SERVERPOD_DATABASE_PASSWORD`):
```yaml
shared:
  serviceSecret: '<random>'          # insights
development:
  database: '<pg password>'
  jwtRefreshTokenHashPepper: '<random>'
  jwtHmacSha512PrivateKey: '<random>'
  emailSecretHashPepper: '<random>'
test:
  database: '<pg password>'
  ...same auth keys
```
Env overrides: `SERVERPOD_DATABASE_HOST/PORT/NAME/USER/REQUIRE_SSL`, `SERVERPOD_REDIS_ENABLED=false` (docs /concepts/lookups/configuration-reference).
Run without Docker:
```bash
createuser -s tmas; createdb -O tmas tmas_dev; createdb -O tmas tmas_test
cd apps/server
serverpod start --no-docker --no-flutter     # dev loop: hot reload, auto-applies migrations, M = create+apply migration
dart run bin/main.dart --apply-migrations    # plain run (CI/prod)
```
`serverpod start` only starts docker compose when a compose file exists and the DB is localhost with no dataPath. Delete the scaffold's `docker-compose.yaml` or pass `--no-docker`.

## 4. Models (`.spy.yaml`, anywhere under server `lib/`)
Plain `.yaml`/`.yml` model files are rejected in 4.x. Ids are `int` serial by default; use `UuidValue` for public-facing ids (docs …/database/tables).
```yaml
# family.spy.yaml
class: Family
table: families
fields:
  id: UuidValue?, defaultPersist=random          # uuid PK (v4); random_v7 also allowed
  tree: Tree?, relation(name=tree_families, onDelete=Cascade)    # generates treeId
  parent: Family?, relation(name=family_children, optional, onDelete=SetNull)  # self 1:n -> parentId nullable
  children: List<Family>?, relation(name=family_children)
  name: String
  branchYear: int?
  originStoryId: UuidValue?                       # plain FK-less column; or relation(parent=stories)
  coverKey: String?
  createdById: UuidValue                          # auth user id (UuidValue in idp module)
  createdAt: DateTime, defaultPersist=now         # or default=now (model+db)
  deletedAt: DateTime?
indexes:
  families_tree_idx: { fields: treeId }
```
```yaml
# membership.spy.yaml  (join table, unique composite)
class: Membership
table: memberships
fields:
  family: Family?, relation(name=family_memberships, onDelete=Cascade)
  userId: UuidValue
  role: MembershipRole
  createdAt: DateTime, default=now
indexes:
  memberships_family_user_uniq: { fields: familyId, userId, unique: true }
```
```yaml
# membership_role.spy.yaml
enum: MembershipRole
serialized: byName        # default; stored as text
values: [owner, coOwner, member]
```
- Many-to-many (story_people): a junction model whose two relations each name a matching `List<StoryPerson>?, relation(name=...)` on the parent side, plus a unique index on `storyId, personId` (docs …/relations/many-to-many).
- Plain FK without an object field: `familyId: UuidValue, relation(parent=families, onDelete=Cascade)`. This is the parent= shorthand from the one-to-many docs; exact syntax for uuid ids is [UNVERIFIED], so check …/relations/one-to-many.md.
- Nullable = `Type?`. Partial/unique per tree: `people_tree_user_uniq: {fields: treeId, userId, unique: true}`. Postgres treats NULLs as distinct, so nullable userId works.
- `serverOnly: true` keeps a class off the client; `scope=serverOnly` does the same per field (nullable fields only). Use this for `invites.tokenHash`.
- Server-side CRUD: `Family.db.insertRow/find/findById/updateRow/deleteWhere(session, where: (t) => t.treeId.equals(id))`, `session.db.transaction((tx) async {...})`.

## 5. Migrations (docs …/database/migrations)
```bash
cd apps/server
serverpod create-migration [--tag init] [--force] [--empty]   # writes migrations/<ts>/migration.sql etc.
dart run bin/main.dart --apply-migrations                      # apply on start
dart run bin/main.dart --role maintenance --apply-migrations   # apply then exit (CI/deploy; exit 1 on failure)
serverpod create-repair-migration [--mode production] [--version <ts>]  # needs a reachable DB
dart run bin/main.dart --apply-repair-migration
```
- The first migration after adding the auth module also creates all auth tables.
- Custom SQL (CHECK constraints, partial indexes) can be appended to a generated `migration.sql` before it is applied. Treat applied migrations as immutable.
- The flag is plural, `--apply-migrations`. The singular form silently falls back to defaults.

## 6. Auth: `serverpod_auth_idp` email OTP
Packages: server `serverpod_auth_idp_server: 4.1.1`, client `serverpod_auth_idp_client: 4.1.1`, app `serverpod_auth_idp_flutter: 4.1.1` (needs `flutter_secure_storage` ≥10).

`lib/server.dart`:
```dart
import 'package:serverpod_auth_idp_server/core.dart';
import 'package:serverpod_auth_idp_server/providers/email.dart';

void run(List<String> args) async {
  final pod = Serverpod(args);
  pod.initializeAuthServices(
    tokenManagerBuilders: [JwtConfigFromPasswords()],   // or ServerSideSessionsConfigFromPasswords() for instant revocation
    identityProviderBuilders: [
      EmailIdpConfigFromPasswords(
        sendRegistrationVerificationCode: _sendCode,      // required
        sendPasswordResetVerificationCode: _sendReset,    // required (unused; just log)
        sendOtpLoginVerificationCode: _sendOtp,           // 6-digit default
        // otpLoginVerificationCodeLifetime: Duration(minutes: 15),
        // otpLoginVerificationCodeAllowedAttempts: 3,
      ),
    ],
  );
  await pod.start();
}

void _sendOtp(Session session, {required String email, required UuidValue otpLoginRequestId,
    required String verificationCode, required Transaction? transaction}) {
  if (session.serverpod.runMode == 'development') {
    session.log('[EmailIDP] Login code ($email): $verificationCode');  // dev: printed to server log
  } else { /* SMTP via package:mailer */ }
}
```
Endpoints, anywhere under `lib/`:
```dart
class EmailIdpEndpoint extends EmailOtpIdpBaseEndpoint {}              // OTP flow; new email => account created
class RefreshJwtTokensEndpoint extends core.RefreshJwtTokensEndpoint {} // import ...core.dart as core; required for JWT
```
- Dev and test run modes log codes instead of sending them, and this applies only to `ServerpodCloudEmailIdpConfig`. With `EmailIdpConfigFromPasswords` you log the code yourself, as above.
- A fixed dev code is possible: `otpLoginVerificationCodeGenerator: pod.runMode=='development' ? () => '111111' : defaultOtpVerificationCodeGenerator`. Source: docs …/email/configuration.
- Password sign-in is off by default, so the flow is passwordless. To restrict sign-in to invited users you need a hook in account creation. Whether `EmailIdpConfig` exposes an "on account request" or allow-list callback is [UNVERIFIED]; grep `serverpod_auth_idp_server` lib/providers/email for `onBeforeAccountCreated`/`Validation`. Fallback: create the account freely and gate everything in app code on membership/invite.

Issuing a session yourself, for custom flows or tests (docs …/token-managers/managing-tokens):
```dart
final AuthSuccess s = await AuthServices.instance.tokenManager.issueToken(session,
    authUserId: authUserId, method: 'email', scopes: {});
await AuthServices.instance.tokenManager.revokeAllTokens(session, authUserId: authUserId);
```
Authenticated user inside an endpoint (docs …/authentication/basics):
```dart
class StoryEndpoint extends Endpoint {
  @override bool get requireLogin => true;          // 401 otherwise
  Future<Story> get(Session session, UuidValue id) async {
    final authUserId = session.authenticated!.authUserId;          // UuidValue
    final uid = session.authenticated!.userIdentifier;             // String form
    ...
  }
}
```
`@unauthenticatedClientCall` marks public methods, for example invite preview.

Flutter client:
```dart
import 'package:flutter/foundation.dart';
import 'package:serverpod_flutter/serverpod_flutter.dart';
import 'package:serverpod_auth_idp_flutter/serverpod_auth_idp_flutter.dart';
late final Client client;
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  client = Client('http://localhost:8080/')
    ..cookieAuth = kIsWeb                              // web: httpOnly cookies
    ..connectivityMonitor = FlutterConnectivityMonitor()
    ..authSessionManager = FlutterAuthSessionManager(); // secure storage on iOS
  await client.auth.initialize();                      // restore + validate
  runApp(const App());
}
// UI: EmailOtpSignInWidget(client: client, onAuthenticated: ..., onError: ...)
// Custom UI: final c = EmailOtpAuthController(client: client, ...);
//   c.emailController.text = e; await c.startOtpLogin();
//   c.verificationCodeController.text = code; await c.verifyOtpCode();
//   new account => await c.finishOtpRegistration();
// state: client.auth.isAuthenticated, client.auth.authInfoListenable, await client.auth.signOutDevice() [UNVERIFIED name]
```
Web cookie mode server config (docs …/web-authentication):
```yaml
authCookie: { secure: false, sameSite: lax }   # dev; prod secure: true
allowedOrigins: [http://localhost:8082, http://localhost:5555]
```

## 7. File uploads and storage (docs /concepts/file-uploads)
Default storages are `public` and `private`, both backed by the database (`DatabaseCloudStorage`). New projects wrap them in `ServerpodCloudProvider` with a DB fallback; remove that wrapper if you self-host.
```dart
// endpoint
Future<String?> photoUploadDescription(Session s, UuidValue storyId) async {
  // authorize first
  final key = 'stories/$storyId/${Uuid().v4()}.jpg';    // no leading slash
  return s.storage.createUploadDescription(storageId: 'private', path: key,
    options: UploadOptions(maxFileSize: 20 << 20, expirationDuration: Duration(minutes: 10),
      metadata: const FileMetadata(contentType: 'image/jpeg')));
}
Future<bool> verifyPhoto(Session s, String key) => s.storage.verifyUpload(storageId: 'private', path: key);
Future<String> photoUrl(Session s, String key) async =>        // after authz
  (await s.storage.temporaryDownloadUrl(storageId: 'private', path: key,
     options: const TemporaryDownloadUrlOptions(expirationDuration: Duration(minutes: 5)))).toString();
// client
final desc = await client.photo.photoUploadDescription(storyId);
final ok = await FileUploader(desc!).upload(byteStream, length);   // returns false on any failure
await client.photo.verifyPhoto(key);
```
The names in the task brief (`createDirectFileUploadDescription`/`verifyDirectFileUpload`) are the older API. 4.x uses `createUploadDescription`/`verifyUpload`.
- Dev DB storage: uploads go through the API server, so **raise `maxRequestSize`** (default 512 KiB) above the largest photo.
- Prod S3: `dart pub add serverpod_cloud_storage_s3` with passwords `AWSAccessKeyId`/`AWSSecretKey`:
```dart
pod.addCloudStorage(s3.S3CloudStorage(serverpod: pod, storageId: 'private', public: false,
    region: 'eu-west-1', bucket: 'tmas-photos'));
```
- Other S3-compatible stores (MinIO, R2, Hetzner) use `serverpod_cloud_storage_s3_compat`, `S3CompatCloudStorage(... endpoints: CustomEndpointConfig(baseUri: ...), uploadStrategy: PresignedPutUploadStrategy())`. R2 has its own package, `serverpod_cloud_storage_r2`. Local disk/NAS needs a custom `CloudStorage` (docs /concepts/endpoints-and-apis/custom-cloud-storage).
- Whether `temporaryDownloadUrl` works for `DatabaseCloudStorage` in dev is [UNVERIFIED]. Test it early; if not, serve dev files with an authorized endpoint using `retrieveFile`.

## 8. Realtime: streaming methods and server events (docs …/streaming, …/server-events)
```dart
class FamilyFeedEndpoint extends Endpoint {
  @override bool get requireLogin => true;
  Stream<FamilyEvent> watch(Session session, UuidValue familyId) async* {
    await _assertMember(session, familyId);            // authz once, at subscribe time
    yield* session.messages.createStream<FamilyEvent>('family_$familyId');
  }
}
// after any write:
await session.messages.postMessage('family_$familyId', FamilyEvent(kind: 'story_updated', id: id));
```
Client:
```dart
final sub = client.familyFeed.watch(familyId).listen(onEvent,
    onError: (e) { if (e is MethodStreamException) {/* reconnect/backoff */} });
```
- Transport is one shared WebSocket. All streams close if it drops, so the client must resubscribe. Streams close automatically when auth is revoked or the user changes.
- `MessageScope.auto` delivers locally without Redis. Multi-instance fan-out needs Redis (`MessageScope.global` throws without it).
- Ping interval defaults to 30s (`websocketPingInterval`). Lower it behind proxies with short idle timeouts.

## 9. Scheduling: daily 60-day purge (docs /concepts/scheduling/*)
```dart
class PurgeFutureCall extends FutureCall {
  Future<void> purgeDeletedFamilies(Session session) async {
    final cutoff = DateTime.now().toUtc().subtract(const Duration(days: 60));
    final doomed = await Family.db.find(session, where: (t) => t.deletedAt < cutoff);
    // delete blobs (session.storage.deleteFile) then rows; must be idempotent (at-least-once)
  }
}
```
Run `serverpod generate`. In `server.dart`, **after** `await pod.start()` (scheduling earlier throws):
```dart
await pod.futureCalls.callRecurring(identifier: 'purge-families')
    .cron('0 3 * * *').purge.purgeDeletedFamilies();     // UTC
```
- Calls are stored in `serverpod_future_call` and run once across all instances. A failed recurring run is logged and the next run still happens. Re-registering the same identifier on every boot may create duplicates [UNVERIFIED]; call `pod.futureCalls.cancel('purge-families')` first to be safe.
- Only the `monolith` (default) and `maintenance` roles execute future calls.

## 10. Testing (docs /concepts/testing/*)
- `dev_dependencies: serverpod_test: 4.1.1, test: ^1.x`. `serverpod generate` writes `test/integration/test_tools/serverpod_test_tools.dart`.
```dart
import 'package:test/test.dart';
import 'test_tools/serverpod_test_tools.dart';
void main() {
  withServerpod('Given Story endpoint', (sessionBuilder, endpoints) {
    test('member can read', () async {
      final sb = sessionBuilder.copyWith(
          authentication: AuthenticationOverride.authenticationInfo(userIdentifier, {}));  // [UNVERIFIED] exact ctor; see testing/writing-tests.md
      expect(await endpoints.story.get(sb, id), isNotNull);
    });
  }, rollbackDatabase: RollbackDatabase.afterEach);   // default
}
```
- DB: `config/test.yaml` points at a running PG, for example local `tmas_test` (5432) with the `test:` passwords. Without `dataPath` the server must be running. By default each `withServerpod` group gets its **own temporary database**, created and dropped on that server, so the DB user needs CREATEDB. Migrations are applied automatically (`applyMigrations: true`).
- Rollback: every test is wrapped in a transaction (`afterEach`). Endpoints that run parallel DB calls, or use `watch`, need `RollbackDatabase.disabled`. Code that swallows DB exceptions passes under rollback but fails in prod.
- Run with `cd apps/server && dart test` (`-t integration` / `-x integration` to split). Use `--concurrency=1` if groups share a DB.

## 11. Errors mirroring `{code, message}`
```yaml
# api_exception.spy.yaml
exception: ApiException
fields:
  code: String        # e.g. 'not_found', 'forbidden', 'validation'
  message: String
```
Server: `throw ApiException(code: 'forbidden', message: 'Not a member of this family');`. The client receives HTTP 400 with a typed payload: `on ApiException catch (e) { e.code }`. A sealed hierarchy (`sealed: true` plus `extends:`) allows exhaustive switches. Uncaught exceptions become `ServerpodClientInternalServerError` (500) with no details. Auth failures surface as `ServerpodClientUnauthorized` (401) or `ServerpodClientForbidden` (403); network failures as `ServerpodClientNetworkException`.

## 12. Serving Flutter web and deploying
```dart
pod.webServer.addRoute(FlutterRoute(Directory('web/app'), enableWasmHeaders: false), '/');  // route path arg [UNVERIFIED]; see docs /concepts/web-server/flutter-web
```
- Build with `flutter build web --output ../server/web/app`. The app is then served on 8082 with SPA fallback and `no-cache` + ETag. Same origin means no CORS question for the API, unless the API stays on 8080 (different port = different origin, so list it in `allowedOrigins`).
- Deploy options:
  - **Serverpod Cloud** (`scloud`): managed PG, storage, and email. Future calls need the Growth plan or higher.
  - **Docker**: the scaffold's Dockerfile, built from the repo root with `docker build -f <server>/Dockerfile .`, `runmode` arg, base image `dart:3.12.2+`.
  - **Plain binary**: in 4.x `dart compile exe` is unsupported because of native build hooks. Use `dart build cli` to get an exe plus a bundle directory. Run it with `--mode production --apply-migrations`, or a separate `--role maintenance --apply-migrations` step.
- Config in production comes from `config/production.yaml` plus `SERVERPOD_*` env vars and `SERVERPOD_PASSWORD_*` secrets.

## 13. Gotchas
- **Version lockstep**: CLI, server, client, flutter, auth, test, and storage packages must all be exactly 4.1.1. A mismatch breaks `pub get` or codegen. After upgrading the CLI, delete `apps/server/.dart_tool/serverpod`.
- **Dart SDK** ≥3.12.2 is required by the server package. The Flutter app's SDK constraint must also allow the client package.
- **Postgres ≥16** is required, because the startup integrity check fails on 14.
- **Redis** is optional. Without it, server events, stream fan-out, and auth revocation messages are local only, so a single instance is fine. **Multi-instance** needs Redis for realtime fan-out. Future calls are already coordinated through the DB.
- **CORS/web**: with cookie auth on, `allowedOrigins` must list every web origin (no wildcard), and dev needs `authCookie.secure: false`. `allowedOrigins` also rejects cross-origin WebSockets. In plain token mode on web, tokens sit in JS-readable storage.
- **iPad simulator/device**: `localhost` only works in the simulator. On a device, use the Mac's LAN IP and set `apiServer.publicHost` to match.
- **Upload size**: dev DB storage is capped by `maxRequestSize`. `FileUploader.upload` returns `false` with no reason.
- Model files must be `.spy.yaml`.
- **`serverpod create .`** clobbers config and passwords. Never run it in this repo.
- Auth user ids are `UuidValue` (`authUserId`). Key `users`/`memberships` on that, or on your own `users` table linked 1:1 to it.
