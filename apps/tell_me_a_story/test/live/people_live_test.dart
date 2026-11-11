@Tags(['live'])
library;

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:tell_me_a_story/core/data/server_people_repository.dart';
import 'package:tell_me_a_story_client/tell_me_a_story_client.dart' as server;

import 'support/live_server.dart';

Uint8List _jpeg(int width, int height) =>
    img.encodeJpg(img.Image(width: width, height: height));

void main() {
  setUpAll(waitForLiveServer);

  test('person create/update with a picture, and the read paths', () async {
    final owner = await signInLive(freshEmail('people-owner'));
    final familyId = (await owner.family.createRoot('People')).toString();
    final api = ServerPeopleRepository(client: owner);

    expect(await api.isHomeFamilySteward(familyId), isTrue);

    final ada = await api.createPerson(
      familyId: familyId,
      name: '  Ada  ',
      about: 'Gardens',
      email: ' ada@example.com ',
      pictureBytes: _jpeg(1200, 900),
    );
    expect(ada.name, 'Ada');
    expect(ada.familyId, familyId);
    expect(ada.about, 'Gardens');
    expect(ada.email, 'ada@example.com');
    expect(ada.userId, isNull);
    expect(ada.avatarPath, isNotNull);

    final bytes = await api.pictureBytes(
      personId: ada.id,
      path: ada.avatarPath,
    );
    final picture = img.decodeJpg(bytes!)!;
    expect(picture.width, 512);
    expect(await api.pictureBytes(personId: ada.id, path: null), isNull);

    final updated = await api.updatePerson(
      personId: ada.id,
      name: 'Ada L',
      about: 'Roses',
      writeAbout: true,
      email: '',
      writeEmail: true,
      clearPicture: true,
    );
    expect(updated.name, 'Ada L');
    expect(updated.about, 'Roses');
    expect(updated.email, isNull);
    expect(updated.avatarPath, isNull);

    expect((await api.personForEdit(ada.id))!.name, 'Ada L');
    final profile = (await api.personProfile(ada.id))!;
    expect(profile.isLinked, isFalse);
    expect(profile.about, 'Roses');

    final family = await api.listPeople(familyId);
    expect(family.map((p) => p.id), contains(ada.id));
    expect(family.where((p) => p.userId != null), hasLength(1));
    expect((await api.listUnlinkedPeople(familyId)).map((p) => p.id), [ada.id]);
  });

  test(
    'tree list coarsens a linked birth; stewards mark passed away',
    () async {
      final owner = await signInLive(freshEmail('tree-owner'));
      final familyUuid = await owner.family.createRoot('Tree');
      final familyId = familyUuid.toString();
      final invite = await owner.invite.create(familyUuid);

      final member = await signInLive(freshEmail('tree-member'));
      await member.profile.saveAccount(
        displayName: 'Bea',
        birthDate: DateTime.utc(1990, 5, 17),
        birthPrecision: server.DatePrecision.day,
        birthVisibility: server.BirthVisibility.year,
      );
      await member.invite.accept(invite.token);

      final ownerView = await ServerPeopleRepository(client: owner)
          .listTreePeople(familyId);
      final bea = ownerView.singleWhere((p) => p.name == 'Bea');
      expect(bea.userId, isNotNull);
      expect(bea.birthDate, DateTime(1990));
      expect(bea.birthPrecision, 'year');

      final selfView = await ServerPeopleRepository(client: member)
          .listTreePeople(familyId);
      final self = selfView.singleWhere((p) => p.id == bea.id);
      expect(self.birthDate, DateTime(1990, 5, 17));
      expect(self.birthPrecision, 'day');

      final api = ServerPeopleRepository(client: owner);
      await api.markPassedAway(personId: bea.id, value: true);
      expect((await api.personForEdit(bea.id))!.passedAway, isTrue);
      await api.markPassedAway(personId: bea.id, value: false);
      expect((await api.personForEdit(bea.id))!.passedAway, isFalse);
      expect(
        await ServerPeopleRepository(client: member)
            .isHomeFamilySteward(familyId),
        isFalse,
      );
    },
  );
}
