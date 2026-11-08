import 'dart:typed_data';

import 'package:serverpod/serverpod.dart';

import '../accounts/accounts.dart';
import '../authz/authz.dart';
import '../errors.dart';
import '../generated/protocol.dart';
import '../media/blob_keys.dart';
import '../media/blob_outbox.dart';

/// The caller's own account (business-rules.md §2.10). Email is the login
/// identity and read-only (D1); account deletion is not offered (D7).
class ProfileEndpoint extends Endpoint {
  @override
  bool get requireLogin => true;

  Future<OwnProfileDto> me(Session session) async {
    final uid = Authz(session).requireUser();
    final user = await _ensureAppUser(session, uid);
    return OwnProfileDto(
      authUserId: uid,
      displayName: user.displayName,
      email: await accountEmail(session, uid),
      avatarKey: user.avatarKey,
      birthDate: user.birthDate,
      birthPrecision: user.birthPrecision,
      birthVisibility: user.birthVisibility,
      about: user.about,
    );
  }

  /// Sets the display name (blank clears it) and renames every person linked
  /// to the caller, in every tree. A blank name leaves linked names alone.
  Future<void> saveName(Session session, String displayName) async {
    final uid = Authz(session).requireUser();
    final name = _trimmedOrNull(displayName);
    await _ensureAppUser(session, uid);
    await session.db.transaction((t) async {
      final user = await _lockAppUser(session, uid, t);
      await AppUser.db.updateRow(
        session,
        user.copyWith(displayName: name, updatedAt: _now()),
        transaction: t,
      );
      await _syncLinkedNames(session, uid, name, t);
    });
  }

  /// One Save of the account form: display name, birth and about are written
  /// as given (null clears); a null [birthVisibility] keeps the current one.
  Future<void> saveAccount(
    Session session, {
    required String displayName,
    DateTime? birthDate,
    DatePrecision? birthPrecision,
    BirthVisibility? birthVisibility,
    String? about,
  }) async {
    final uid = Authz(session).requireUser();
    final name = _trimmedOrNull(displayName);
    final birth = _normalizedBirth(birthDate, birthPrecision);
    final aboutText = _trimmedOrNull(about ?? '');
    if (aboutText != null && aboutText.length > 500) {
      throw validation('about must be at most 500 characters');
    }
    await _ensureAppUser(session, uid);
    await session.db.transaction((t) async {
      final user = await _lockAppUser(session, uid, t);
      await AppUser.db.updateRow(
        session,
        user.copyWith(
          displayName: name,
          birthDate: birth?.$1,
          birthPrecision: birth?.$2,
          birthVisibility: birthVisibility ?? user.birthVisibility,
          about: aboutText,
          updatedAt: _now(),
        ),
        transaction: t,
      );
      await _syncLinkedNames(session, uid, name, t);
    });
  }

  /// Stores a JPEG (≤ 2 MiB) under a fresh key and points the account at it;
  /// the previous key is queued for deletion in the same transaction.
  Future<String> saveAvatar(Session session, ByteData jpeg) async {
    final uid = Authz(session).requireUser();
    if (jpeg.lengthInBytes > avatarMaxBytes) {
      throw validation('file is too large');
    }
    if (sniffImageMime(jpeg) != 'image/jpeg') {
      throw validation('unsupported image type');
    }
    await _ensureAppUser(session, uid);
    final key = userAvatarKey(authUserId: uid);
    await session.storage.storeFile(
      storageId: blobStorageId,
      path: key,
      byteData: jpeg,
      options: const StoreFileOptions(
        preventOverwrite: true,
        metadata: FileMetadata(contentType: 'image/jpeg'),
      ),
    );
    try {
      await session.db.transaction((t) async {
        final user = await _lockAppUser(session, uid, t);
        await queueBlobDeletions(session, [user.avatarKey], transaction: t);
        await AppUser.db.updateRow(
          session,
          user.copyWith(avatarKey: key, updatedAt: _now()),
          transaction: t,
        );
      });
    } catch (_) {
      await queueBlobDeletions(session, [key]);
      rethrow;
    }
    return key;
  }

  Future<void> clearAvatar(Session session) async {
    final uid = Authz(session).requireUser();
    await _ensureAppUser(session, uid);
    await session.db.transaction((t) async {
      final user = await _lockAppUser(session, uid, t);
      if (user.avatarKey == null) return;
      await queueBlobDeletions(session, [user.avatarKey], transaction: t);
      await AppUser.db.updateRow(
        session,
        user.copyWith(avatarKey: null, updatedAt: _now()),
        transaction: t,
      );
    });
  }
}

DateTime _now() => DateTime.now().toUtc();

String? _trimmedOrNull(String value) {
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}

/// The `users` row is created by the auth hook; this is the fallback for an
/// account that predates it.
Future<AppUser> _ensureAppUser(Session session, UuidValue uid) async {
  final existing = await AppUser.db.findFirstRow(
    session,
    where: (t) => t.authUserId.equals(uid),
  );
  if (existing != null) return existing;
  try {
    return await AppUser.db.insertRow(session, AppUser(authUserId: uid));
  } on DatabaseQueryException catch (e) {
    if (e.code != '23505') rethrow;
    final raced = await AppUser.db.findFirstRow(
      session,
      where: (t) => t.authUserId.equals(uid),
    );
    return raced!;
  }
}

Future<AppUser> _lockAppUser(
  Session session,
  UuidValue uid,
  Transaction t,
) async {
  final user = await AppUser.db.findFirstRow(
    session,
    where: (u) => u.authUserId.equals(uid),
    transaction: t,
    lockMode: LockMode.forUpdate,
  );
  return user!;
}

/// Linked person name = display name (schema-design.md §3.2); a blank name
/// keeps the existing person names.
Future<void> _syncLinkedNames(
  Session session,
  UuidValue uid,
  String? name,
  Transaction t,
) async {
  if (name == null) return;
  await Person.db.updateWhere(
    session,
    columnValues: (p) => [p.name(name), p.updatedAt(_now())],
    where: (p) => p.userId.equals(uid),
    transaction: t,
  );
}

/// Birth date aligned to [precision] at UTC midnight, or null when no date.
(DateTime, DatePrecision)? _normalizedBirth(
  DateTime? date,
  DatePrecision? precision,
) {
  if (date == null) return null;
  if (precision == null) throw validation('birth precision is required');
  if (date.year < 1000 || date.year > 9999) {
    throw validation('birth year must be four digits');
  }
  final aligned = switch (precision) {
    DatePrecision.year => DateTime.utc(date.year),
    DatePrecision.month => DateTime.utc(date.year, date.month),
    DatePrecision.day => DateTime.utc(date.year, date.month, date.day),
  };
  return (aligned, precision);
}
