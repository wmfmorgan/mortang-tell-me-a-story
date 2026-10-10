import 'package:supabase_flutter/supabase_flutter.dart';

/// Family-scoped person row (shared list; not deceased-only / public directory).
class Person {
  const Person({
    required this.id,
    required this.familyId,
    required this.name,
    required this.relationship,
    this.email,
    required this.createdBy,
  });

  final String id;
  final String familyId;
  final String name;
  final String relationship;
  final String? email;
  final String createdBy;

  factory Person.fromJson(Map<String, dynamic> json) {
    return Person(
      id: json['id'] as String,
      familyId: json['family_id'] as String,
      name: json['name'] as String,
      relationship: json['relationship'] as String,
      email: json['email'] as String?,
      createdBy: json['created_by'] as String,
    );
  }
}

/// Rejects empty / whitespace-only name or relationship before network.
void ensureValidPersonCreate({
  required String name,
  required String relationship,
}) {
  if (name.trim().isEmpty) {
    throw ArgumentError.value(name, 'name', 'must not be empty');
  }
  if (relationship.trim().isEmpty) {
    throw ArgumentError.value(
      relationship,
      'relationship',
      'must not be empty',
    );
  }
}

abstract class PeopleGateway {
  Future<List<Person>> listPeople(String familyId);

  /// Name and relationship for a viewer who can read the family tree and is
  /// not a member. The default reads [listPeople] so fakes stay unchanged.
  Future<List<Person>> listTreePeople(String familyId) => listPeople(familyId);

  Future<Person> createPerson({
    required String familyId,
    required String name,
    required String relationship,
    String? email,
  });
}

/// PostgREST CRUD gateway for family-scoped `people` rows.
class PeopleApi implements PeopleGateway {
  PeopleApi({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  @override
  Future<List<Person>> listPeople(String familyId) async {
    final rows = await _client
        .from('people')
        .select('id, family_id, name, relationship, email, created_by')
        .eq('family_id', familyId)
        .order('name');
    return rows.map(Person.fromJson).toList();
  }

  @override
  Future<List<Person>> listTreePeople(String familyId) async {
    final rows = await _client
        .from('people_tree_read')
        .select('id, family_id, name, relationship')
        .eq('family_id', familyId)
        .order('name');
    return [
      for (final row in rows)
        Person(
          id: row['id'] as String,
          familyId: row['family_id'] as String,
          name: row['name'] as String,
          relationship: row['relationship'] as String,
          createdBy: '',
        ),
    ];
  }

  @override
  Future<Person> createPerson({
    required String familyId,
    required String name,
    required String relationship,
    String? email,
  }) async {
    ensureValidPersonCreate(name: name, relationship: relationship);
    final uid = _client.auth.currentUser!.id;
    final row = await _client
        .from('people')
        .insert({
          'family_id': familyId,
          'name': name.trim(),
          'relationship': relationship.trim(),
          if (email != null && email.trim().isNotEmpty) 'email': email.trim(),
          'created_by': uid,
        })
        .select()
        .single();
    return Person.fromJson(row);
  }
}
