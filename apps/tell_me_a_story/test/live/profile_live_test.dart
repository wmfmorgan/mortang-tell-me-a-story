@Tags(['live'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:tell_me_a_story/core/data/profile_repository.dart';

import 'support/live_server.dart';

void main() {
  setUpAll(waitForLiveServer);

  test('profile: load, saveName, saveAccount, avatar round trip', () async {
    final email = freshEmail('profile');
    await signInLive(email);
    final api = ServerProfileRepository();

    final fresh = (await api.loadOwn())!;
    expect(fresh.email, email);
    expect(fresh.avatarPath, isNull);

    await api.saveName('  Ada  ');
    expect((await api.loadOwn())!.displayName, 'Ada');

    await api.saveAccount(
      displayName: 'Ada Lovelace',
      birthDate: DateTime(1990, 5, 17),
      birthPrecision: 'month',
      birthVisibility: BirthVisibility.yearMonth,
      about: 'Counts things',
    );
    final saved = (await api.loadOwn())!;
    expect(saved.displayName, 'Ada Lovelace');
    expect(saved.birthDate, DateTime(1990, 5));
    expect(saved.birthPrecision, 'month');
    expect(saved.birthVisibility, BirthVisibility.yearMonth);
    expect(saved.about, 'Counts things');

    final key = await api.saveAvatar(
      img.encodeJpg(img.Image(width: 1200, height: 800)),
    );
    expect((await api.loadOwn())!.avatarPath, key);
    final avatar = img.decodeJpg((await api.downloadAvatar(key))!)!;
    expect(avatar.width, 512);

    await api.clearAvatar();
    expect((await api.loadOwn())!.avatarPath, isNull);
    expect(await api.downloadAvatar(key), isNull);
  });
}
