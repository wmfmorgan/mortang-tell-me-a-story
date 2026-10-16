import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'families_api.dart';
import 'photos_api.dart';

/// Family-scoped person row. Relationship is optional; new people send null.
class Person {
  const Person({
    required this.id,
    required this.familyId,
    required this.name,
    this.relationship,
    this.email,
    this.birthDate,
    this.birthPrecision,
    this.passingDate,
    this.passingPrecision,
    this.about,
    this.avatarPath,
    this.userId,
    this.passedAway = false,
    this.createdBy = '',
  });

  final String id;
  final String familyId;
  final String name;
  final String? relationship;
  final String? email;
  final DateTime? birthDate;
  final String? birthPrecision;
  final DateTime? passingDate;
  final String? passingPrecision;
  final String? about;
  final String? avatarPath;
  final String? userId;
  final bool passedAway;
  final String createdBy;

  factory Person.fromJson(Map<String, dynamic> json) {
    return Person(
      id: json['id'] as String,
      familyId: json['family_id'] as String,
      name: json['name'] as String,
      relationship: json['relationship'] as String?,
      email: json['email'] as String?,
      birthDate: personDateFromJson(json['birth_date']),
      birthPrecision: json['birth_precision'] as String?,
      passingDate: personDateFromJson(json['passing_date']),
      passingPrecision: json['passing_precision'] as String?,
      about: json['about'] as String?,
      avatarPath: json['avatar_path'] as String?,
      userId: json['user_id'] as String?,
      passedAway: json['passed_away'] == true,
      createdBy: json['created_by'] as String? ?? '',
    );
  }
}

/// Fields `person_profile` returns. Never includes user_id or email.
class PersonProfile {
  const PersonProfile({
    required this.id,
    required this.familyId,
    required this.name,
    required this.isLinked,
    this.birthDate,
    this.birthPrecision,
    this.about,
    this.avatarPath,
    this.passingDate,
    this.passingPrecision,
    this.passedAway = false,
  });

  final String id;
  final String familyId;
  final String name;
  final DateTime? birthDate;
  final String? birthPrecision;
  final String? about;
  final String? avatarPath;
  final DateTime? passingDate;
  final String? passingPrecision;
  final bool passedAway;
  final bool isLinked;

  factory PersonProfile.fromJson(Map<String, dynamic> json) {
    return PersonProfile(
      id: json['id'] as String,
      familyId: json['family_id'] as String,
      name: json['name'] as String,
      birthDate: personDateFromJson(json['birth_date']),
      birthPrecision: json['birth_precision'] as String?,
      about: json['about'] as String?,
      avatarPath: json['avatar_path'] as String?,
      passingDate: personDateFromJson(json['passing_date']),
      passingPrecision: json['passing_precision'] as String?,
      passedAway: json['passed_away'] == true,
      isLinked: json['is_linked'] == true,
    );
  }
}

/// PostgREST returns a `returns table` function as a one-element list.
PersonProfile? personProfileFromRpc(Object? res) {
  final row = switch (res) {
    List(isEmpty: true) => null,
    final List rows => rows.first,
    final Map map => map,
    _ => null,
  };
  if (row is! Map) return null;
  return PersonProfile.fromJson(
    row.map((key, value) => MapEntry(key.toString(), value)),
  );
}

class PersonProfileNotFound implements Exception {
  const PersonProfileNotFound();
}

const personAvatarsBucket = 'person-avatars';

String personAvatarObjectPath(String personId) => '$personId/avatar.jpg';

/// Year → YYYY-01-01, month → YYYY-MM-01, day → that date. Never a range.
({DateTime date, String precision}) storedPersonDate({
  required int year,
  int? month,
  int? day,
}) {
  if (month != null && day != null) {
    return (date: DateTime(year, month, day), precision: 'day');
  }
  if (month != null) {
    return (date: DateTime(year, month, 1), precision: 'month');
  }
  return (date: DateTime(year, 1, 1), precision: 'year');
}

DateTime? personDateFromJson(Object? raw) {
  if (raw == null) return null;
  if (raw is DateTime) return raw;
  if (raw is String && raw.isNotEmpty) return DateTime.parse(raw);
  return null;
}

String personDateIso(DateTime date) {
  final y = date.year.toString().padLeft(4, '0');
  final m = date.month.toString().padLeft(2, '0');
  final d = date.day.toString().padLeft(2, '0');
  return '$y-$m-$d';
}

/// Rejects an empty name, or an about longer than 500, before the network.
void ensureValidPersonCreate({required String name, String? about}) {
  if (name.trim().isEmpty) {
    throw ArgumentError.value(name, 'name', 'must not be empty');
  }
  if (about != null && about.length > 500) {
    throw ArgumentError.value(about, 'about', 'must be at most 500 characters');
  }
}

abstract class PeopleGateway {
  Future<List<Person>> listPeople(String familyId);

  /// People in [familyId]'s tree. Linked rows take a trimmed birth from
  /// `person_profile`. The default reads [listPeople] so fakes stay unchanged.
  Future<List<Person>> listTreePeople(String familyId) => listPeople(familyId);

  Future<Person> createPerson({
    required String familyId,
    required String name,
    String? about,
    String? email,
    bool passedAway = false,
    List<int>? pictureBytes,
  });

  /// Tree-member row, including `user_id`. Not `person_profile`.
  Future<Person?> personForEdit(String personId) async => null;

  Future<PersonProfile?> personProfile(String personId) async => null;

  Future<Person> updatePerson({
    required String personId,
    required String name,
    bool passedAway = false,
    bool writePassedAway = false,
    String? about,
    bool writeAbout = false,
    String? email,
    bool writeEmail = false,
    List<int>? pictureBytes,
    bool clearPicture = false,
  }) async {
    throw UnimplementedError();
  }

  Future<List<Person>> listUnlinkedPeople(String familyId) async => const [];

  /// Home-family owner or co-owner. Other members, including owners of
  /// another family in the tree, are false.
  Future<bool> isHomeFamilySteward(String familyId) async => false;

  /// `mark_passed_away(p_person_id, p_value)`.
  Future<void> markPassedAway({required String personId, required bool value}) {
    throw UnimplementedError();
  }

  /// `person-avatars` when [path] is `{personId}/avatar.jpg`, else `avatars`.
  Future<String?> signedPictureUrl({
    required String personId,
    String? path,
  }) async => null;
}

/// PostgREST CRUD gateway for family-scoped `people` rows.
class PeopleApi implements PeopleGateway {
  PeopleApi({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  static const _rowSelect =
      'id, family_id, name, relationship, email, created_by, '
      'about, avatar_path, user_id, passed_away';

  static const _treeSelect = 'id, family_id, name, user_id, passed_away';

  @override
  Future<List<Person>> listPeople(String familyId) async {
    final rows = await _client
        .from('people')
        .select(_rowSelect)
        .eq('family_id', familyId)
        .order('name');
    return rows.map(Person.fromJson).toList();
  }

  @override
  Future<List<Person>> listTreePeople(String familyId) async {
    final familyIds = await _treeFamilyIds(familyId);
    final rows = await _client
        .from('people')
        .select(_treeSelect)
        .inFilter('family_id', familyIds)
        .order('name');
    return Future.wait(rows.map(_treePerson));
  }

  /// One [Person] per tree row. Linked profiles load together.
  Future<Person> _treePerson(Map<String, dynamic> row) async {
    final userId = row['user_id'] as String?;
    final profile = userId == null
        ? null
        : await personProfile(row['id'] as String);
    return Person(
      id: row['id'] as String,
      familyId: row['family_id'] as String,
      name: row['name'] as String,
      userId: userId,
      passedAway: profile?.passedAway ?? row['passed_away'] == true,
      birthDate: profile?.birthDate,
      birthPrecision: profile?.birthPrecision,
    );
  }

  /// Families in [familyId]'s tree. One family when the walk returns none.
  Future<List<String>> _treeFamilyIds(String familyId) async {
    final tree = await _client.rpc(
      'list_family_tree',
      params: {'fid': familyId},
    );
    if (tree is! List) {
      throw StateError('list_family_tree did not return a list');
    }
    final ids = <String>[
      for (final row in tree)
        if (row is Map && row['id'] is String) row['id'] as String,
    ];
    if (ids.isEmpty) return [familyId];
    return ids;
  }

  @override
  Future<Person> createPerson({
    required String familyId,
    required String name,
    String? about,
    String? email,
    bool passedAway = false,
    List<int>? pictureBytes,
  }) async {
    final trimmedAbout = _aboutOrNull(about);
    ensureValidPersonCreate(name: name, about: trimmedAbout);
    final trimmedEmail = _emailOrNull(email);
    final uid = _client.auth.currentUser!.id;
    final row = await _client
        .from('people')
        .insert({
          'family_id': familyId,
          'name': name.trim(),
          'relationship': null,
          'email': ?trimmedEmail,
          'passed_away': passedAway,
          'about': ?trimmedAbout,
          'created_by': uid,
        })
        .select(_rowSelect)
        .single();
    var person = Person.fromJson(row);
    if (pictureBytes != null && pictureBytes.isNotEmpty) {
      person = await _uploadPersonPicture(person, pictureBytes);
    }
    return person;
  }

  @override
  Future<Person?> personForEdit(String personId) async {
    final row = await _client
        .from('people')
        .select(_rowSelect)
        .eq('id', personId)
        .maybeSingle();
    if (row == null) return null;
    return Person.fromJson(row);
  }

  @override
  Future<PersonProfile?> personProfile(String personId) async {
    try {
      final res = await _client.rpc(
        'person_profile',
        params: {'p_person_id': personId},
      );
      return personProfileFromRpc(res);
    } on PostgrestException catch (error) {
      if (error.message.startsWith('NOT_FOUND:')) {
        throw const PersonProfileNotFound();
      }
      rethrow;
    }
  }

  @override
  Future<Person> updatePerson({
    required String personId,
    required String name,
    bool passedAway = false,
    bool writePassedAway = false,
    String? about,
    bool writeAbout = false,
    String? email,
    bool writeEmail = false,
    List<int>? pictureBytes,
    bool clearPicture = false,
  }) async {
    final trimmedAbout = writeAbout ? _aboutOrNull(about) : null;
    ensureValidPersonCreate(
      name: name,
      about: writeAbout ? trimmedAbout : null,
    );
    final clearing =
        clearPicture && (pictureBytes == null || pictureBytes.isEmpty);
    final patch = <String, dynamic>{
      'name': name.trim(),
      'updated_at': DateTime.now().toUtc().toIso8601String(),
      if (clearing) 'avatar_path': null,
    };
    if (writePassedAway) patch['passed_away'] = passedAway;
    if (writeAbout) patch['about'] = trimmedAbout;
    if (writeEmail) patch['email'] = _emailOrNull(email);
    final row = await _client
        .from('people')
        .update(patch)
        .eq('id', personId)
        .select(_rowSelect)
        .single();
    var person = Person.fromJson(row);
    if (pictureBytes != null && pictureBytes.isNotEmpty) {
      person = await _uploadPersonPicture(person, pictureBytes);
    }
    return person;
  }

  @override
  Future<bool> isHomeFamilySteward(String familyId) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return false;
    final row = await _client
        .from('memberships')
        .select('role')
        .eq('family_id', familyId)
        .eq('user_id', uid)
        .maybeSingle();
    final role = row?['role'];
    return originSteward(role is String ? role : null);
  }

  @override
  Future<void> markPassedAway({
    required String personId,
    required bool value,
  }) async {
    await _client.rpc(
      'mark_passed_away',
      params: {'p_person_id': personId, 'p_value': value},
    );
  }

  @override
  Future<List<Person>> listUnlinkedPeople(String familyId) async {
    final res = await _client.rpc(
      'list_unlinked_people',
      params: {'p_family_id': familyId},
    );
    if (res is! List) return const [];
    return [
      for (final row in res)
        if (row is Map)
          Person(
            id: row['id'] as String,
            familyId: row['family_id'] as String,
            name: row['name'] as String,
            email: row['email'] as String?,
          ),
    ];
  }

  @override
  Future<String?> signedPictureUrl({
    required String personId,
    String? path,
  }) async {
    if (path == null || path.isEmpty) return null;
    final bucket = path == personAvatarObjectPath(personId)
        ? personAvatarsBucket
        : avatarsBucketName;
    return _client.storage.from(bucket).createSignedUrl(path, 3600);
  }

  Future<Person> _uploadPersonPicture(Person person, List<int> bytes) async {
    final compressed = compressStoryPhoto(
      Uint8List.fromList(bytes),
      maxEdge: 512,
      quality: 80,
    );
    final path = personAvatarObjectPath(person.id);
    await _client.storage
        .from(personAvatarsBucket)
        .uploadBinary(
          path,
          compressed.bytes,
          fileOptions: const FileOptions(
            contentType: 'image/jpeg',
            upsert: true,
          ),
        );
    final row = await _client
        .from('people')
        .update({
          'avatar_path': path,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', person.id)
        .select(_rowSelect)
        .single();
    return Person.fromJson(row);
  }
}

const avatarsBucketName = 'avatars';

String? _emailOrNull(String? email) {
  if (email == null) return null;
  final trimmed = email.trim();
  if (trimmed.isEmpty) return null;
  return trimmed;
}

String? _aboutOrNull(String? about) {
  if (about == null) return null;
  if (about.isEmpty) return null;
  return about;
}
