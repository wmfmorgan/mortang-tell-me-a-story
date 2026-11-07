# Endpoint contract: Flutter gateways → Serverpod 4.1.1

Paths are relative to `apps/tell_me_a_story/` unless they say otherwise. "ids" means `UuidValue` on the wire and `String` in the client domain models (see §2.0).

---

## 0. Ground rules this contract assumes

| Topic | Decision | Source |
|---|---|---|
| Server | Serverpod **4.1.1**. Endpoints extend `Endpoint`. Streams are endpoint methods that return `Stream<T>`; fan-out uses `session.messages.createStream<T>(channel)` and `session.messages.postMessage(channel, msg)` | https://docs.serverpod.dev/concepts/streams ("live updates for a filtered query") |
| Login | `class EmailIdpEndpoint extends EmailOtpIdpBaseEndpoint {}`. The client calls `startOtpLogin(email) → UuidValue`, then `verifyOtpLoginCode(otpLoginRequestId:, verificationCode:) → EmailAccountOtpVerificationResult{token, accountExists, allowPassword}`, then `finishOtpLogin(otpLoginToken:)` or, for a new email, `finishOtpRegistration(otpLoginToken:)`. Both return `AuthSuccess{authUserId, token, refreshToken, …}` | `serverpod_auth_idp_server-4.1.1/lib/src/providers/email/endpoints/email_otp_idp_base_endpoint.dart:39,63,87,113` (pub archive); fields `…/email_account_otp_verification_result.dart:52-60`; `serverpod_auth_core_client-4.1.1/lib/src/protocol/common/models/auth_success.dart:62-79` |
| Dev code delivery | Set `EmailIdpConfig.sendOtpLoginVerificationCode` to a callback that logs the code. If it is unset, codes go through `sendRegistrationVerificationCode` | https://docs.serverpod.dev/concepts/authentication/providers/email/setup |
| Client session | `client.auth` is a `FlutterAuthSessionManager`. It exposes `authInfoListenable: ValueListenable<AuthSuccess?>`, `authInfo`, `isAuthenticated`, `initialize()`, `updateSignedInUser(AuthSuccess?)`, `signOutDevice()` | `serverpod_auth_core_flutter-4.1.1/lib/src/session_manager.dart:68,93`; `serverpod_auth_core_client-4.1.1/lib/src/session_manager.dart:65-272` |
| Blobs | Large images (story photos, family covers) use `session.storage.createUploadDescription(...)`, then the client's `FileUploader(desc).upload(...)`, then `session.storage.verifyUpload(...)`. Small images (512 px avatars) go inline as a `ByteData` argument, which stays under the 512 KiB `maxRequestSize` default. Reads go through an authorized endpoint that returns `ByteData` (`session.storage.retrieveFile`) | https://docs.serverpod.dev/concepts/file-uploads |
| Errors | One serializable exception `AppException{code: AppErrorCode, message: String}`, with `AppErrorCode` = `notFound, forbidden, validation, inviteInvalid, conflict, photoCap, storageFailed`. Unauthenticated calls are rejected by Serverpod itself (`requireLogin = true` on every app endpoint except `InviteEndpoint.preview`) | https://docs.serverpod.dev/concepts/endpoints-and-apis/error-handling-and-exceptions |
| Schema | Per `docs/migration/schema-design.md` (§1 models, §3 constraints). UUID PKs. The `AppUser` model (table `users`) holds displayName, avatarKey, about, birthDate, birthPrecision and birthVisibility. People carry their own life dates (birthDate/birthPrecision, deathDate/deathPrecision); while a person is linked to a user, the account birth wins, coarsened by birthVisibility. Email is read from `serverpod_auth_idp_email_account.email` | `docs/migration/schema-design.md` |

### Why the client keeps its domain models
Features read `Story`, `Person`, `Place` and the other domain classes in hundreds of places. For example, `.id` appears 402 times and `.familyId` 78 times in feature/core code, counted outside `lib/data`. They also depend on the `abstract class *Gateway` seams that tests fake. So the gateway **interfaces stay**, the **`*Api` classes keep their names**, and only their bodies change. Each body calls the generated `Client` and maps the protocol DTO to the domain class: `String` ↔ `UuidValue`, and date-only `DateTime` ↔ UTC midnight. The `fromJson` factories and the PostgREST embed parsers (`_embedLabel`, `_storyPeople`, …) are deleted.

Dates: `timeframe_start/end`, `birth_date` and the other date-only values travel as `DateTime.utc(y, m, d)`. The adapters rebuild them with `DateTime(v.year, v.month, v.day)` and **never** call `toLocal()`. This replaces `_date()` / `_parseDate()` in `lib/data/stories_api.dart:758-827`.

---

## 1. Gateway inventory: what each method does today

Abbreviations: **T** = PostgREST table call, **E** = embed, **R** = RPC, **F** = edge function, **S** = Storage bucket. "Used fields" are the fields features actually read, counted by regex over `lib/features` and `lib/core`. Fields nobody reads are marked *unused*.

### 1.1 `FamiliesGateway` (`lib/data/families_api.dart:169-225`, impl `:336-712`)
| Method | Today | Returns / used fields |
|---|---|---|
| `listMine()` | T `memberships` E `families!inner(id,name,parent_family_id,branch_year,created_at,deleted_at,cover_photo_path)` where `user_id = uid`, `families.deleted_at is null`. Retries without `cover_photo_path` on `familiesCoverColumnMissing` (`:396-429`) | `List<MemberFamily>{id,name,parentFamilyId,createdAt,branchYear,role,coverPhotoPath}`. All are read (`parentFamilyId` 16×, `role` 24×, `branchYear` 4×, `coverPhotoPath` 4×) |
| `listStewarded()` | T `memberships` E `families!inner(id,name,deleted_at)` with role ∈ {owner, co_owner}, then client filter on the 60-day window (`:497-511`) | `List<StewardFamily>{id,name,role,deletedAt}` |
| `setFamilyOrigin({familyId, storyId})` | R `set_family_origin(p_family_id,p_story_id)`. Errors map to `OriginRpcException` (`:450-464`) | void |
| `listOriginDependents(storyId)` | R `list_origin_dependents(p_story_id)` (`:466-494`) | `List<OriginDependent>{familyId,name}` |
| `setCoverPhoto({familyId, bytes, previousPath})` | S `family-covers` upload (compress 1920, ≤5 MB), T `families.update(cover_photo_path)`, S remove previous (`:359-376`, `family_covers.dart:59-88`) | `String` path |
| `clearCoverPhoto({familyId, path})` | S list+remove `{familyId}/*`, T update `cover_photo_path=null` (`:380-389`) | void |
| `listMembers(familyId)` | T `memberships` E `profiles(display_name,avatar_path)`, then **N+1** S `avatars` download per member (`:553-588`) | `List<FamilyPerson>{userId,role,displayName,avatarBytes}` |
| `listFamilyTree(familyId)` | R `list_family_tree(fid)` (`:431-447`) | `List<TreeFamily>{id,name,parentFamilyId,branchYear,originStoryId}` (`originStoryId` 19×) |

### 1.2 `FamilyDirectoryGateway` (`families_api.dart:331-334`)
| Method | Today | Returns |
|---|---|---|
| `listDirectory()` | 2× T memberships (active / deleted), T `memberships` count by family, T `stories` published count, plus client filtering (`:513-550`). **4 round trips** | `FamilyDirectory{active,recoverable: List<FamilyRoster{id,name,role,memberCount,publishedCount,deletedAt}>}` |
| `loadDetail(familyId)` | T `families(id,name)` + `listMembers` (N+1 avatars) + T `invites(id,email,expires_at)` status=pending order email (`:590-632`) | `FamilyDetail{id,name,myRole,people,pendingInvites{id,email,expiresAt,createdAt→sentAt,isExpired}}` |

### 1.3 `FamilyCoverClient` (`family_covers.dart:35-41`, also implemented by `FamiliesApi`)
`download(path)` → S `family-covers` download, null on `StorageException`. `save` and `clear` are the internals of 1.1.

### 1.4 `StoriesGateway` (`stories_api.dart:354-413`, impl `:416-755`)
`_storySelect` (`:422-423`) = story columns + `story_people(person_id)` + `photos(id,storage_path,edited_storage_path,edit_version,sort_order)` + `profiles!author_id(display_name,avatar_path)`.
`_publishedSelect` (`:425-426`) = the above + `places(label,address)` + `story_people(person_id, people(name,user_id))` + `comments(id)` + `perspectives(id)` (the last two are only counted).

| Method | Today | Returns |
|---|---|---|
| `createDraft({id?, familyId, timeframeStart?, timeframeEnd?, datePrecision?, title?, body?, placeId?, allowUndated, personIds})` | T insert stories (client-supplied id allowed), T delete+insert `story_people`, then `getStory` (`:428-465`). **4 round trips**. A retried id raises 23505, which `new_story_page.dart:726-729` handles | `Story` |
| `updateDraft({storyId, …, personIds?})` | T update (patch of non-null fields; `placeId == ''` clears), replace people, `getStory` (`:467-491, 517-571`) | `Story` |
| `autosaveDraft({…})` | Same, with `status = 'draft'` guard. Returns false when nothing matched (`:493-515`) | `bool` |
| `publish(storyId)` | `getStory` → client `publishReadiness` → T update status, published_at → `getStory` (`:573-593`) | `Story` |
| `getStory(storyId)` | T `_storySelect` single (`:595-603`) | `Story` |
| `getPublished(storyId)` | T `_storySelect`, status=published, maybeSingle (`:605-608`) | `Story?` |
| `listMyDrafts(familyId)` | T `_storySelect` author = uid, status = draft (`:653-669`) | `List<Story>` |
| `listPublished(familyId)` | T `_publishedSelect` (`:671-683`) | `List<Story>` |
| `getPublishedOrigin(storyId)` | T `_publishedSelect` single (`:685-688`) | `Story?` |
| `listLatestPublished(familyId,{withinDays,limit,now})` | T stories + photos, `published_at >= cutoff` (`:701-729`) | `List<Story>` |
| `discard(storyId)` | T delete stories (`:731-734`). `drafts_page.dart:254` calls `PhotosGateway.deleteAllForStory` first | void |
| `linkPerson({storyId, personId})` | T insert `story_people` (`:736-745`). Duplicates raise 23505, which `new_story_page.dart:468-480` swallows | void |
| *(not on interface)* `StoriesApi.storiesForPerson(personId)` | T stories with `story_people!inner` filter, then **N+1** S `createSignedUrl` per thumb (`:610-651`). Called by `person_profile_dialog.dart:607` | `List<PersonStoryCard>{id,title,whenLabel,place,photoCount,thumbUrl}` |
| *(top-level)* `downloadFirstThumbs(stories, photos)` | **N+1** `PhotosGateway.downloadBytes` per story (`:840-866`) | `Map<storyId, Uint8List>` |

Story fields features read: all except `createdAt` (4×, sort only). `authorAvatarPath` 1× (`story_reader_page.dart:479`), `commentCount`/`perspectiveCount` 1× (`timeline_page.dart:3381`), `personUserIds` 2× (`all_stories_logic.dart:211-213`), `placeAddress` 3×, `photoPaths` 5× (first path = thumb).

### 1.5 `PeopleGateway` (`people_api.dart:168-220`, impl `:223-475`)
| Method | Today | Returns |
|---|---|---|
| `listPeople(familyId)` | T `people` `_rowSelect` order name (`:235-243`) | `List<Person>` |
| `listTreePeople(familyId)` | R `list_family_tree`, T `people` in tree ids, then **N+1** R `person_profile` per linked row (`:245-288`) | `List<Person>{id,familyId,name,userId,passedAway,birthDate,birthPrecision}` |
| `createPerson({familyId,name,about?,email?,passedAway,pictureBytes?})` | T insert; if a picture is given: S `person-avatars/{id}/avatar.jpg` upsert, T update `avatar_path` (`:290-321`) | `Person` |
| `personForEdit(personId)` | T `people` single (`:323-332`) | `Person?` (includes `userId`, `email`) |
| `personProfile(personId)` | R `person_profile`. `NOT_FOUND:` maps to `PersonProfileNotFound` (`:334-348`) | `PersonProfile{id,familyId,name,isLinked,birthDate,birthPrecision,about,avatarPath,passingDate,passingPrecision,passedAway}` |
| `updatePerson({personId,name,passedAway?,about?,email?,pictureBytes?,clearPicture})` with `write*` flags | T update patch, optional picture upload + update (`:350-389`). Duplicate email → 23505 (`invite_chrome_test.dart:262-336`) | `Person` |
| `listUnlinkedPeople(familyId)` | R `list_unlinked_people(p_family_id)` (`:416-433`) | `List<Person>{id,familyId,name,email}` |
| `isHomeFamilySteward(familyId)` | T `memberships.role` for uid (`:391-403`) | `bool` |
| `markPassedAway({personId,value})` | R `mark_passed_away` (`:405-414`). `FORBIDDEN:` is surfaced via `mapRpcError` (`person_profile_dialog.dart:230`) | void |
| `signedPictureUrl({personId,path})` | S signed URL, `person-avatars` or `avatars` (`:435-445`). Used by `Image.network` in `edit_person_dialog.dart:82,434` and `person_profile_dialog.dart:145,558` | `String?` |

Person fields that are *unused* in features: `passingDate`, `passingPrecision`, `createdBy`. `relationship` is read in `story_reader_page.dart:1368`, but every write sends null (`people_api.dart:308`).

### 1.6 `PhotosGateway` (`photos_api.dart:162-181`, impl `:190-378`)
| Method | Today | Returns |
|---|---|---|
| `listPhotos(storyId)` | T `photos` order sort_order (`:226-234`) | `List<Photo>{id,storyId,familyId,uploaderId,storagePath,editedStoragePath,editVersion,sortOrder}`. Features read `uploaderId` (`story_reader_page.dart:1017`), `effectiveStoragePath`, `id`, and `sortOrder` via `photosWithHeroFirst` |
| `uploadPhoto({familyId,storyId,bytes,sortOrder})` | T count (cap 20) → compress → S upload `{family}/{story}/{photo}.jpg` → T insert; removes the object if the insert fails (`:236-272`) | `Photo` |
| `deletePhoto(photo)` | S remove original+edited, T delete (`:294-306`) | void |
| `setHeroPhoto({storyId,photoId})` | `listPhotos` + **N** T updates of sort_order (`:274-292`) | void |
| `deleteAllForStory({familyId,storyId})` | S list prefix + remove (`:308-326`) | void |
| `downloadBytes(storagePath)` | S `story-photos` download (`:328-332`) | `Uint8List` |

### 1.7 `CommentsGateway` / `PerspectivesGateway` (`comments_api.dart:43-52`, `perspectives_api.dart:43-52`)
Each has the same four methods: `listForStory(storyId)` (T select `*, author:profiles!author_id(display_name)` order created_at), `create({storyId,familyId,body})`, `update({id,body})`, `delete(id)`. They return `Comment` / `Perspective{id,storyId,familyId,authorId,body,createdAt,authorDisplayName}`.

### 1.8 `PlacesGateway` (`places_api.dart:77-97`)
`listPlaces`, `listFavorites`, `listRecents(limit 10)`, `createPlace`, `markUsed`, `setFavorite`, `findByMapboxPlaceId`, `getPlace`. Every one is a single T `places` call over `id,family_id,label,address,lat,lng,mapbox_place_id,is_favorite,last_used_at`. Features read all fields except `mapboxPlaceId` and `lastUsedAt`, which are only used as filters.

### 1.9 `InviteGateway` (`invite_api.dart:14-24`) and `InviteLinkGateway` (`:194-196`)
| Method | Today | Returns |
|---|---|---|
| `currentFamilyId()` | Binds `ProfileSession` / `FamilySelection` to uid. T memberships (live families) used to validate the remembered id, else T memberships `limit(1)` (`:33-69`) | `String?` |
| `createFamily(name)` | R `create_family(p_name)` (`:72-77`). Called by `drafts_page.dart:224`, `new_story_page.dart:429` and `timeline_page.dart:437` with `'Family'` | `String` id |
| `createInvite({familyId,email?,personId?})` | F `create-invite` (201) (`:79-99`) | `CreateInviteResult{inviteId,token,expiresAt,inviteUrl}` |
| `sendInviteEmail({inviteId})` | F `send-invite-email` | void |
| `acceptInvite({token})` | F `accept-invite` | `AcceptInviteResult{familyId,membershipId}`. Only `familyId` is read (`invite_sign_in_page.dart:120`) |
| `validateInviteToken(token)` (link gateway, unauthenticated) | F GET `validate-invite-token` | `InvitePreview{valid,familyId,familyName,inviterName}` |

Errors are mapped to `InviteApiException{code,message}` (`:115-144`).

### 1.10 `ManageFamiliesGateway` (`manage_families_api.dart:3-30`)
Each method is one F call; errors map to `ManageFamiliesException{code,message}`. `start_timeline_dialog.dart:215-225` branches on code `NOT_FOUND` / `FORBIDDEN`.
`createRootFamily(name)` → `create-root-family` (201, `family_id`). `createBranchFamily({parentFamilyId,originStoryId,name,branchYear,ownerUserId,personIds})` → `create-branch-family`. `renameFamily`, `addCoOwner`, `removeCoOwner`, `removeMember`, `transferOwnership({familyId,newOwnerUserId,formerOwnerBecomes})`, `softDeleteFamily`, `recoverFamily`, `resendInvite(inviteId) → DateTime expiresAt`, `revokeInvite(inviteId)`.

### 1.11 `ProfileGateway` (`profile_api.dart:83-108`)
| Method | Today | Returns |
|---|---|---|
| `loadOwn()` | T `profiles(id,display_name,email,avatar_path,about)` + R `my_profile` for birth (`:150-169`) | `OwnProfile{id,displayName,email,avatarPath,birthDate,birthPrecision,birthVisibility,about}` |
| `saveName(displayName)` | T update | void |
| `saveAccount({displayName,birthDate?,birthPrecision?,birthVisibility?,about?})` | T update | void |
| `saveAvatar(bytes)` | compress 512 → S `avatars/{uid}/avatar.jpg` upsert → T update (`:193-213`) | `String` path |
| `clearAvatar()` | T update avatar_path=null | void |
| `downloadAvatar(path)` | S signed URL + `http.get` (`:220-231`) | `Uint8List?` |
| `updateEmail(email)` | `auth.updateUser(email)` (GoTrue email-change flow) (`:233-240`) | void |

### 1.12 `SearchGateway` (`search_api.dart:180-209`)
`search(SearchRequest)` → T stories (published, family) + `places(label,address)` + `story_people(person_id, people(name))` + `profiles!author_id(display_name)` + photos. Then a **pure client** `filterSearchRecords` does the filtering and ranking (`:123-178`).

### 1.13 `TimelineLive` (`timeline_live.dart:27-38`)
`watch({familyId,onChange})` listens to postgres changes on `stories, photos, comments, perspectives` filtered by `family_id`, then applies `timelineEventMatters` and a 200 ms debounce. `watchStory({storyId,onChange})` listens to `comments, perspectives, photos` by `story_id`. `dispose()`.

### 1.14 Non-gateway direct Supabase use
- `rpc_error.dart:4-19` parses the `PostgrestException.message` prefixes `NOT_FOUND:` / `FORBIDDEN:` / `VALIDATION:` / `INVITE_INVALID:`. Callers: `family_landing_page.dart:219,279`, `invite_modal.dart:221`, `add_person_modal.dart:128`, `person_profile_dialog.dart:230`.
- `add_perspective_page.dart:147-163` queries T `profiles.display_name` directly.
- `album_header.dart:1115` calls `auth.signOut()`.

---

## 2. Proposed Serverpod endpoints

### 2.0 Conventions
- Every endpoint below uses `@override bool get requireLogin => true;`, except `InviteEndpoint.preview`, which lives in `InvitePublicEndpoint` with `requireLogin => false`.
- The caller id is `session.authenticated!.authUserId` (`UuidValue`) [UNVERIFIED exact accessor name in 4.1.1; ServerpodResearch to confirm].
- Every mutating method calls `Authz.*` (RulesInventory owns the rules), runs inside `session.db.transaction`, and after commit posts `LiveEvent`s to `family:<familyId>` and, where relevant, `story:<storyId>`.
- DTO names end in `Dto` so they don't collide with the client domain classes. They are `.spy.yaml` classes without `table:` unless SchemaDesign says otherwise.
- Blob keys are produced by the server only. Keys per schema-design.md §4.2. They are stored in the `private` storage.
- `MediaEndpoint` authorizes a read by finding the row holding the key (`photos.originalKey`/`editedKey`, `families.coverKey`, `people.avatarKey`, `users.avatarKey`) and checking tree/family access. Nobody parses keys.
- Methods that replace or remove a blob never delete it inline: old keys go to `blob_deletions` in the same transaction.

### 2.1 Shared DTOs (protocol)
```yaml
# app_exception.spy.yaml
exception: AppException
fields: { code: AppErrorCode, message: String }
enum: AppErrorCode  # notFound, forbidden, validation, inviteInvalid, conflict, photoCap, storageFailed

class: MemberFamilyDto      # id, name, parentId?, branchYear?, createdAt, role: MembershipRole, coverKey?
class: StewardFamilyDto     # id, name, role, deletedAt?
class: TreeFamilyDto        # id, name, parentId?, branchYear?, effectiveOriginStoryId?
class: OriginDependentDto   # familyId, name
class: FamilyRosterDto      # id, name, role, memberCount: int, publishedCount: int, deletedAt?
class: FamilyDirectoryDto   # active: List<FamilyRosterDto>, recoverable: List<FamilyRosterDto>
class: FamilyMemberDto      # userId, role, displayName?, avatarKey?
class: PendingInviteDto     # id, email?, personId?, sentAt, expiresAt, createdAt
class: FamilyDetailDto      # id, name, myRole, members: List<FamilyMemberDto>, pendingInvites: List<PendingInviteDto>
enum:  MembershipRole       # owner, coOwner, member

class: StoryPersonDto       # personId, name, userId?
class: PhotoRefDto          # id, key (effective = edited ?? original), sortOrder
class: StoryDto             # id, familyId, authorId?, title?, body?, dateStart?, dateEnd?, datePrecision: DatePrecision?,
                            # createdAt, placeId?, placeLabel?, placeAddress?, status: StoryStatus, publishedAt?,
                            # people: List<StoryPersonDto>, photos: List<PhotoRefDto>,
                            # authorName?, authorAvatarKey?, commentCount: int, perspectiveCount: int
class: StoryWriteDto        # dateStart?, dateEnd?, datePrecision?, title?, body?, placeId?, clearPlace: bool,
                            # personIds: List<UuidValue>?   (null = leave story_people alone)
enum:  StoryStatus          # draft, published
enum:  DatePrecision        # year, month, day (byIndex, append-only)

class: PersonDto            # id, treeId, homeFamilyId, name, email?, about?, avatarKey?, userId?, passedAway,
                            # birthDate?, birthPrecision?, deathDate?, deathPrecision?
                            # (birth = linked AppUser, coarsened by visibility, when linked; else the person row)
class: PersonProfileDto     # id, homeFamilyId, name, isLinked, birthDate?, birthPrecision?, deathDate?, deathPrecision?,
                            # about?, avatarKey?, passedAway
class: PersonWriteDto       # name, about?, writeAbout, email?, writeEmail, passedAway?, writePassedAway, clearPicture,
                            # birthDate?, birthPrecision?, writeBirth, deathDate?, deathPrecision?, writeDeath
enum:  KinshipKind          # parentOf, partnerOf
class: KinshipDto           # id, kind: KinshipKind, fromPersonId, toPersonId
class: PhotoDto             # id, storyId, familyId (derived), uploaderId?, originalKey, editedKey?, editVersion, sortOrder
class: PhotoUploadTicketDto # photoId, key, uploadDescription: String
class: CoverUploadTicketDto # key, uploadDescription: String
enum:  NoteKind             # comment, perspective
class: NoteDto              # id, storyId, familyId, kind, authorId?, authorName?, body, createdAt
class: PlaceDto             # id, treeId, label, address, lat: double, lng: double, mapboxPlaceId?, isFavorite, lastUsedAt?
class: PlaceInputDto        # label, address, lat, lng, mapboxPlaceId?, isFavorite
class: OwnProfileDto        # authUserId, displayName?, email?, avatarKey?, birthDate?, birthPrecision?, birthVisibility, about?
enum:  BirthVisibility      # hidden, year, yearMonth, full
class: CreatedInviteDto     # inviteId, token, expiresAt, inviteUrl
class: InvitePreviewDto     # valid, familyId?, familyName?, inviterName?
class: LiveEventDto         # familyId, storyId?, kind: LiveKind (story|photo|note), storyStatus: StoryStatus?, deleted: bool

enum:  SearchSort           # relevant, chronological, recentlyAdded
class: StorySearchDto       # familyId, text: String (default ''), personIds: List<UuidValue>, placeId?,
                            # rangeStart?, rangeEnd?, decades: List<int>, sort: SearchSort
class: DecadeFacetDto       # decade: int, storyCount: int
class: PersonFacetDto       # personId, name, storyCount: int
class: PlaceFacetDto        # placeId, label, storyCount: int
class: StoryFacetsDto       # decades: List<DecadeFacetDto>, people: List<PersonFacetDto>, places: List<PlaceFacetDto>
```
`familyId` on `NoteDto`, `PhotoDto` and `LiveEventDto` is derived on the server from the story and is not stored.

### 2.2 Endpoint signatures (server, Dart)
```dart
// ── auth ────────────────────────────────────────────────────────────────
class EmailIdpEndpoint extends EmailOtpIdpBaseEndpoint {}   // startOtpLogin / verifyOtpLoginCode / finishOtpLogin / finishOtpRegistration
// plus whatever refresh/session endpoint the token manager needs (ServerpodResearch).

// ── families + management ───────────────────────────────────────────────
class FamilyEndpoint extends Endpoint {
  Future<List<MemberFamilyDto>> listMine(Session s);                                   // FamiliesGateway.listMine; InviteGateway.currentFamilyId uses it too
  Future<List<StewardFamilyDto>> listStewarded(Session s);                             // incl. soft-deleted inside 60 days (server filters)
  Future<List<TreeFamilyDto>> listTree(Session s, UuidValue familyId);                 // list_family_tree: one query on families.treeId
  Future<void> setOrigin(Session s, UuidValue familyId, UuidValue storyId);            // set_family_origin
  Future<List<OriginDependentDto>> listOriginDependents(Session s, UuidValue storyId);
  Future<CoverUploadTicketDto> startCoverUpload(Session s, UuidValue familyId, int byteLength);   // steward; maxFileSize 5 MiB, contentType image/jpeg, image/png or image/webp
  Future<String> finishCoverUpload(Session s, UuidValue familyId, String key);         // verifyUpload, set coverKey; old key goes to blob_deletions in the same transaction → returns key
  Future<void> clearCover(Session s, UuidValue familyId);                              // null coverKey; old key goes to blob_deletions in the same transaction
  Future<List<FamilyMemberDto>> listMembers(Session s, UuidValue familyId);
  Future<FamilyDirectoryDto> directory(Session s);                                     // ONE query with counts (was 4 round trips)
  Future<FamilyDetailDto?> detail(Session s, UuidValue familyId);                      // family + members + pending invites in one call
  Future<UuidValue> createRoot(Session s, String name);                                // replaces BOTH create_family RPC and create-root-family fn
  Future<UuidValue> createBranch(Session s, {required UuidValue parentFamilyId, required UuidValue originStoryId,
      required String name, required int branchYear, required UuidValue ownerUserId, List<UuidValue> personIds = const []});
  Future<void> rename(Session s, UuidValue familyId, String name);
  Future<void> addCoOwner(Session s, UuidValue familyId, UuidValue userId);
  Future<void> removeCoOwner(Session s, UuidValue familyId, UuidValue userId);
  Future<void> removeMember(Session s, UuidValue familyId, UuidValue userId);
  Future<void> transferOwnership(Session s, UuidValue familyId, UuidValue newOwnerUserId, MembershipRole formerOwnerBecomes);
  Future<void> softDelete(Session s, UuidValue familyId);                              // sets deleted_at; purge future call scheduled +60d
  Future<void> recover(Session s, UuidValue familyId);
}

// ── invites ─────────────────────────────────────────────────────────────
class InviteEndpoint extends Endpoint {
  Future<CreatedInviteDto> create(Session s, UuidValue familyId, {String? email, UuidValue? personId});
  Future<void> sendEmail(Session s, UuidValue inviteId);
  Future<UuidValue> accept(Session s, String token);       // returns familyId; single transaction (membership + person link)
  Future<DateTime> resend(Session s, UuidValue inviteId);  // new expires_at
  Future<void> revoke(Session s, UuidValue inviteId);
}
class InvitePublicEndpoint extends Endpoint {               // requireLogin => false
  Future<InvitePreviewDto> preview(Session s, String token);
}

// ── people ──────────────────────────────────────────────────────────────
class PeopleEndpoint extends Endpoint {
  Future<List<PersonDto>> listFamily(Session s, UuidValue familyId);
  Future<List<PersonDto>> listTree(Session s, UuidValue familyId);         // tree people + linked-user birth coarsened, ONE call (was 2 + N)
  Future<PersonDto> create(Session s, UuidValue familyId, PersonWriteDto input, ByteData? picture);   // picture ≤512px jpeg, inline
  Future<PersonDto?> forEdit(Session s, UuidValue personId);               // includes userId + email; steward/self only
  Future<PersonProfileDto> profile(Session s, UuidValue personId);         // throws AppException(notFound)
  Future<PersonDto> update(Session s, UuidValue personId, PersonWriteDto input, ByteData? picture);   // duplicate email → AppException(conflict, 'That email is already used')
  Future<List<PersonDto>> listUnlinked(Session s, UuidValue familyId);
  Future<bool> isHomeFamilySteward(Session s, UuidValue familyId);
  Future<void> markPassedAway(Session s, UuidValue personId, bool value);
  // Kinship (contract only; not implemented yet). No client UI yet; a UX spec must precede a gateway method.
  Future<List<KinshipDto>> listKinships(Session s, UuidValue familyId);    // whole tree; tree reader
  Future<KinshipDto> addKinship(Session s, UuidValue familyId, KinshipKind kind, UuidValue fromPersonId, UuidValue toPersonId);
  Future<void> removeKinship(Session s, UuidValue kinshipId);
}

// ── stories ─────────────────────────────────────────────────────────────
class StoryEndpoint extends Endpoint {
  Future<StoryDto> createDraft(Session s, UuidValue familyId, StoryWriteDto input, {UuidValue? id, bool allowUndated = false});
      // IDEMPOTENT on id: if a row with that id exists and the caller authored it, apply input as an update and return it.
  Future<StoryDto> updateDraft(Session s, UuidValue storyId, StoryWriteDto input);
  Future<bool> autosaveDraft(Session s, UuidValue storyId, StoryWriteDto input);     // false when no longer a draft
  Future<StoryDto> publish(Session s, UuidValue storyId);    // server checks readiness → AppException(validation)
  Future<StoryDto> get(Session s, UuidValue storyId);
  Future<StoryDto?> getPublished(Session s, UuidValue storyId);    // serves getPublished AND getPublishedOrigin (one DTO shape)
  Future<List<StoryDto>> listMyDrafts(Session s, UuidValue familyId);
  Future<List<StoryDto>> listPublished(Session s, UuidValue familyId);
  Future<List<StoryDto>> listLatestPublished(Session s, UuidValue familyId, {int withinDays = 7, int limit = 3});
  Future<List<StoryDto>> listForPerson(Session s, UuidValue personId);   // published, oldest first
  Future<void> discard(Session s, UuidValue storyId);       // deletes photo rows; their keys go to blob_deletions in the same transaction
  Future<void> linkPerson(Session s, UuidValue storyId, UuidValue personId);   // ON CONFLICT DO NOTHING
  // Search and facets (contract only; not implemented yet). Semantics below the code block.
  Future<List<StoryDto>> search(Session s, StorySearchDto q);
  Future<StoryFacetsDto> facets(Session s, UuidValue familyId);
}

// ── photos ──────────────────────────────────────────────────────────────
class PhotoEndpoint extends Endpoint {
  Future<List<PhotoDto>> list(Session s, UuidValue storyId);
  Future<PhotoUploadTicketDto> startUpload(Session s, UuidValue storyId, int byteLength);   // cap 20 → AppException(photoCap)
  Future<PhotoDto> finishUpload(Session s, UuidValue storyId, UuidValue photoId, int sortOrder); // verifyUpload, insert row; deletes blob on failure
  Future<void> delete(Session s, UuidValue photoId);         // row; original + edited keys go to blob_deletions in the same transaction
  Future<void> setHero(Session s, UuidValue storyId, UuidValue photoId);   // one transaction rewriting sort_order 0..n-1
}

// ── notes (comments + perspectives merged) ─────────────────────────────
class NoteEndpoint extends Endpoint {
  Future<List<NoteDto>> listForStory(Session s, UuidValue storyId, {NoteKind? kind});   // null = both, ordered created_at
  Future<NoteDto> create(Session s, UuidValue storyId, NoteKind kind, String body);
  Future<void> update(Session s, UuidValue noteId, String body);
  Future<void> delete(Session s, UuidValue noteId);
}

// ── places ──────────────────────────────────────────────────────────────
class PlaceEndpoint extends Endpoint {   // familyId params resolve the family's tree; results are tree-wide
  Future<List<PlaceDto>> list(Session s, UuidValue familyId);
  Future<List<PlaceDto>> favorites(Session s, UuidValue familyId);
  Future<List<PlaceDto>> recents(Session s, UuidValue familyId, {int limit = 10});
  Future<PlaceDto> create(Session s, UuidValue familyId, PlaceInputDto input);
  Future<PlaceDto> markUsed(Session s, UuidValue placeId);
  Future<PlaceDto> setFavorite(Session s, UuidValue placeId, bool isFavorite);
  Future<PlaceDto?> findByMapboxId(Session s, UuidValue familyId, String mapboxPlaceId);
  Future<PlaceDto?> get(Session s, UuidValue placeId);
}

// ── own profile ─────────────────────────────────────────────────────────
class ProfileEndpoint extends Endpoint {
  Future<OwnProfileDto> me(Session s);                       // AppUser created in onAfterAuthUserCreated; ensureAppUser fallback. Email from serverpod_auth_idp_email_account
  Future<void> saveName(Session s, String displayName);
  Future<void> saveAccount(Session s, {required String displayName, DateTime? birthDate, DatePrecision? birthPrecision,
      BirthVisibility? birthVisibility, String? about});
  Future<String> saveAvatar(Session s, ByteData jpeg);       // ≤512px, inline; returns key; old key goes to blob_deletions in the same transaction
  Future<void> clearAvatar(Session s);                       // old key goes to blob_deletions in the same transaction
  Future<UuidValue> startEmailChange(Session s, String newEmail);                   // see §2.4 caveat
  Future<void> finishEmailChange(Session s, UuidValue requestId, String code);
}

// ── media (authorized reads) ───────────────────────────────────────────
class MediaEndpoint extends Endpoint {
  Future<ByteData?> get(Session s, String key);                          // find the row holding the key, check tree/family access, retrieveFile from 'private'
  Future<Map<String, ByteData>> getMany(Session s, List<String> keys);   // collapses thumb/avatar N+1; caller-visible keys only
}

// ── realtime ────────────────────────────────────────────────────────────
class LiveEndpoint extends Endpoint {
  Stream<LiveEventDto> watchFamily(Session s, UuidValue familyId) async* {   // authz once, then
    yield* s.messages.createStream<LiveEventDto>('family:$familyId');
  }
  Stream<LiveEventDto> watchStory(Session s, UuidValue storyId) async* {
    yield* s.messages.createStream<LiveEventDto>('story:$storyId');
  }
}
```
**Search semantics** (`StoryEndpoint.search` / `facets`; contract only, not implemented yet):
- `StorySearchDto{familyId, text = '', personIds: List<UuidValue>, placeId?, rangeStart?, rangeEnd?, decades: List<int>, sort: SearchSort}`, with `SearchSort { relevant, chronological, recentlyAdded }`.
- Scope: published stories with `familyId` = the request's family.
- `personIds` use AND semantics. `placeId` matches exactly. When `decades` is non-empty, it filters on `floor(year(dateStart)/10)*10 ∈ decades`. Otherwise, if both range bounds are set, it filters on overlap (`dateStart <= rangeEnd AND rangeStart <= dateEnd`).
- Text: a case-insensitive substring match (`ILIKE` with `%`/`_`/`\` escaped) over title, body, place label, place address, tagged person names, the start year as text, and the decade label `'<decade>s'` for **any** decade (the 1900–2020 bound is dropped).
- Relevance tiers: 3 = title; 2 = a person name or place label/address; 1 = body, year or decade.
- Sorts (`timelineOrder` = dateStart, datePrecision, createdAt, id ascending; see schema-design.md §0.5):
  - `relevant`: tier desc, then reverse `timelineOrder`;
  - `chronological`: reverse `timelineOrder`;
  - `recentlyAdded`: `publishedAt` desc nulls last, then reverse `timelineOrder`.
- `facets(familyId)` covers the same story scope. Decades ascend; people are the people tagged on those stories (any home family), ordered by name; places are ordered by label. This replaces the second boot search and the family-only people chips.

### 2.3 Gateway method → endpoint map (1:1)
| Gateway method | Endpoint call | Collapsed |
|---|---|---|
| Families.listMine | `family.listMine` | the cover-column fallback is gone |
| Families.listStewarded | `family.listStewarded` | the 60-day filter moves to the server |
| Families.setFamilyOrigin / listOriginDependents | `family.setOrigin` / `family.listOriginDependents` | |
| Families.setCoverPhoto | compress → `family.startCoverUpload` → `FileUploader.upload` → `family.finishCoverUpload` | upload + update + old-object delete happen in one server step |
| Families.clearCoverPhoto | `family.clearCover` | list+remove+update in one call |
| Families.listMembers | `family.listMembers` + one `media.getMany(avatarKeys)` | N+1 → 2 |
| Families.listFamilyTree | `family.listTree` | |
| Directory.listDirectory | `family.directory` | 4 → 1 |
| Directory.loadDetail | `family.detail` + `media.getMany` | 3+N → 2 |
| FamilyCoverClient.download | `media.get(key)` | |
| Stories.createDraft | `story.createDraft` | 4 → 1; duplicate-id handling moves to the server |
| Stories.updateDraft / autosaveDraft | `story.updateDraft` / `story.autosaveDraft` | 3 → 1 |
| Stories.publish | `story.publish` | 4 → 1 |
| Stories.getStory / getPublished / getPublishedOrigin | `story.get` / `story.getPublished` (both) | |
| Stories.listMyDrafts / listPublished / listLatestPublished | same names | |
| Stories.discard (+ Photos.deleteAllForStory) | `story.discard` | 2 calls → 1 |
| Stories.linkPerson | `story.linkPerson` (idempotent) | |
| StoriesApi.storiesForPerson | `story.listForPerson` + `media.getMany(first photo keys)` | N+1 → 2 |
| downloadFirstThumbs | `media.getMany` | N → 1 |
| People.listPeople / listTreePeople | `people.listFamily` / `people.listTree` | 2+N → 1 |
| People.createPerson / updatePerson | `people.create` / `people.update` (picture inline) | 3 → 1 |
| People.personForEdit / personProfile / listUnlinkedPeople / isHomeFamilySteward / markPassedAway | same names | |
| *(none yet)* | `people.listKinships` / `addKinship` / `removeKinship` | contract only; a UX spec must precede a gateway method |
| People.signedPictureUrl | **becomes** `pictureBytes({personId, key}) → Uint8List?` via `media.get` | URL → bytes (see §3) |
| Photos.listPhotos | `photo.list` | |
| Photos.uploadPhoto | compress → `photo.startUpload` → upload → `photo.finishUpload` | |
| Photos.deletePhoto / setHeroPhoto | `photo.delete` / `photo.setHero` | hero: 1+N → 1 |
| Photos.deleteAllForStory | **removed** (folded into `story.discard`) | |
| Photos.downloadBytes | `media.get` | |
| Comments.* / Perspectives.* | `note.*` with `NoteKind.comment` / `NoteKind.perspective` | |
| Places.* | `place.*` | |
| Search.search | `story.search` | client filtering and ranking move to the server |
| search page boot | `story.facets` | replaces the second boot search and the family-only people chips |
| Invite.currentFamilyId | `family.listMine` + the existing client selection logic | 2 → 1 |
| Invite.createFamily | `family.createRoot` | merged with ManageFamilies.createRootFamily |
| Invite.createInvite / sendInviteEmail / acceptInvite | `invite.create` / `invite.sendEmail` / `invite.accept` | |
| InviteLink.validateInviteToken | `invitePublic.preview` | |
| ManageFamilies.* | `family.*` and `invite.resend` / `invite.revoke` | |
| Profile.loadOwn | `profile.me` | 2 → 1 |
| Profile.saveName / saveAccount / saveAvatar / clearAvatar | same names | avatar: 2 → 1 |
| Profile.downloadAvatar | `media.get` | signed URL + http → 1 |
| Profile.updateEmail | `profile.startEmailChange` + `finishEmailChange` (interface grows a code step) | |
| TimelineLive.watch / watchStory | `live.watchFamily` / `live.watchStory` | |

### 2.4 Open items with how to resolve them
- **Email change.** `EmailIdpBaseEndpoint` 4.1.1 has no change-email method. Its public methods are `startRegistration, verifyRegistrationCode, finishRegistration, login, hasAccount, startPasswordReset, verifyPasswordResetCode, finishPasswordReset` (grep of `email_idp_base_endpoint.dart`). `ProfileEndpoint.start/finishEmailChange` therefore has to be custom. It would send a code to the new address and then update the IDP's email-account row. [UNVERIFIED] that updating `serverpod_auth_idp` `EmailAccount` rows directly is supported; to check, read `serverpod_auth_idp_server-4.1.1/lib/src/providers/email/business/` for an admin/update API. The other option is for Main to drop email change from Settings (`settings_page.dart:359`).
- **The caller id accessor** and **refresh token endpoint** names are owned by ServerpodResearch.
- Whether `retrieveFile` on the S3 provider streams large responses efficiently is [UNVERIFIED]. Photos are capped at 1920 px JPEG q80, so they are typically well under 1 MB.

---

## 3. Client-side change list
LOC = lines changed (added + removed), estimated.

### New files
| File | Content | LOC |
|---|---|---|
| `lib/core/server/server_client.dart` (replaces `lib/core/supabase/`) | `late final Client serverClient` built with `Client(Env.serverUrl)..authSessionManager = FlutterAuthSessionManager()`, plus `initServer()` that awaits `client.auth.initialize()` [UNVERIFIED exact 4.1.1 wiring; ServerpodResearch] | 40 |
| `lib/core/server/app_session.dart` | `AppSession` gives one place to read `currentUserId` (`client.auth.authInfo?.authUserId.toString()`), `isSignedIn`, `signOut()` (`client.auth.signOutDevice()`), and a `ValueListenable` | 40 |
| `lib/data/dto_mapping.dart` | `Story.fromDto`, `Person.fromDto`, `Place.fromDto`, `Photo.fromDto`, `Comment/Perspective.fromNote`, `MemberFamily.fromDto`, …; `_ymd` / `_utcDate` helpers; and `AppException` → existing exception types (`InviteApiException`, `ManageFamiliesException`, `OriginRpcException`, `PersonProfileNotFound`, `StorageFailedException`, `StateError('PHOTO_CAP')`) | 250 |
| `packages/tell_me_a_story_client` (generated) | pubspec path dependency | 0 hand-written |

### Changed files in `lib/`
| File | Change | LOC |
|---|---|---|
| `pubspec.yaml` | remove `supabase_flutter`; add `tell_me_a_story_client` (path), `serverpod_flutter`, `serverpod_auth_idp_flutter`. `http` stays for Mapbox | 6 |
| `lib/main.dart` | `initServer()` replaces `initSupabase()`. `AuthRefresh(listenable: serverClient.auth.authInfoListenable)` replaces the `onAuthStateChange` / `currentSession` pair (`:21,28-29`) | 10 |
| `lib/core/supabase/supabase_init.dart`, `auth_callback.dart`, `browser_url_stub.dart`, `browser_url_web.dart` | **delete**. With no redirect login, nothing needs to strip `?code=` | −78 |
| `lib/core/config/env.dart` | `SUPABASE_URL`/`SUPABASE_ANON_KEY` → `SERVER_URL` (absolute http(s), keep `isAbsoluteHttpUrl`); update `validate()` messages | 25 |
| `lib/core/router/auth_refresh.dart` | constructor takes `ValueListenable<AuthSuccess?>` (or `Stream<bool>`) instead of `Stream<AuthState>`; same clear-on-signout behaviour | 15 |
| `lib/core/router/app_router.dart` | drop the supabase import; `_signedInUserId()` (`:471-477`) → `AppSession.currentUserId`. The redirect logic (`:248-302`) is unchanged because it already goes through `authRefresh` and `FamiliesGateway`. Optionally add an `onLogout` default | 8 |
| `lib/core/theme/album_header.dart` | `:1115` `Supabase…signOut()` → `AppSession.signOut()` | 3 |
| `lib/features/auth/magic_link_page.dart` (538 lines) | becomes an email-then-6-digit-code page. `MagicLinkSender` → `OtpSignIn{Future<UuidValue> start(email); Future<void> verify(requestId, code)}`. The verify step runs `verifyOtpLoginCode`, then `finishOtpLogin` or `finishOtpRegistration` depending on `accountExists`, then `client.auth.updateSignedInUser`. The "sent" panel turns into a code field with resend; `AuthException` → `EmailAccountRequestException` (reasons: invalid, expired, tooManyAttempts) | ~180 |
| `lib/features/auth/magic_link_redirect.dart` | **delete** (no redirect URL) | −15 |
| `lib/features/auth/invite_sign_in_page.dart` (481 lines) | uses the same `OtpSignIn` and an inline code step instead of `redirectTo: …/invite/token`. After `updateSignedInUser` the existing `_onAuth` → `_accept()` path runs unchanged (`:79-81`); `AuthException` handling (`:150`) → OTP exceptions | ~90 |
| `lib/features/drafts/drafts_page.dart` | `:166` currentUser → `AppSession`; `:254` drop `deleteAllForStory` (folded into `discard`) | 6 |
| `lib/features/family/manage_families_page.dart` | `:132` → `AppSession` | 4 |
| `lib/features/family/manage_family_page.dart` | `:170` → `AppSession` | 4 |
| `lib/features/family/start_timeline_host.dart` | `:16` → `AppSession` | 4 |
| `lib/features/people/person_profile_dialog.dart` | `:81` → `AppSession`; `signedPictureUrl` → `pictureBytes` and `Image.network` → `Image.memory` (`:145,558`); `PersonStoryCard.thumbUrl` → `thumbBytes` (`:480-493`) | 25 |
| `lib/features/people/edit_person_dialog.dart` | `:82,434` URL → bytes, `Image.memory` | 12 |
| `lib/features/perspectives/add_perspective_page.dart` | `:147-163` direct `profiles` query → `ProfileSession.instance.displayName` (already loaded) or `ProfileGateway.loadOwn()` | 12 |
| `lib/features/settings/settings_page.dart` | `:201` → `AppSession`; `:359` `updateEmail` gains a code-entry step, or the feature is removed (§2.4) | 10–60 |
| `lib/features/stories/new_story_page.dart` | drop the supabase import; `_linkIgnoringDuplicate` (`:468-480`) → plain `linkPerson` (idempotent on the server); `_writeDraft` catch (`:726-729`) removed, because `createDraft` is idempotent on id | 20 |
| `lib/features/stories/story_reader_page.dart` | `:202` → `AppSession`; `:231` `SupabaseTimelineLive()` → `ServerTimelineLive()` | 6 |
| `lib/features/timeline/timeline_page.dart` | `:226` → `AppSession`; `:85` → `ServerTimelineLive()` | 6 |
| `lib/data/families_api.dart` (712) | impl body → `serverClient.family.*`; delete `familiesCoverColumnMissing`, the `fromJson` factories, `_membershipRows`/`_rosters`/`_counts`/`_publishedCounts`; `originRpcException` reads `AppException` | −350 / +120 |
| `lib/data/family_covers.dart` (110) | keep compression and the 5 MB check; `save` = ticket+`FileUploader`+finish; `download` = `media.get`; `clear` = `family.clearCover`; delete the path regex (the server owns keys) | 60 |
| `lib/data/stories_api.dart` (866) | impl → `serverClient.story.*`; delete `_storySelect`/`_publishedSelect`, the embed parsers (`:129-275`), `isDuplicateStoryKey`, `_replacePeople`, `_date`/`_parseDate`; `storiesForPerson` → `listForPerson` + `media.getMany`; `downloadFirstThumbs` → `getMany`. `publishReadiness` stays client-side for UI gating | −330 / +140 |
| `lib/data/people_api.dart` (490) | impl → `people.*`; delete `fromJson`, `personProfileFromRpc`, `_treeFamilyIds`, `_uploadPersonPicture`; `signedPictureUrl` → `pictureBytes` on the interface. `Person.relationship` is removed (dead: written only as null at `:324`; `story_reader_page.dart:1363-1366` reads it); `Person` gains `deathDate`/`deathPrecision`, and `familyId` maps from `homeFamilyId` | −200 / +90 |
| `lib/data/photos_api.dart` (378) | keep `compressStoryPhoto`, `ensurePhotoCap`, `photosWithHeroFirst`, `comparePhotoOrder`. Delete `storyPhotoStoragePath` (moves to the server), `deleteAllForStory` and most test injectables (`uploadBinary`/`removeObjects`/`insertPhoto`/`deletePhotoRow`/`listStoryObjects`). Keep one `PhotoUploadBinary` seam for tests | −150 / +70 |
| `lib/data/comments_api.dart`, `perspectives_api.dart` | impl → `note.*` with a kind; delete `fromJson` | 40 each |
| `lib/data/places_api.dart` (221) | impl → `place.*`; `buildPlaceInsert` → `PlaceInputDto` builder; remove `Place.familyId` (read by no feature, `places_api.dart:7,18,30`) | −80 / +50 |
| `lib/data/invite_api.dart` (231) | `_invoke` / `FunctionException` → endpoint calls + `AppException` mapping; `createFamily` → `family.createRoot`; `currentFamilyId` uses `family.listMine` | −90 / +50 |
| `lib/data/manage_families_api.dart` (197) | each method is one endpoint call; `_invoke` → `AppException` → `ManageFamiliesException` | −80 / +45 |
| `lib/data/profile_api.dart` (249) | `loadOwn` → `profile.me`; `saveAvatar` inline `ByteData`; `downloadAvatar` → `media.get` (drops the `http` signed-URL fetch); `updateEmail` per §2.4 | −80 / +50 |
| `lib/data/search_api.dart` | `search` → `story.search(StorySearchDto)` + `Story.fromDto`; at cutover delete `filterSearchRecords`, `searchRecordFromRow` and the fixed 1900–2020 decade constants (`:37-38,123-185,197-207`) | −150 / +30 |
| `lib/features/search/search_page.dart` | person, place and decade chips read from `story.facets` instead of a second boot search and the family people list (`:113,136-145`); `timeframe_chips.dart:31-32` drops its fixed decades | 30 |
| `lib/data/timeline_live.dart` (146) | `SupabaseTimelineLive` → `ServerTimelineLive`, which subscribes to `live.watchFamily` / `live.watchStory` and keeps the 200 ms debounce. `timelineEventMatters` takes a `LiveEventDto` (or keeps its named params, mapped from the DTO) | −80 / +60 |
| `lib/data/rpc_error.dart` | `PostgrestException` prefix parsing → `if (error is AppException && error.code in {notFound, forbidden, validation, inviteInvalid, conflict}) return error.message` | 15 |
| `lib/data/profile_session.dart`, `family_selection.dart` | no change (comment-only "after Supabase starts" `:13`) | 1 |

### Phase 4 client items (F16, no schema change)
- Three different story sort orders: `stories_api.dart:852-876`, `all_stories_logic.dart:105-108`, `search_api.dart:153-185`. Align them to the named orders in schema-design.md §0.5 (`timelineOrder`, `allStoriesOrder`, `latestOrder`).
- `relatedMarks` puts null years first (`timeline_zoom.dart:169-187`); undated stories should sort last.
- Client `authorId`/`uploaderId` are non-null (`stories_api.dart:24,49,94`, `comments_api.dart:20,35`, `perspectives_api.dart:20,35`, `photos_api.dart:19,29,42`) while the server FKs are SetNull; make them nullable.
- `Place.familyId` is read by no feature (`places_api.dart:7,18,30`); removed (see table above).
- `co_owner` string literals at 14 code sites in 7 files; replace with `MembershipRole.coOwner`.

Total: about **−1 900 / +1 400** lines in `lib/`. The largest single items are the two auth pages (~270) and `stories_api.dart`.

---

## 4. Tests that import `supabase_flutter` or build `SupabaseClient`
Integration tests and other affected tests come last. Gateway fakes in widget tests implement the unchanged interfaces, so they don't change.

| File | Supabase use | Becomes |
|---|---|---|
| `test/add_person_modal_test.dart` | fakes throw `PostgrestException('VALIDATION: …')` (`:436,496,533,862,946`) | throw `AppException(code: AppErrorCode.validation, message: '…')`; `mapRpcError` returns the message |
| `test/comments_api_test.dart` | `Comment.fromJson` tests; `CommentsApi(client: SupabaseClient(…))` validation tests (`:115,125`) | `Comment.fromNote(NoteDto)` mapper tests; validation tests construct `CommentsApi(client: Client('http://localhost/'))` (validation throws before any network call) |
| `test/perspectives_api_test.dart` | same (`:118,128`) | same, with `NoteKind.perspective` |
| `test/family_landing_latest_test.dart` | `familiesCoverColumnMissing(PostgrestException…)` (`:57-79`) | delete those 3 cases (the function is gone); `latestShelf` tests stay |
| `test/family_selection_test.dart` | `StreamController<AuthState>` + `AuthState(signedOut)` (`:79-91`) | `ValueNotifier<AuthSuccess?>` set to null |
| `test/profile_session_test.dart` | same (`:37-49`) | same |
| `test/invite_chrome_test.dart` | `updateError = PostgrestException(23505 …)` (`:263,299,333`) | `AppException(conflict, 'That email is already used')`. The raw "duplicate key" message cases become a single conflict case, because the server always sends the catalog text |
| `test/m13_fit_finish_test.dart` | `_Sender implements MagicLinkSender`, `AuthException('Request failed', statusCode: '429')` (`:73,364`) | `_Otp implements OtpSignIn`; throw `EmailAccountRequestException(reason: tooManyAttempts)`; add code-entry steps |
| `test/m14_3_dob_passed_away_test.dart` | `markError = PostgrestException('FORBIDDEN: …')` (`:187`) | `AppException(forbidden, …)` |
| `test/new_story_capture_test.dart` | `PostgrestException` 23505 `story_people_pkey` (`:357`), 42501 RLS (`:1638`), 23505 `photos_pkey` (`:1843`) | duplicate-link tests: the fake `linkPerson` just succeeds, and the test asserts no error UI. RLS → `AppException(forbidden)`. `photos_pkey` → `AppException(conflict)` (still surfaces as an error) |
| `test/new_story_shell_test.dart` | `PostgrestException` `stories_pkey` on a retried create (`:944`) | fake `createDraft` returns the existing story on a repeated id; assert that autosave then updates |
| `test/people_api_test.dart` | `Person.fromJson`, `personProfileFromRpc`, and `listTreePeople` over a stubbed PostgREST `httpClient` (`:111-240+`) | delete the PostgREST stub group (the tree walk and linked-birth coarsening move to **server** integration tests); keep `ensureValidPersonCreate`; add `Person.fromDto` tests |
| `test/photos_api_test.dart` | `SupabaseClient('http://127.0.0.1','anon-key')` + injectables (`:66-436`) | keep compression/cap/hero-order tests; delete `removeObjects`/`listStoryObjects`/storage-path tests (they move to server tests: key generation, delete removes the edited blob too, cap) |
| `test/stories_api_test.dart` | `Story.fromJson`, `isDuplicateStoryKey(PostgrestException)` (`:153`) | `Story.fromDto` tests (date-only round trip, effective photo key, counts); delete the duplicate-key tests |

Also affected, though they don't import Supabase:
- `test/auth_callback_test.dart` and `test/magic_link_redirect_test.dart`: **delete**, along with their source files.
- `test/env_test.dart`: rewrite for `SERVER_URL`.
- `test/timeline_page_test.dart:2218-2245` (`timelineEventMatters`): keep; adapt the argument source if the signature changes.
- `integration_test/e2e_test.dart:429-449` and `integration_test/support/preconditions.dart:1-13`: use `serverClient.auth` for initialize, sign-out and `isAuthenticated`.
- `integration_test/support/relay_client.dart`: [INFERENCE from the name; not opened] it fetches magic links from the local mail relay. Replace it with a fetch of the dev OTP code. The decided design prints the code to the server log; e2e needs a machine-readable source, either a dev-only endpoint enabled in `development` run mode or a log file tail.

---

## 5. Cutover order (every step leaves the app runnable)

**Why there is no gateway-by-gateway backend mix.** Supabase RLS needs a GoTrue JWT, while Serverpod has its own users and UUIDs. A Serverpod-created family id means nothing to PostgREST, and the reverse is also true. A build where half the gateways talk to each backend cannot work end to end. So the seams are cut while the app still runs on Supabase, the server is built and tested on its own, and the data switch happens in one composition-root commit.

**Phase A: seams on Supabase.** The app stays fully functional after each step, and `flutter test` stays green.
1. Add `AppSession` (Supabase-backed for now) and route the 12 feature files, `app_router.dart:471` and `album_header.dart:1115` through it. The only remaining `Supabase.instance` uses are in `lib/data/*`, `main.dart` and the auth pages.
2. Add an `AppException` type in `lib/data` and translate inside each `*Api`: Postgrest/Function errors → `AppException` or the existing typed exceptions. Point `mapRpcError` at `AppException`, and switch test fakes from `PostgrestException` to `AppException`. After this step, tests no longer import `supabase_flutter` except the auth ones.
3. Make duplicates idempotent inside the gateways: `StoriesApi.createDraft` handles 23505 itself and `linkPerson` swallows the pkey duplicate. Remove the handling in `new_story_page.dart:468-480,726-729`. Fold `deleteAllForStory` into `StoriesApi.discard` and drop the call from `drafts_page.dart:254`.
4. Switch URLs to bytes: `PeopleGateway.signedPictureUrl` → `pictureBytes`, `PersonStoryCard.thumbUrl` → `thumbBytes`, and `Image.network` → `Image.memory` (3 sites). Replace `add_perspective_page.dart:147-163` with `ProfileSession`.
5. Change the login UI to a typed 6-digit code. Supabase GoTrue supports this via `signInWithOtp` + `verifyOTP(type: OtpType.email)` [UNVERIFIED that local GoTrue templates send `{{ .Token }}`; check `supabase/config.toml` email template]. After this step the `OtpSignIn` seam and the code-entry UI exist and are tested, so the Serverpod swap only changes the seam's implementation. If the Supabase template can't be changed cheaply, skip this step and do the UI in C2.

**Phase B: the server, built alongside.** The app is unchanged and still on Supabase.
1. Scaffold `tell_me_a_story_server` / `_client` (Serverpod 4.1.1), schema models and migrations (SchemaDesign), `Authz` (RulesInventory), `EmailIdpEndpoint` with dev log delivery, and storage (`private` → local disk in dev, S3 in prod).
2. Add endpoints in dependency order, each with Serverpod integration tests against local Postgres: `ProfileEndpoint` → `FamilyEndpoint` (+ purge future call) → `InviteEndpoint`/`InvitePublicEndpoint` → `PeopleEndpoint` → `PlaceEndpoint` → `StoryEndpoint` → `PhotoEndpoint` → `NoteEndpoint` → `MediaEndpoint` → `LiveEndpoint` (event posts are added to the mutating methods of the earlier endpoints).
3. Add client mapping code (`dto_mapping.dart`) with unit tests against the generated DTOs. Not wired yet.

**Phase C: the switch.** One commit, or one short-lived branch. Afterwards the app is runnable on Serverpod only.
1. Rewrite the `*Api` bodies (§3 table) to call `serverClient`. The interfaces and feature code are untouched apart from Phase A.
2. `main.dart` → `initServer()`; `AppSession` and `AuthRefresh` → `client.auth`; `OtpSignIn` → `EmailIdpEndpoint`; `env.dart` → `SERVER_URL`; `ServerTimelineLive` replaces `SupabaseTimelineLive`.
3. Delete `lib/core/supabase/`, `magic_link_redirect.dart`, the auth callback/redirect tests and the `supabase_flutter` dependency. Rewrite the e2e preconditions and the relay (OTP code fetch).
4. Verify: `flutter analyze`, `flutter test`, server `dart test`, e2e against local Postgres. Then, outside this contract's scope, delete `supabase/`, the Deno functions and Python.
