@Tags(['live'])
library;

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:serverpod_auth_core_flutter/serverpod_auth_core_flutter.dart';
import 'package:tell_me_a_story/data/app_exception.dart';
import 'package:tell_me_a_story/data/families_api.dart';
import 'package:tell_me_a_story/data/family_covers.dart';
import 'package:tell_me_a_story/data/invite_api.dart';
import 'package:tell_me_a_story/data/manage_families_api.dart';
import 'package:tell_me_a_story_client/tell_me_a_story_client.dart' as server;

import 'support/live_server.dart';

/// A published, dated story in [familyId], made with the raw client.
Future<String> _publishedStory(server.Client client, String familyId) async {
  final person = await client.people.create(
    server.UuidValue.fromString(familyId),
    server.PersonWriteDto(
      name: 'Grandma',
      writeAbout: false,
      writeEmail: false,
      writePassedAway: false,
      clearPicture: false,
      writeBirth: false,
      writeDeath: false,
    ),
    null,
  );
  final place = await client.place.create(
    server.UuidValue.fromString(familyId),
    server.PlaceInputDto(
      label: 'Home',
      address: '1 Main St',
      lat: 40,
      lng: -74,
      isFavorite: false,
    ),
  );
  final draft = await client.story.createDraft(
    server.UuidValue.fromString(familyId),
    server.StoryWriteDto(
      title: 'Origin',
      body: 'Where it began.',
      dateStart: DateTime.utc(1990),
      datePrecision: server.DatePrecision.year,
      clearPlace: false,
      personIds: [person.id],
      placeId: place.id,
    ),
    allowUndated: false,
  );
  final published = await client.story.publish(draft.id);
  return published.id.toString();
}

/// Signs [owner] in, creates a root family, and has [joiner] accept an
/// invite to it. Returns the family id and both clients and user ids.
Future<
  ({
    String familyId,
    server.Client ownerClient,
    server.Client joinerClient,
    String joinerId,
  })
>
_familyWithJoiner(String owner, String joiner) async {
  final ownerClient = await signInLive(freshEmail(owner));
  final familyId = await ManageFamiliesApi(client: ownerClient)
      .createRootFamily('$owner family');
  final invite = await InviteApi(client: ownerClient)
      .createInvite(familyId: familyId);
  final joinerClient = await signInLive(freshEmail(joiner));
  await InviteApi(client: joinerClient).acceptInvite(token: invite.token);
  final joinerId = joinerClient.auth.authInfo!.authUserId.toString();
  return (
    familyId: familyId,
    ownerClient: ownerClient,
    joinerClient: joinerClient,
    joinerId: joinerId,
  );
}

Matcher _code(AppErrorCode code) =>
    throwsA(isA<AppException>().having((e) => e.code, 'code', code));

void main() {
  setUpAll(waitForLiveServer);

  test('createRoot, listMine, rename, listStewarded and the tree', () async {
    final client = await signInLive(freshEmail('root'));
    final manage = ManageFamiliesApi(client: client);
    final families = FamiliesApi(client: client);

    final id = await manage.createRootFamily('  Morgans ');
    var mine = await families.listMine();
    expect(mine.map((f) => f.id), [id]);
    expect(mine.single.name, 'Morgans');
    expect(mine.single.role, 'owner');
    expect(mine.single.coverPhotoPath, isNull);

    await manage.renameFamily(familyId: id, name: 'Carters');
    mine = await families.listMine();
    expect(mine.single.name, 'Carters');

    final stewarded = await families.listStewarded();
    expect(stewarded.single.id, id);
    expect(stewarded.single.role, 'owner');
    expect(stewarded.single.deletedAt, isNull);

    final tree = await families.listFamilyTree(id);
    expect(tree.single.id, id);
    expect(tree.single.parentFamilyId, isNull);
  });

  test(
    'directory, detail and members show counts, roles and invites',
    () async {
      final setup = await _familyWithJoiner('dir-owner', 'dir-member');
      final families = FamiliesApi(client: setup.ownerClient);
      await _publishedStory(setup.ownerClient, setup.familyId);
      await InviteApi(
        client: setup.ownerClient,
      ).createInvite(familyId: setup.familyId, email: 'Pending@Example.test ');

      final directory = await families.listDirectory();
      final roster = directory.active.singleWhere(
        (r) => r.id == setup.familyId,
      );
      expect(roster.role, 'owner');
      expect(roster.memberCount, 2);
      expect(roster.publishedCount, 1);
      expect(directory.recoverable, isEmpty);

      final detail = await families.loadDetail(setup.familyId);
      expect(detail, isNotNull);
      expect(detail!.myRole, 'owner');
      expect(detail.people.map((p) => p.role).toSet(), {'owner', 'member'});
      final invite = detail.pendingInvites.single;
      expect(invite.email, 'pending@example.test');
      expect(invite.sentAt, isNotNull);
      expect(invite.isExpired, isFalse);

      final members = await families.listMembers(setup.familyId);
      expect(members.map((m) => m.userId), contains(setup.joinerId));

      final stranger = await signInLive(freshEmail('dir-stranger'));
      expect(
        await FamiliesApi(client: stranger).loadDetail(setup.familyId),
        isNull,
      );
    },
  );

  test('cover round trip: save, download, clear', () async {
    final client = await signInLive(freshEmail('cover'));
    final id = await ManageFamiliesApi(client: client)
        .createRootFamily('Covers');
    final families = FamiliesApi(client: client);
    final png = Uint8List.fromList(
      img.encodePng(img.Image(width: 8, height: 6)),
    );

    final key = await families.setCoverPhoto(familyId: id, bytes: png);
    final mine = (await families.listMine()).single;
    expect(mine.coverPhotoPath, key);
    final bytes = await families.download(key);
    expect(img.decodeJpg(bytes!)!.width, 8);

    await families.clearCoverPhoto(familyId: id, path: key);
    expect((await families.listMine()).single.coverPhotoPath, isNull);
    await expectLater(
      FamilyCoversApi(client: client).save(familyId: id, bytes: Uint8List(0)),
      throwsA(isA<CoverPhotoException>()),
    );
  });

  test('co-owner add/remove, transfer, remove member', () async {
    final setup = await _familyWithJoiner('mg-owner', 'mg-member');
    final manage = ManageFamiliesApi(client: setup.ownerClient);
    final families = FamiliesApi(client: setup.ownerClient);
    Future<String> roleOf(String userId) async =>
        (await families.listMembers(setup.familyId))
            .singleWhere((m) => m.userId == userId)
            .role;

    await manage.addCoOwner(familyId: setup.familyId, userId: setup.joinerId);
    expect(await roleOf(setup.joinerId), 'co_owner');
    await manage.removeCoOwner(
      familyId: setup.familyId,
      userId: setup.joinerId,
    );
    expect(await roleOf(setup.joinerId), 'member');

    await manage.addCoOwner(familyId: setup.familyId, userId: setup.joinerId);
    await manage.transferOwnership(
      familyId: setup.familyId,
      newOwnerUserId: setup.joinerId,
      formerOwnerBecomes: 'co_owner',
    );
    expect(await roleOf(setup.joinerId), 'owner');
    final ownerId = setup.ownerClient.auth.authInfo!.authUserId.toString();
    expect(await roleOf(ownerId), 'co_owner');

    await ManageFamiliesApi(client: setup.joinerClient)
        .removeMember(familyId: setup.familyId, userId: ownerId);
    expect(await FamiliesApi(client: setup.ownerClient).listMine(), isEmpty);
  });

  test('soft delete then recover', () async {
    final client = await signInLive(freshEmail('del'));
    final manage = ManageFamiliesApi(client: client);
    final families = FamiliesApi(client: client);
    final id = await manage.createRootFamily('Deleted');

    await manage.softDeleteFamily(id);
    expect(await families.listMine(), isEmpty);
    final directory = await families.listDirectory();
    expect(directory.active, isEmpty);
    expect(directory.recoverable.single.id, id);
    expect((await families.listStewarded()).single.deletedAt, isNotNull);

    await manage.recoverFamily(id);
    expect((await families.listMine()).single.id, id);
  });

  test('origin, branch and origin dependents', () async {
    final setup = await _familyWithJoiner('br-owner', 'br-member');
    final families = FamiliesApi(client: setup.ownerClient);
    final storyId = await _publishedStory(setup.ownerClient, setup.familyId);

    await families.setFamilyOrigin(familyId: setup.familyId, storyId: storyId);
    final branchId = await ManageFamiliesApi(client: setup.ownerClient)
        .createBranchFamily(
          parentFamilyId: setup.familyId,
          originStoryId: storyId,
          name: 'Branch',
          branchYear: 1995,
          ownerUserId: setup.joinerId,
        );

    final tree = await families.listFamilyTree(setup.familyId);
    final branch = tree.singleWhere((f) => f.id == branchId);
    expect(branch.parentFamilyId, setup.familyId);
    expect(branch.branchYear, 1995);
    expect(
      tree.singleWhere((f) => f.id == setup.familyId).originStoryId,
      storyId,
    );

    final dependents = await families.listOriginDependents(storyId);
    expect(dependents.map((d) => d.familyId), contains(setup.familyId));

    await expectLater(
      FamiliesApi(client: setup.joinerClient)
          .setFamilyOrigin(familyId: setup.familyId, storyId: storyId),
      _code(AppErrorCode.forbidden),
    );
  });
}
