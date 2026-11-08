import 'dart:typed_data';

import 'package:serverpod/serverpod.dart';
import 'package:tell_me_a_story_server/src/generated/protocol.dart';

import 'fixtures.dart';

/// The smallest bytes that sniff as JPEG.
ByteData jpegBytes() =>
    ByteData.sublistView(Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE0, 0, 1]));

/// A PNG signature, refused for person pictures (JPEG only).
ByteData pngBytes() => ByteData.sublistView(
  Uint8List.fromList([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]),
);

/// A [PersonWriteDto]; every field group is off unless its flag is set.
PersonWriteDto personWrite({
  String name = 'Ada',
  String? about,
  bool writeAbout = false,
  String? email,
  bool writeEmail = false,
  bool? passedAway,
  bool writePassedAway = false,
  bool clearPicture = false,
  DateTime? birthDate,
  DatePrecision? birthPrecision,
  bool writeBirth = false,
  DateTime? deathDate,
  DatePrecision? deathPrecision,
  bool writeDeath = false,
}) => PersonWriteDto(
  name: name,
  about: about,
  writeAbout: writeAbout,
  email: email,
  writeEmail: writeEmail,
  passedAway: passedAway,
  writePassedAway: writePassedAway,
  clearPicture: clearPicture,
  birthDate: birthDate,
  birthPrecision: birthPrecision,
  writeBirth: writeBirth,
  deathDate: deathDate,
  deathPrecision: deathPrecision,
  writeDeath: writeDeath,
);

/// People-slice builders.
extension PeopleFx on Fx {
  /// Sets [user]'s account profile fields on the app `users` row.
  Future<AppUser> account(
    UuidValue user, {
    String? displayName,
    String? about,
    String? avatarKey,
    DateTime? birthDate,
    DatePrecision? birthPrecision,
    BirthVisibility birthVisibility = BirthVisibility.hidden,
  }) async {
    final row = await AppUser.db.findFirstRow(
      s,
      where: (t) => t.authUserId.equals(user),
    );
    return AppUser.db.updateRow(
      s,
      row!.copyWith(
        displayName: displayName,
        about: about,
        avatarKey: avatarKey,
        birthDate: birthDate,
        birthPrecision: birthPrecision,
        birthVisibility: birthVisibility,
      ),
    );
  }

  Future<Person> reload(Person person) async =>
      (await Person.db.findById(s, person.id!))!;

  Future<bool> queued(String key) async =>
      await BlobDeletion.db.count(s, where: (t) => t.key.equals(key)) > 0;
}
