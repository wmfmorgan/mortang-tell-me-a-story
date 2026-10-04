import 'package:supabase_flutter/supabase_flutter.dart';

/// A family the signed-in member can already read.
class MemberFamily {
  const MemberFamily({
    required this.id,
    required this.name,
    required this.createdAt,
    this.parentFamilyId,
  });

  final String id;
  final String name;
  final String? parentFamilyId;
  final DateTime createdAt;

  factory MemberFamily.fromJson(Map<String, dynamic> json) {
    return MemberFamily(
      id: json['id'] as String,
      name: (json['name'] as String?)?.trim().isNotEmpty == true
          ? (json['name'] as String).trim()
          : 'Family',
      parentFamilyId: json['parent_family_id'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.utc(2020),
    );
  }
}

abstract class FamiliesGateway {
  Future<List<MemberFamily>> listMine();
}

class FamiliesApi implements FamiliesGateway {
  FamiliesApi({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  @override
  Future<List<MemberFamily>> listMine() async {
    final uid = _client.auth.currentUser!.id;
    final rows = await _client
        .from('memberships')
        .select('families(id, name, parent_family_id, created_at)')
        .eq('user_id', uid);
    final families = <MemberFamily>[];
    for (final row in rows) {
      final embedded = row['families'];
      if (embedded is Map<String, dynamic>) {
        families.add(MemberFamily.fromJson(embedded));
      } else if (embedded is Map) {
        families.add(
          MemberFamily.fromJson(Map<String, dynamic>.from(embedded)),
        );
      }
    }
    return families;
  }
}
