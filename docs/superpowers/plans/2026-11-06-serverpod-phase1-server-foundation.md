# Phase 1: Server Foundation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a Serverpod 4.1.1 backend at `apps/server`, plus its generated client at `packages/tell_me_a_story_client`. It covers the full new schema, passwordless email-code login, an `AppException` error envelope and family-level authorization, and it runs and tests locally with no Docker and no Supabase.

**Architecture:** The scaffold is copied from `serverpod create` into standalone packages (no pub workspace), so the Flutter app is untouched. Dev and test use Serverpod's embedded Postgres (`dataPath` in `config/*.yaml`). Raw SQL constraints that models can't express live in `lib/src/db/constraints.dart`. They run after every boot and in test setup, because Serverpod builds fresh databases from `definition.sql` only. Login is `EmailOtpIdpBaseEndpoint`, with a fixed code `111111` in development and test, and Resend in staging and production.

**Tech Stack:** Dart 3.13.5 (from mise Flutter 3.47.7), Serverpod 4.1.1 (`serverpod`, `serverpod_auth_idp_server`, `serverpod_test`), embedded PostgreSQL 16, `package:http`, just.

**Verified:** every file and command below was run in a scratch copy on 2026-11-06. `dart analyze` was clean and `dart test` gave 9/9 passing, with a dev boot on :8080 that applied the init migration and answered `startOtpLogin`. The Task 2 just recipes were run in the same scratch copy.

**References:** `docs/migration/schema-design.md` (model rationale and the old→new column map), `docs/migration/business-rules.md` §1 (predicates), `docs/migration/serverpod-notes.md`.

---

## File map

| Path | Responsibility |
|---|---|
| `apps/server/pubspec.yaml`, `config/*.yaml`, `bin/main.dart` | Serverpod package, run-mode config, entrypoint |
| `apps/server/lib/server.dart` | Boot: auth, storage, start, constraints |
| `apps/server/lib/src/auth/auth_config.dart` | `configureAuth()`: JWT, email OTP, dev code, `AppUser` creation hook |
| `apps/server/lib/src/auth/login_code_sender.dart` | Logs the code in dev/test, sends it via Resend in staging/prod |
| `apps/server/lib/src/auth/email_idp_endpoint.dart`, `jwt_refresh_endpoint.dart` | Scaffold auth endpoints (kept as generated) |
| `apps/server/lib/src/models/*.spy.yaml` | 17 schema models + `AppException` |
| `apps/server/lib/src/db/constraints.dart` | `constraintsSql` + `applyConstraints()` |
| `apps/server/lib/src/authz/authz.dart` | `Authz` family-level predicates |
| `apps/server/test/integration/*_test.dart` | login, constraints, authz tests |
| `packages/tell_me_a_story_client/` | Generated client (never hand-edited) |
| `justfile` | `server-*` recipes |

---

### Task 1: Scaffold the server and client packages

**Files:**
- Create: `apps/server/**` and `packages/tell_me_a_story_client/**`, copied from a scratch scaffold
- Modify: `apps/server/pubspec.yaml`, `apps/server/config/generator.yaml`, `apps/server/config/development.yaml`, `apps/server/lib/server.dart`, `packages/tell_me_a_story_client/pubspec.yaml`

- [ ] **Step 1: Install the CLI and scaffold in a scratch dir**

Never run `serverpod create` inside the repo, because it overwrites config and passwords.

```bash
mise exec -- dart pub global activate serverpod_cli 4.1.1
mise exec -- dart pub global run serverpod_cli version     # Expected: Serverpod version: 4.1.1
rm -rf /tmp/tmas-scaffold && mkdir /tmp/tmas-scaffold && cd /tmp/tmas-scaffold
mise exec -- dart pub global run serverpod_cli create tell_me_a_story
```

- [ ] **Step 2: Copy the two packages into the repo and drop the scaffold extras**

```bash
cd /Users/david/projects/mortang-tell-me-a-story
mkdir -p packages
cp -R /tmp/tmas-scaffold/tell_me_a_story/tell_me_a_story_server apps/server
cp -R /tmp/tmas-scaffold/tell_me_a_story/tell_me_a_story_client packages/tell_me_a_story_client
rm -rf apps/server/.dart_tool apps/server/.serverpod packages/tell_me_a_story_client/.dart_tool
rm -rf apps/server/docker-compose.yaml apps/server/Dockerfile apps/server/web \
       apps/server/CHANGELOG.md apps/server/README.md \
       apps/server/lib/src/greetings apps/server/lib/src/web apps/server/lib/src/cache_busting.dart \
       apps/server/test/integration/greeting_endpoint_test.dart
```

- [ ] **Step 3: Make both packages standalone**

In both `apps/server/pubspec.yaml` and `packages/tell_me_a_story_client/pubspec.yaml`, delete the line `resolution: workspace`. In `apps/server/pubspec.yaml`, delete everything from the top-level `serverpod:` key to the end of the file (the `scripts` and `flutter_apps` blocks point at the scaffold's Flutter app). Then add `http`:

```bash
cd apps/server && mise exec -- dart pub add http
```

`apps/server/pubspec.yaml` must now read:

```yaml
name: tell_me_a_story_server
description: Starting point for a Serverpod server.
# version: 1.0.0
# homepage: https://www.example.com

environment:
  sdk: '^3.12.2'


dependencies:
  http: ^1.6.0
  serverpod: 4.1.1
  serverpod_auth_idp_server: 4.1.1
dev_dependencies:
  lints: '>=3.0.0 <7.0.0'
  serverpod_test: 4.1.1
  test: ^1.25.5
```

- [ ] **Step 4: Point the generator at the client package**

`apps/server/config/generator.yaml`:

```yaml
type: server

client_package_path: ../../packages/tell_me_a_story_client
server_test_tools_path: test/integration/test_tools
```

- [ ] **Step 5: Raise the request size for dev uploads**

In `apps/server/config/development.yaml`, replace the `maxRequestSize: 524288 ...` line with:

```yaml
maxRequestSize: 52428800 # 50 MiB: dev DatabaseCloudStorage uploads go through the API server
```

Keep `database.dataPath: .serverpod/development/pgdata`, which is the embedded Postgres. `config/test.yaml` stays as scaffolded (embedded, `dataPath: .serverpod/test/pgdata`).

- [ ] **Step 6: Replace `apps/server/lib/server.dart` with a minimal boot so the package compiles**

```dart
import 'src/generated/serverpod.dart';

void run(List<String> args) async {
  final pod = Serverpod(args);
  await pod.start();
}
```

- [ ] **Step 7: Generate and analyze**

```bash
cd apps/server && mise exec -- dart pub get
(cd ../../packages/tell_me_a_story_client && mise exec -- dart pub get)
mise exec -- dart pub global run serverpod_cli generate     # Expected: ✅ Done.
mise exec -- dart analyze                                   # Expected: No issues found!
```

`apps/server/.gitignore` (scaffolded) already ignores `config/passwords.yaml` and `.serverpod/`. The scaffold's `config/passwords.yaml` is deleted in Step 8; Task 2 regenerates it.

- [ ] **Step 8: Commit**

```bash
rm apps/server/config/passwords.yaml
git add apps/server packages/tell_me_a_story_client
git commit -m "feat(server): scaffold Serverpod 4.1.1 server and client packages"
```

### Task 2: just recipes for the server

**Files:**
- Modify: `justfile` (append after the `run` recipe)
- Modify: `README.md` (one line after the `just setup` sentence)

- [ ] **Step 1: Append the recipes**

```just
# Install serverpod_cli 4.1.1 and fetch server/client packages; create local passwords if missing
server-setup:
    dart pub global activate serverpod_cli 4.1.1
    cd apps/server && dart pub get
    cd packages/tell_me_a_story_client && dart pub get
    just server-passwords

# Write apps/server/config/passwords.yaml with random development/test secrets (no-op if it exists)
server-passwords:
    #!/usr/bin/env sh
    set -eu
    file=apps/server/config/passwords.yaml
    if [ -f "$file" ]; then echo "$file exists; leaving it alone."; exit 0; fi
    r() { openssl rand -hex "$1"; }
    {
        for mode in development test; do
            echo "$mode:"
            echo "  database: \"$(r 16)\""
            echo "  serviceSecret: \"$(r 32)\""
            echo "  emailSecretHashPepper: \"$(r 32)\""
            echo "  jwtHmacSha512PrivateKey: \"$(r 64)\""
            echo "  jwtRefreshTokenHashPepper: \"$(r 32)\""
        done
    } > "$file"
    echo "Wrote $file"

# Regenerate server protocol, client package and test tools after model/endpoint changes
server-generate:
    cd apps/server && dart pub global run serverpod_cli generate

# Create a migration from model changes: just server-migration <tag>
server-migration tag:
    cd apps/server && dart pub global run serverpod_cli create-migration --tag {{tag}}

# Run the API server on :8080 (embedded Postgres, migrations applied, login code 111111)
server:
    cd apps/server && dart run bin/main.dart --apply-migrations

# Backend integration tests (embedded Postgres)
server-test:
    cd apps/server && dart test
```

- [ ] **Step 2: Add a README pointer**

After the line starting ``From the repo root, `just setup` installs``, add:

```markdown
`just server-setup` prepares the Serverpod backend in `apps/server` (CLI, packages, local secrets). `just server` runs it on :8080 with an embedded Postgres; the dev login code is `111111`. `just server-test` runs its tests.
```

- [ ] **Step 3: Run and check**

```bash
mise exec -- just server-setup        # Expected ends: Wrote apps/server/config/passwords.yaml
mise exec -- just server-passwords    # Expected: apps/server/config/passwords.yaml exists; leaving it alone.
mise exec -- just --list | rg server  # Expected: 6 server recipes
```

- [ ] **Step 4: Commit**

```bash
git add justfile README.md && git commit -m "chore: add just recipes for the Serverpod backend"
```

### Task 3: Schema models and the init migration

**Files:**
- Create: the 17 files under `apps/server/lib/src/models/` listed below
- Create: `apps/server/migrations/<timestamp>-init/*` (generated)

The design rationale is in `docs/migration/schema-design.md` §0–§2. Ids are UUID v7. User foreign keys point at `serverpod_auth_core_user`. `DatePrecision` is `byIndex` and append-only.

- [ ] **Step 1: Write the model files exactly as follows**


`apps/server/lib/src/models/app_user.spy.yaml`
```yaml
### App-owned profile for one Serverpod AuthUser (1:1 bridge).
### Endpoints return this only for the caller; other users' data goes out via DTOs
### (e.g. PersonProfile with birth date coarsened by birthVisibility).
class: AppUser
table: users
fields:
  id: UuidValue?, defaultPersist=random_v7
  ### serverpod_auth_core_user.id
  authUserId: UuidValue, relation(parent=serverpod_auth_core_user, onDelete=Cascade)
  displayName: String?
  ### Blob key, see §4. users/{authUserId}/avatar/{blobId}.jpg
  avatarKey: String?
  ### ≤ 500 chars (CHECK users_about_len).
  about: String?
  ### UTC midnight. Paired with birthPrecision (CHECK users_birth_pair).
  birthDate: DateTime?
  birthPrecision: DatePrecision?
  birthVisibility: BirthVisibility, default=hidden
  createdAt: DateTime, default=now
  updatedAt: DateTime, default=now
indexes:
  users_auth_user_uidx:
    fields: authUserId
    unique: true
```

`apps/server/lib/src/models/birth_visibility.spy.yaml`
```yaml
### How much of a user's birth date other tree members see.
enum: BirthVisibility
serialized: byName
values:
  - hidden
  - year
  - yearMonth
  - full
```

`apps/server/lib/src/models/blob_deletion.spy.yaml`
```yaml
### Keys whose objects must be deleted from blob storage. Written in the SAME
### transaction that drops/replaces the DB reference; drained by a recurring future
### call. Needed because Serverpod CloudStorage has no list/prefix-delete (§4.3).
class: BlobDeletion
table: blob_deletions
serverOnly: true
fields:
  id: UuidValue?, defaultPersist=random_v7
  key: String
  createdAt: DateTime, default=now
  attempts: int, default=0
indexes:
  blob_deletions_created_idx:
    fields: createdAt
```

`apps/server/lib/src/models/date_precision.spy.yaml`
```yaml
### Precision of a calendar date span. byIndex ON PURPOSE: the stored bigint
### (0 year, 1 month, 2 day) sorts coarse→fine like the old Postgres enum.
### APPEND-ONLY. Never reorder or remove values.
enum: DatePrecision
serialized: byIndex
values:
  - year
  - month
  - day
```

`apps/server/lib/src/models/family.spy.yaml`
```yaml
class: Family
table: families
fields:
  id: UuidValue?, defaultPersist=random_v7
  ### Immutable. Tree rows are deleted by the purge job only when empty.
  treeId: UuidValue, relation(parent=trees, onDelete=Restrict)
  ### Branch parent; same tree enforced by raw FK families_parent_same_tree_fk.
  parentId: UuidValue?, relation(parent=families, onDelete=SetNull)
  name: String
  ### 1..9999 (CHECK).
  branchYear: int?
  ### Story in the parent family this branch started from.
  originStoryId: UuidValue?, relation(parent=stories, onDelete=SetNull)
  ### Blob key, see §4. families/{familyId}/cover/{blobId}.{jpg|png|webp}
  coverKey: String?
  createdById: UuidValue?, relation(parent=serverpod_auth_core_user, onDelete=SetNull)
  createdAt: DateTime, default=now
  ### Soft delete; purged 60 days later by a future call.
  deletedAt: DateTime?
indexes:
  families_tree_idx:
    fields: treeId
  ### Target of the composite FKs (people + parent) in constraintsSql.
  families_id_tree_uidx:
    fields: id, treeId
    unique: true
  families_parent_idx:
    fields: parentId
  families_origin_story_idx:
    fields: originStoryId
  families_deleted_at_idx:
    fields: deletedAt
```

`apps/server/lib/src/models/invite.spy.yaml`
```yaml
### serverOnly: tokenHash must never be serialized to the app; endpoints return an
### InviteSummary DTO (id, email, personId, status, expiresAt, createdAt).
### Status is derived: acceptedAt → accepted; revokedAt → revoked;
### expiresAt <= now → expired; else pending.
class: Invite
table: invites
serverOnly: true
fields:
  id: UuidValue?, defaultPersist=random_v7
  familyId: UuidValue, relation(parent=families, onDelete=Cascade)
  personId: UuidValue?, relation(parent=people, onDelete=SetNull)
  ### Null = open link invite. Lower-cased/trimmed (CHECK).
  email: String?
  ### lowercase hex SHA-256 of the raw token (CHECK invites_token_hash_shape).
  tokenHash: String
  invitedById: UuidValue?, relation(parent=serverpod_auth_core_user, onDelete=SetNull)
  acceptedById: UuidValue?, relation(parent=serverpod_auth_core_user, onDelete=SetNull)
  acceptedAt: DateTime?
  revokedAt: DateTime?
  ### Set by the app: now + 7 days (create and resend). No YAML default can express it.
  expiresAt: DateTime
  createdAt: DateTime, default=now
indexes:
  invites_token_hash_uidx:
    fields: tokenHash
    unique: true
  invites_family_created_idx:
    fields: familyId, createdAt
  invites_person_idx:
    fields: personId
```

`apps/server/lib/src/models/membership.spy.yaml`
```yaml
class: Membership
table: memberships
fields:
  id: UuidValue?, defaultPersist=random_v7
  familyId: UuidValue, relation(parent=families, onDelete=Cascade)
  userId: UuidValue, relation(parent=serverpod_auth_core_user, onDelete=Cascade)
  ### One owner per family: raw partial unique index memberships_one_owner_uidx.
  role: MembershipRole, default=member
  createdAt: DateTime, default=now
indexes:
  memberships_family_user_uidx:
    fields: familyId, userId
    unique: true
  ### "My families" lookup.
  memberships_user_idx:
    fields: userId
```

`apps/server/lib/src/models/membership_role.spy.yaml`
```yaml
### Role of a user in one family. Stored by name (text).
enum: MembershipRole
serialized: byName
values:
  - owner
  - coOwner
  - member
```

`apps/server/lib/src/models/note_kind.spy.yaml`
```yaml
### Replaces the separate comments / perspectives tables.
enum: NoteKind
serialized: byName
values:
  - comment
  - perspective
```

`apps/server/lib/src/models/person.spy.yaml`
```yaml
class: Person
table: people
fields:
  id: UuidValue?, defaultPersist=random_v7
  familyId: UuidValue, relation(parent=families, onDelete=Cascade)
  ### Copy of families.treeId (immutable); kept equal by raw composite FK
  ### people_family_tree_fk. Exists so "one linked person per tree" is a plain unique index.
  treeId: UuidValue
  ### Linked account. Unique per tree; NULLs are distinct so unlinked people don't collide.
  userId: UuidValue?, relation(parent=serverpod_auth_core_user, onDelete=SetNull)
  ### For linked people this mirrors AppUser.displayName (app-layer sync, §3.2).
  name: String
  relationship: String?
  ### Lower-cased, trimmed, non-empty or null (CHECK).
  email: String?
  ### ≤ 500 chars (CHECK).
  about: String?
  ### Blob key, see §4. families/{familyId}/people/{personId}/avatar/{blobId}.jpg
  avatarKey: String?
  passedAway: bool, default=false
  createdById: UuidValue?, relation(parent=serverpod_auth_core_user, onDelete=SetNull)
  createdAt: DateTime, default=now
  updatedAt: DateTime, default=now
indexes:
  people_tree_user_uidx:
    fields: treeId, userId
    unique: true
  people_family_name_idx:
    fields: familyId, name
  ### Tree-wide person picker (story tagging across branches).
  people_tree_name_idx:
    fields: treeId, name
  people_user_idx:
    fields: userId
```

`apps/server/lib/src/models/photo.spy.yaml`
```yaml
class: Photo
table: photos
fields:
  id: UuidValue?, defaultPersist=random_v7
  storyId: UuidValue, relation(parent=stories, onDelete=Cascade)
  ### Uploader may delete own photo (story_reader_page.dart:1017).
  uploaderId: UuidValue?, relation(parent=serverpod_auth_core_user, onDelete=SetNull)
  ### families/{familyId}/stories/{storyId}/photos/{photoId}/original.{jpg|png|webp}
  originalKey: String
  ### families/{familyId}/stories/{storyId}/photos/{photoId}/edited-{editVersion}.jpg
  editedKey: String?
  ### Optimistic-concurrency counter; +1 on every save AND reset of an edit.
  editVersion: int, default=0
  sortOrder: int, default=0
  createdAt: DateTime, default=now
indexes:
  photos_story_sort_idx:
    fields: storyId, sortOrder
```

`apps/server/lib/src/models/place.spy.yaml`
```yaml
class: Place
table: places
fields:
  id: UuidValue?, defaultPersist=random_v7
  familyId: UuidValue, relation(parent=families, onDelete=Cascade)
  label: String
  address: String
  lat: double
  lng: double
  mapboxPlaceId: String?
  isFavorite: bool, default=false
  lastUsedAt: DateTime?
indexes:
  places_family_label_idx:
    fields: familyId, label
  ### Client looks a place up by (family, mapbox id), places_api.dart:204-206.
  places_family_mapbox_uidx:
    fields: familyId, mapboxPlaceId
    unique: true
  ### "Recent places", places_api.dart:135-138.
  places_family_last_used_idx:
    fields: familyId, lastUsedAt
```

`apps/server/lib/src/models/story.spy.yaml`
```yaml
class: Story
table: stories
fields:
  id: UuidValue?, defaultPersist=random_v7
  familyId: UuidValue, relation(parent=families, onDelete=Cascade)
  ### Null only after the author's account is deleted.
  authorId: UuidValue?, relation(parent=serverpod_auth_core_user, onDelete=SetNull)
  title: String?
  body: String?
  status: StoryStatus, default=draft
  ### UTC midnight. All three null (undated draft) or a valid span (CHECK stories_date_shape).
  dateStart: DateTime?
  dateEnd: DateTime?
  datePrecision: DatePrecision?
  placeId: UuidValue?, relation(parent=places, onDelete=SetNull)
  publishedAt: DateTime?
  createdAt: DateTime, default=now
  updatedAt: DateTime, default=now
indexes:
  ### Timeline order. status sits after familyId because timeline reads always filter
  ### status=published (drafts are author-only), so the remaining columns give an
  ### index-ordered scan: dateStart, datePrecision, createdAt, id
  ### (same tiebreak as client compareStories, stories_api.dart:796 and :663-665).
  stories_family_order_idx:
    fields: familyId, status, dateStart, datePrecision, createdAt, id
  ### Drafts page (author's drafts).
  stories_author_status_idx:
    fields: authorId, status
  ### "Latest" window (latestPublishedCutoff, stories_api.dart:767).
  stories_family_published_at_idx:
    fields: familyId, publishedAt
  stories_place_idx:
    fields: placeId
```

`apps/server/lib/src/models/story_note.spy.yaml`
```yaml
### Comments and perspectives in one table.
class: StoryNote
table: story_notes
fields:
  id: UuidValue?, defaultPersist=random_v7
  storyId: UuidValue, relation(parent=stories, onDelete=Cascade)
  authorId: UuidValue?, relation(parent=serverpod_auth_core_user, onDelete=SetNull)
  kind: NoteKind
  body: String
  createdAt: DateTime, default=now
  updatedAt: DateTime, default=now
indexes:
  ### Lists per story+kind ordered by createdAt (comments_api.dart:68-69).
  story_notes_story_kind_created_idx:
    fields: storyId, kind, createdAt
```

`apps/server/lib/src/models/story_person.spy.yaml`
```yaml
### Junction story ↔ person (Serverpod tables always have an id; the old composite PK
### becomes a unique index). https://docs.serverpod.dev/concepts/data-and-the-database/database/relations/many-to-many
class: StoryPerson
table: story_people
fields:
  id: UuidValue?, defaultPersist=random_v7
  storyId: UuidValue, relation(parent=stories, onDelete=Cascade)
  personId: UuidValue, relation(parent=people, onDelete=Cascade)
indexes:
  story_people_story_person_uidx:
    fields: storyId, personId
    unique: true
  story_people_person_idx:
    fields: personId
```

`apps/server/lib/src/models/story_status.spy.yaml`
```yaml
enum: StoryStatus
serialized: byName
values:
  - draft
  - published
```

`apps/server/lib/src/models/tree.spy.yaml`
```yaml
### Groups a root family and all its branches. Every family has exactly one tree;
### "same tree" checks become an equality on treeId (no recursive parent walk).
class: Tree
table: trees
fields:
  id: UuidValue?, defaultPersist=random_v7
  createdAt: DateTime, default=now
```


- [ ] **Step 2: Generate, create the migration, analyze**

```bash
mise exec -- just server-generate          # Expected: ✅ Done.
mise exec -- just server-migration init    # Expected: Server migration created: migrations/<ts>-init
cd apps/server && mise exec -- dart analyze # Expected: No issues found!
```

- [ ] **Step 3: Boot once to prove the migration applies**

```bash
mise exec -- just server
# Expected log lines: "runMode: development" and "Applied database migration: - <ts>-init". Stop with Ctrl-C.
```

- [ ] **Step 4: Commit**

```bash
git add apps/server packages/tell_me_a_story_client && git commit -m "feat(server): add schema models and init migration"
```

### Task 4: Passwordless email-code login

**Files:**
- Create: `apps/server/test/integration/login_test.dart`
- Create: `apps/server/lib/src/auth/auth_config.dart`, `apps/server/lib/src/auth/login_code_sender.dart`
- Modify: `apps/server/lib/server.dart`
- Keep: `apps/server/lib/src/auth/email_idp_endpoint.dart` (scaffold, extends `EmailOtpIdpBaseEndpoint`) and `jwt_refresh_endpoint.dart`

- [ ] **Step 1: Write the failing test**

`withServerpod` does not execute `run()`, so tests call `configureAuth` themselves. The auth module opens its own transactions, so this group needs `RollbackDatabase.disabled`. Each test uses a unique email for that reason.

```dart
import 'package:tell_me_a_story_server/src/auth/auth_config.dart';
import 'package:tell_me_a_story_server/src/generated/protocol.dart';
import 'package:test/test.dart';

import 'test_tools/serverpod_test_tools.dart';

void main() {
  setUpAll(() => configureAuth(useDevLoginCode: true));

  withServerpod('Given email one-time-code login', (sessionBuilder, endpoints) {
    test('when a new email verifies the dev code then an account is created',
        () async {
      final requestId = await endpoints.emailIdp.startOtpLogin(
        sessionBuilder,
        email: 'ana@example.com',
      );
      final result = await endpoints.emailIdp.verifyOtpLoginCode(
        sessionBuilder,
        otpLoginRequestId: requestId,
        verificationCode: devLoginCode,
      );
      expect(result.accountExists, isFalse);

      final auth = await endpoints.emailIdp.finishOtpRegistration(
        sessionBuilder,
        otpLoginToken: result.token,
      );
      final appUser = await AppUser.db.findFirstRow(
        sessionBuilder.build(),
        where: (t) => t.authUserId.equals(auth.authUserId),
      );
      expect(appUser, isNotNull);
    });

    test('when the wrong code is entered then verification fails', () async {
      final requestId = await endpoints.emailIdp.startOtpLogin(
        sessionBuilder,
        email: 'ben@example.com',
      );
      await expectLater(
        endpoints.emailIdp.verifyOtpLoginCode(
          sessionBuilder,
          otpLoginRequestId: requestId,
          verificationCode: '000000',
        ),
        throwsA(anything),
      );
    });
  }, rollbackDatabase: RollbackDatabase.disabled);
}
```

- [ ] **Step 2: Run it and confirm it fails**

```bash
cd apps/server && mise exec -- dart test test/integration/login_test.dart
# Expected: compile error, auth_config.dart not found
```

- [ ] **Step 3: Implement**

`apps/server/lib/src/auth/login_code_sender.dart`:

```dart
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:serverpod/serverpod.dart';

/// Delivers a one-time login code.
///
/// Development and test: logs the code (the fixed dev code is `111111`).
/// Staging and production: sends it through Resend using the
/// `resendApiKey` and `resendFrom` entries in `config/passwords.yaml`.
Future<void> sendLoginCode(
  Session session, {
  required String email,
  required UuidValue otpLoginRequestId,
  required String verificationCode,
  required Transaction? transaction,
}) async {
  final mode = session.serverpod.runMode;
  if (mode == ServerpodRunMode.development || mode == ServerpodRunMode.test) {
    session.log('Login code for $email: $verificationCode');
    return;
  }

  final apiKey = session.passwords['resendApiKey'];
  final from = session.passwords['resendFrom'];
  if (apiKey == null || from == null) {
    throw StateError('resendApiKey and resendFrom must be set in passwords');
  }

  final response = await http.post(
    Uri.parse('https://api.resend.com/emails'),
    headers: {
      'Authorization': 'Bearer $apiKey',
      'Content-Type': 'application/json',
    },
    body: jsonEncode({
      'from': from,
      'to': [email],
      'subject': 'Your Tell Me a Story sign-in code',
      'text': 'Your sign-in code is $verificationCode. It expires soon.',
    }),
  );
  if (response.statusCode >= 300) {
    session.log(
      'Resend rejected login email: ${response.statusCode} ${response.body}',
      level: LogLevel.error,
    );
    throw StateError('Login email could not be sent');
  }
}
```

`apps/server/lib/src/auth/auth_config.dart`:

```dart
import 'package:serverpod/serverpod.dart';
import 'package:serverpod_auth_idp_server/core.dart';
import 'package:serverpod_auth_idp_server/providers/email.dart';

import '../generated/protocol.dart';
import 'login_code_sender.dart';

/// Fixed one-time login code used in the development and test run modes.
const devLoginCode = '111111';

/// Registers JWT sessions and passwordless email-code login, and creates the
/// app's `users` row whenever an auth user is created.
///
/// Called from `run` before the server starts, and from test `setUpAll`
/// because `withServerpod` does not execute `run`.
void configureAuth({required bool useDevLoginCode}) {
  AuthServices.set(
    tokenManagerBuilders: [JwtConfigFromPasswords()],
    identityProviderBuilders: [
      EmailIdpConfigFromPasswords(
        sendOtpLoginVerificationCode: sendLoginCode,
        otpLoginVerificationCodeGenerator: useDevLoginCode
            ? () => devLoginCode
            : defaultOtpVerificationCodeGenerator,
      ),
    ],
    authUsersConfig: const AuthUsersConfig(
      onAfterAuthUserCreated: _createAppUser,
    ),
  );
}

Future<void> _createAppUser(
  Session session,
  AuthUserModel authUser, {
  required Transaction transaction,
}) async {
  await AppUser.db.insertRow(
    session,
    AppUser(authUserId: authUser.id),
    transaction: transaction,
  );
}
```

`apps/server/lib/server.dart` (constraints are wired in Task 5):

```dart
import 'src/auth/auth_config.dart';
import 'src/generated/serverpod.dart';

/// The starting point of the Serverpod server.
void run(List<String> args) async {
  final pod = Serverpod(args);

  // Superseded: as built, the dev code is gated by isLocalPod(pod)
  // (apps/server/lib/src/auth/local_mode.dart): run mode development/test
  // AND an embedded Postgres (database.dataPath). The run-mode-only check
  // below would enable the fixed code against a real database.
  configureAuth(
    useDevLoginCode: pod.runMode == ServerpodRunMode.development ||
        pod.runMode == ServerpodRunMode.test,
  );

  pod.addCloudStorage(DatabaseCloudStorage('private'));

  await pod.start();
}
```

- [ ] **Step 4: Run it and confirm it passes**

```bash
mise exec -- just server-test   # Expected: +2: All tests passed!
```

- [ ] **Step 5: Commit**

```bash
git add apps/server && git commit -m "feat(server): passwordless email-code login with dev code"
```

### Task 5: Raw SQL constraints

**Files:**
- Create: `apps/server/test/integration/constraints_test.dart`
- Create: `apps/server/lib/src/db/constraints.dart`
- Modify: `apps/server/lib/server.dart`

- [ ] **Step 1: Write the failing test**

```dart
import 'package:serverpod/serverpod.dart';
import 'package:serverpod_auth_idp_server/core.dart';
import 'package:tell_me_a_story_server/src/auth/auth_config.dart';
import 'package:tell_me_a_story_server/src/db/constraints.dart';
import 'package:tell_me_a_story_server/src/generated/protocol.dart';
import 'package:test/test.dart';

import 'test_tools/serverpod_test_tools.dart';

void main() {
  setUpAll(() => configureAuth(useDevLoginCode: true));

  withServerpod('Given the raw SQL constraints', (sessionBuilder, endpoints) {
    late Session session;

    setUp(() async {
      session = sessionBuilder.build();
      await session.db.unsafeSimpleExecute(constraintsSql);
    });

    test('when a second owner is added to a family then the insert fails',
        () async {
      final a = await AuthServices.instance.authUsers.create(session);
      final b = await AuthServices.instance.authUsers.create(session);
      final tree = await Tree.db.insertRow(session, Tree());
      final family = await Family.db.insertRow(
        session,
        Family(treeId: tree.id!, name: 'Mortang'),
      );
      await Membership.db.insertRow(
        session,
        Membership(familyId: family.id!, userId: a.id, role: MembershipRole.owner),
      );

      await expectLater(
        Membership.db.insertRow(
          session,
          Membership(
            familyId: family.id!,
            userId: b.id,
            role: MembershipRole.owner,
          ),
        ),
        throwsA(isA<DatabaseQueryException>()),
      );
    });

    test('when the constraints run twice then the second run succeeds',
        () async {
      await session.db.unsafeSimpleExecute(constraintsSql);
    });
  }, rollbackDatabase: RollbackDatabase.disabled);
}
```

- [ ] **Step 2: Run it and confirm it fails**

```bash
cd apps/server && mise exec -- dart test test/integration/constraints_test.dart
# Expected: compile error, constraints.dart not found
```

- [ ] **Step 3: Implement `apps/server/lib/src/db/constraints.dart`**

The SQL is the §3.3 block of `docs/migration/schema-design.md`, embedded as a Dart const so deploys don't depend on a file path.

```dart
import '../generated/serverpod.dart';

/// Applies [constraintsSql] after Serverpod has run its migrations.
Future<void> applyConstraints(Serverpod pod) async {
  final session = await pod.createSession();
  try {
    await session.db.unsafeSimpleExecute(constraintsSql);
  } finally {
    await session.close();
  }
}

/// Constraints Serverpod models cannot express. Idempotent; run after
/// migrations on every boot and in test setup.
const constraintsSql = r'''
-- Invariants Serverpod model YAML cannot express. Idempotent: safe to run on
-- every server start after Serverpod has applied its migrations.
-- Column names are Serverpod's quoted camelCase field names.
-- DatePrecision is serialized byIndex: 0 = year, 1 = month, 2 = day.

-- One owner per family (partial unique index).
CREATE UNIQUE INDEX IF NOT EXISTS memberships_one_owner_uidx
  ON memberships ("familyId")
  WHERE "role" = 'owner';

DO $constraints$
DECLARE
  c record;
BEGIN
  FOR c IN
    SELECT * FROM (VALUES
      -- families -----------------------------------------------------------
      ('families', 'families_parent_not_self',
        $$CHECK ("parentId" IS NULL OR "parentId" <> "id")$$),
      ('families', 'families_name_not_blank',
        $$CHECK (btrim("name") <> '')$$),
      ('families', 'families_branch_year_range',
        $$CHECK ("branchYear" IS NULL OR "branchYear" BETWEEN 1 AND 9999)$$),
      -- A branch's parent must be in the same tree (needs families_id_tree_uidx).
      ('families', 'families_parent_same_tree_fk',
        $$FOREIGN KEY ("parentId", "treeId") REFERENCES families ("id", "treeId")
          ON DELETE SET NULL ("parentId")$$),
      -- memberships --------------------------------------------------------
      ('memberships', 'memberships_role_valid',
        $$CHECK ("role" IN ('owner', 'coOwner', 'member'))$$),
      -- people -------------------------------------------------------------
      -- people.treeId must equal the family's treeId.
      ('people', 'people_family_tree_fk',
        $$FOREIGN KEY ("familyId", "treeId") REFERENCES families ("id", "treeId")
          ON DELETE CASCADE$$),
      ('people', 'people_name_not_blank',
        $$CHECK (btrim("name") <> '')$$),
      ('people', 'people_about_len',
        $$CHECK ("about" IS NULL OR char_length("about") <= 500)$$),
      ('people', 'people_email_normalized',
        $$CHECK ("email" IS NULL OR ("email" <> '' AND "email" = lower(btrim("email"))))$$),
      -- users --------------------------------------------------------------
      ('users', 'users_about_len',
        $$CHECK ("about" IS NULL OR char_length("about") <= 500)$$),
      ('users', 'users_birth_pair',
        $$CHECK (("birthDate" IS NULL) = ("birthPrecision" IS NULL))$$),
      ('users', 'users_birth_midnight',
        $$CHECK ("birthDate" IS NULL OR "birthDate" = date_trunc('day', "birthDate"))$$),
      -- stories ------------------------------------------------------------
      -- Dates are all-null (undated draft) or a well-formed year/month/day span.
      ('stories', 'stories_date_shape',
        $$CHECK (
          ("dateStart" IS NULL AND "dateEnd" IS NULL AND "datePrecision" IS NULL)
          OR (
            "dateStart" IS NOT NULL AND "dateEnd" IS NOT NULL AND "datePrecision" IS NOT NULL
            AND "dateStart" = date_trunc('day', "dateStart")
            AND extract(year FROM "dateStart") BETWEEN 1000 AND 9999
            AND (
              ("datePrecision" = 2 AND "dateEnd" = "dateStart")
              OR ("datePrecision" = 1
                  AND "dateStart" = date_trunc('month', "dateStart")
                  AND "dateEnd" = date_trunc('month', "dateStart") + interval '1 month' - interval '1 day')
              OR ("datePrecision" = 0
                  AND "dateStart" = date_trunc('year', "dateStart")
                  AND "dateEnd" = date_trunc('year', "dateStart") + interval '1 year' - interval '1 day')
            )
          )
        )$$),
      ('stories', 'stories_published_needs_date',
        $$CHECK ("status" <> 'published' OR ("dateStart" IS NOT NULL AND "publishedAt" IS NOT NULL))$$),
      ('stories', 'stories_status_valid',
        $$CHECK ("status" IN ('draft', 'published'))$$),
      -- photos -------------------------------------------------------------
      ('photos', 'photos_edit_version_nonnegative',
        $$CHECK ("editVersion" >= 0)$$),
      ('photos', 'photos_edited_needs_version',
        $$CHECK ("editedKey" IS NULL OR "editVersion" > 0)$$),
      -- story_notes --------------------------------------------------------
      ('story_notes', 'story_notes_body_not_blank',
        $$CHECK (btrim("body") <> '')$$),
      ('story_notes', 'story_notes_kind_valid',
        $$CHECK ("kind" IN ('comment', 'perspective'))$$),
      -- invites ------------------------------------------------------------
      ('invites', 'invites_token_hash_shape',
        $$CHECK ("tokenHash" ~ '^[0-9a-f]{64}$')$$),
      ('invites', 'invites_email_normalized',
        $$CHECK ("email" IS NULL OR ("email" <> '' AND "email" = lower(btrim("email"))))$$),
      -- acceptedById may be nulled later by account deletion, so one direction only.
      ('invites', 'invites_accepted_by_needs_at',
        $$CHECK ("acceptedById" IS NULL OR "acceptedAt" IS NOT NULL)$$),
      ('invites', 'invites_not_accepted_and_revoked',
        $$CHECK ("acceptedAt" IS NULL OR "revokedAt" IS NULL)$$),
      ('invites', 'invites_expiry_after_create',
        $$CHECK ("expiresAt" > "createdAt")$$)
    ) AS t(tbl, name, def)
  LOOP
    IF NOT EXISTS (
      SELECT 1 FROM pg_constraint
      WHERE conname = c.name AND conrelid = c.tbl::regclass
    ) THEN
      EXECUTE format('ALTER TABLE %I ADD CONSTRAINT %I %s', c.tbl, c.name, c.def);
    END IF;
  END LOOP;
END
$constraints$;
''';
```

Then wire it into `apps/server/lib/server.dart`:

```dart
import 'src/auth/auth_config.dart';
import 'src/db/constraints.dart';
import 'src/generated/serverpod.dart';

/// The starting point of the Serverpod server.
void run(List<String> args) async {
  final pod = Serverpod(args);

  // Superseded: as built, the dev code is gated by isLocalPod(pod)
  // (apps/server/lib/src/auth/local_mode.dart): run mode development/test
  // AND an embedded Postgres (database.dataPath). The run-mode-only check
  // below would enable the fixed code against a real database.
  configureAuth(
    useDevLoginCode: pod.runMode == ServerpodRunMode.development ||
        pod.runMode == ServerpodRunMode.test,
  );

  pod.addCloudStorage(DatabaseCloudStorage('private'));

  await pod.start();
  await applyConstraints(pod);
}
```

- [ ] **Step 4: Run it and confirm it passes**

```bash
mise exec -- just server-test   # Expected: +4: All tests passed!
```

- [ ] **Step 5: Commit**

```bash
git add apps/server && git commit -m "feat(server): enforce raw SQL constraints on boot"
```

### Task 6: AppException and family-level authorization

**Files:**
- Create: `apps/server/test/integration/authz_test.dart`
- Create: `apps/server/lib/src/models/app_exception.spy.yaml`, `apps/server/lib/src/authz/authz.dart`

Semantic change from the old SQL: tree membership is `treeId` equality among live families. The old recursive walk split the tree at a soft-deleted middle family; this version doesn't. Story-level predicates (`canContribute`, `canEditStory`, `familyOrigin`) arrive with the Phase 3 story slice.

- [ ] **Step 1: Write the failing test**

```dart
import 'package:serverpod/serverpod.dart';
import 'package:serverpod_auth_idp_server/core.dart';
import 'package:tell_me_a_story_server/src/auth/auth_config.dart';
import 'package:tell_me_a_story_server/src/authz/authz.dart';
import 'package:tell_me_a_story_server/src/generated/protocol.dart';
import 'package:test/test.dart';

import 'test_tools/serverpod_test_tools.dart';

void main() {
  setUpAll(() => configureAuth(useDevLoginCode: true));

  withServerpod('Given families in one tree', (sessionBuilder, endpoints) {
    late Session db;
    late UuidValue owner, member, branchMember, stranger;
    late Family root, branch, deletedBranch;

    Authz authzFor(UuidValue? user) => Authz(
          (user == null
                  ? sessionBuilder
                  : sessionBuilder.copyWith(
                      authentication: AuthenticationOverride.authenticationInfo(
                        user.uuid,
                        {},
                      ),
                    ))
              .build(),
        );

    Future<UuidValue> newUser() async =>
        (await AuthServices.instance.authUsers.create(db)).id;

    Future<void> join(Family f, UuidValue user, MembershipRole role) =>
        Membership.db.insertRow(
          db,
          Membership(familyId: f.id!, userId: user, role: role),
        );

    setUp(() async {
      db = sessionBuilder.build();
      owner = await newUser();
      member = await newUser();
      branchMember = await newUser();
      stranger = await newUser();
      final tree = await Tree.db.insertRow(db, Tree());
      root = await Family.db.insertRow(
        db,
        Family(treeId: tree.id!, name: 'Root'),
      );
      branch = await Family.db.insertRow(
        db,
        Family(treeId: tree.id!, parentId: root.id, name: 'Branch'),
      );
      deletedBranch = await Family.db.insertRow(
        db,
        Family(
          treeId: tree.id!,
          parentId: root.id,
          name: 'Gone',
          deletedAt: DateTime.now().toUtc(),
        ),
      );
      await join(root, owner, MembershipRole.owner);
      await join(root, member, MembershipRole.member);
      await join(branch, branchMember, MembershipRole.member);
      await join(deletedBranch, member, MembershipRole.owner);
    });

    test('owner is steward and member is not', () async {
      expect(await authzFor(owner).isSteward(root.id!), isTrue);
      expect(await authzFor(member).isSteward(root.id!), isFalse);
    });

    test('membership in a soft-deleted family is not live', () async {
      expect(await authzFor(member).isMember(deletedBranch.id!), isTrue);
      expect(await authzFor(member).isLiveMember(deletedBranch.id!), isFalse);
    });

    test('branch member can read the parent family through the tree', () async {
      expect(await authzFor(branchMember).isTreeReadable(root.id!), isTrue);
      expect(await authzFor(branchMember).isMember(root.id!), isFalse);
    });

    test('a soft-deleted family is not a tree member target', () async {
      expect(await authzFor(owner).isTreeMember(deletedBranch.id!), isFalse);
    });

    test('stranger and anonymous callers get nothing', () async {
      expect(await authzFor(stranger).isTreeReadable(root.id!), isFalse);
      expect(await authzFor(null).isMember(root.id!), isFalse);
      expect(
        () => authzFor(null).requireUser(),
        throwsA(isA<AppException>().having((e) => e.code, 'code', 'auth_required')),
      );
    });
  }, rollbackDatabase: RollbackDatabase.disabled);
}
```

- [ ] **Step 2: Run it and confirm it fails**

```bash
cd apps/server && mise exec -- dart test test/integration/authz_test.dart
# Expected: compile error, authz.dart not found
```

- [ ] **Step 3: Implement**

`apps/server/lib/src/models/app_exception.spy.yaml`:

```yaml
### Single error envelope for every endpoint.
### code: auth_required | forbidden | not_found | validation | conflict |
###       invite_invalid | invite_accepted | invite_expired
exception: AppException
fields:
  code: String
  message: String
```

`apps/server/lib/src/authz/authz.dart`:

```dart
import 'package:serverpod/serverpod.dart';
import 'package:serverpod_auth_idp_server/core.dart';

import '../generated/protocol.dart';

/// Family-level authorization predicates (business-rules.md §1).
///
/// Every predicate is false for an unauthenticated session. "Live" means the
/// family has no `deletedAt`. Tree membership is equality on `treeId`.
class Authz {
  Authz(this.session);

  final Session session;

  UuidValue? get userId => session.authenticated?.authUserId;

  /// Returns the caller's id or throws `AppException(code: 'auth_required')`.
  UuidValue requireUser() {
    final id = userId;
    if (id == null) {
      throw AppException(code: 'auth_required', message: 'Sign in to continue.');
    }
    return id;
  }

  Future<MembershipRole?> roleIn(UuidValue familyId) async {
    final uid = userId;
    if (uid == null) return null;
    final row = await Membership.db.findFirstRow(
      session,
      where: (t) => t.familyId.equals(familyId) & t.userId.equals(uid),
    );
    return row?.role;
  }

  /// Membership in [familyId], ignoring soft delete.
  Future<bool> isMember(UuidValue familyId) async =>
      await roleIn(familyId) != null;

  Future<bool> isOwner(UuidValue familyId) async =>
      await roleIn(familyId) == MembershipRole.owner;

  /// Owner or co-owner, ignoring soft delete.
  Future<bool> isSteward(UuidValue familyId) async {
    final role = await roleIn(familyId);
    return role == MembershipRole.owner || role == MembershipRole.coOwner;
  }

  /// Membership in [familyId] and the family is not soft-deleted.
  Future<bool> isLiveMember(UuidValue familyId) async {
    final family = await Family.db.findById(session, familyId);
    if (family == null || family.deletedAt != null) return false;
    return isMember(familyId);
  }

  /// Caller is a member of some live family in the same tree as [familyId].
  Future<bool> isTreeReadable(UuidValue familyId) async {
    final uid = userId;
    if (uid == null) return false;
    final family = await Family.db.findById(session, familyId);
    if (family == null) return false;
    final memberships = await Membership.db.find(
      session,
      where: (t) => t.userId.equals(uid),
    );
    if (memberships.isEmpty) return false;
    final count = await Family.db.count(
      session,
      where: (t) =>
          t.id.inSet(memberships.map((m) => m.familyId).toSet()) &
          t.treeId.equals(family.treeId) &
          t.deletedAt.equals(null),
    );
    return count > 0;
  }

  /// [isTreeReadable] and [familyId] itself is live.
  Future<bool> isTreeMember(UuidValue familyId) async {
    final family = await Family.db.findById(session, familyId);
    if (family == null || family.deletedAt != null) return false;
    return isTreeReadable(familyId);
  }

  /// Throws `AppException(code: 'forbidden')` unless [allowed].
  void ensure(bool allowed) {
    if (!allowed) {
      throw AppException(
        code: 'forbidden',
        message: "You don't have access to that.",
      );
    }
  }
}
```

```bash
mise exec -- just server-generate
```

- [ ] **Step 4: Run it and confirm it passes**

```bash
mise exec -- just server-test   # Expected: +9: All tests passed!
```

- [ ] **Step 5: Commit**

```bash
git add apps/server packages/tell_me_a_story_client && git commit -m "feat(server): AppException and family authorization predicates"
```

### Task 7: Phase gate

- [ ] **Step 1:** `mise exec -- just server-test`. Expected: `+9: All tests passed!`
- [ ] **Step 2:** `cd apps/server && mise exec -- dart analyze && mise exec -- dart format --set-exit-if-changed lib test`. Expected: no issues; if anything gets reformatted, commit it as `style(server): dart format`.
- [ ] **Step 3:** `mise exec -- just test`. Expected: the Flutter suite is unchanged (677 passing).
- [ ] **Step 4:** Smoke: `mise exec -- just server`, then in another shell run `curl -s -X POST http://localhost:8080/emailIdp -H 'content-type: application/json' -d '{"method":"startOtpLogin","email":"smoke@example.com"}'`. Expected: a quoted UUID and HTTP 200.
