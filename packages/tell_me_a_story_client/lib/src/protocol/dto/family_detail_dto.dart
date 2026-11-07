/* AUTOMATICALLY GENERATED CODE DO NOT MODIFY */
/*   To generate run: "serverpod generate"    */

// ignore_for_file: implementation_imports
// ignore_for_file: library_private_types_in_public_api
// ignore_for_file: non_constant_identifier_names
// ignore_for_file: public_member_api_docs
// ignore_for_file: type_literal_in_constant_pattern
// ignore_for_file: use_super_parameters
// ignore_for_file: invalid_use_of_internal_member

// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'package:serverpod_client/serverpod_client.dart' as _isc;
import 'package:tell_me_a_story_client/src/protocol/protocol.dart' as _ipmlb5v5;
import '../dto/family_member_dto.dart' as _iu0vkf0x;
import '../dto/pending_invite_dto.dart' as _i6tk8dmd;
import '../membership_role.dart' as _id460rmf;

/// Family + members + pending invites in one call (FamilyEndpoint.detail).
abstract class FamilyDetailDto
    implements _isc.SerializableModel, _isc.ProtocolSerialization {
  FamilyDetailDto._({
    required this.id,
    required this.name,
    required this.myRole,
    required this.members,
    required this.pendingInvites,
  });

  factory FamilyDetailDto({
    required _isc.UuidValue id,
    required String name,
    required _id460rmf.MembershipRole myRole,
    required List<_iu0vkf0x.FamilyMemberDto> members,
    required List<_i6tk8dmd.PendingInviteDto> pendingInvites,
  }) = _FamilyDetailDtoImpl;

  factory FamilyDetailDto.fromJson(Map<String, dynamic> jsonSerialization) {
    return FamilyDetailDto(
      id: _isc.UuidValueJsonExtension.fromJson(jsonSerialization['id']),
      name: jsonSerialization['name'] as String,
      myRole: _id460rmf.MembershipRole.fromJson(
        (jsonSerialization['myRole'] as String),
      ),
      members: _ipmlb5v5.Protocol()
          .deserialize<List<_iu0vkf0x.FamilyMemberDto>>(
            jsonSerialization['members'],
          ),
      pendingInvites: _ipmlb5v5.Protocol()
          .deserialize<List<_i6tk8dmd.PendingInviteDto>>(
            jsonSerialization['pendingInvites'],
          ),
    );
  }

  _isc.UuidValue id;

  String name;

  _id460rmf.MembershipRole myRole;

  List<_iu0vkf0x.FamilyMemberDto> members;

  List<_i6tk8dmd.PendingInviteDto> pendingInvites;

  /// Returns a shallow copy of this [FamilyDetailDto]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  FamilyDetailDto copyWith({
    _isc.UuidValue? id,
    String? name,
    _id460rmf.MembershipRole? myRole,
    List<_iu0vkf0x.FamilyMemberDto>? members,
    List<_i6tk8dmd.PendingInviteDto>? pendingInvites,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'FamilyDetailDto',
      'id': id.toJson(),
      'name': name,
      'myRole': myRole.toJson(),
      'members': members.toJson(valueToJson: (v) => v.toJson()),
      'pendingInvites': pendingInvites.toJson(valueToJson: (v) => v.toJson()),
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'FamilyDetailDto',
      'id': id.toJson(),
      'name': name,
      'myRole': myRole.toJson(),
      'members': members.toJson(valueToJson: (v) => v.toJsonForProtocol()),
      'pendingInvites': pendingInvites.toJson(
        valueToJson: (v) => v.toJsonForProtocol(),
      ),
    };
  }

  @override
  String toString() {
    return _isc.SerializationManager.encode(this);
  }
}

class _FamilyDetailDtoImpl extends FamilyDetailDto {
  _FamilyDetailDtoImpl({
    required _isc.UuidValue id,
    required String name,
    required _id460rmf.MembershipRole myRole,
    required List<_iu0vkf0x.FamilyMemberDto> members,
    required List<_i6tk8dmd.PendingInviteDto> pendingInvites,
  }) : super._(
         id: id,
         name: name,
         myRole: myRole,
         members: members,
         pendingInvites: pendingInvites,
       );

  /// Returns a shallow copy of this [FamilyDetailDto]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  @override
  FamilyDetailDto copyWith({
    _isc.UuidValue? id,
    String? name,
    _id460rmf.MembershipRole? myRole,
    List<_iu0vkf0x.FamilyMemberDto>? members,
    List<_i6tk8dmd.PendingInviteDto>? pendingInvites,
  }) {
    return FamilyDetailDto(
      id: id ?? this.id,
      name: name ?? this.name,
      myRole: myRole ?? this.myRole,
      members: members ?? this.members.map((e0) => e0.copyWith()).toList(),
      pendingInvites:
          pendingInvites ??
          this.pendingInvites.map((e0) => e0.copyWith()).toList(),
    );
  }
}
