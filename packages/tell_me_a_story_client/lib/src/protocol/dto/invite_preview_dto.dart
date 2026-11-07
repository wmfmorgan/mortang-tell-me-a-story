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

/// Anonymous invite preview. Invalid previews carry no family or inviter.
abstract class InvitePreviewDto
    implements _isc.SerializableModel, _isc.ProtocolSerialization {
  InvitePreviewDto._({
    required this.valid,
    this.familyId,
    this.familyName,
    this.inviterName,
  });

  factory InvitePreviewDto({
    required bool valid,
    _isc.UuidValue? familyId,
    String? familyName,
    String? inviterName,
  }) = _InvitePreviewDtoImpl;

  factory InvitePreviewDto.fromJson(Map<String, dynamic> jsonSerialization) {
    return InvitePreviewDto(
      valid: _isc.BoolJsonExtension.fromJson(jsonSerialization['valid']),
      familyId: jsonSerialization['familyId'] == null
          ? null
          : _isc.UuidValueJsonExtension.fromJson(jsonSerialization['familyId']),
      familyName: jsonSerialization['familyName'] as String?,
      inviterName: jsonSerialization['inviterName'] as String?,
    );
  }

  bool valid;

  _isc.UuidValue? familyId;

  String? familyName;

  String? inviterName;

  /// Returns a shallow copy of this [InvitePreviewDto]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  InvitePreviewDto copyWith({
    bool? valid,
    _isc.UuidValue? familyId = const _isc.$UndefinedUuidValue(),
    String? familyName,
    String? inviterName,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'InvitePreviewDto',
      'valid': valid,
      if (familyId != null) 'familyId': familyId?.toJson(),
      if (familyName != null) 'familyName': familyName,
      if (inviterName != null) 'inviterName': inviterName,
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'InvitePreviewDto',
      'valid': valid,
      if (familyId != null) 'familyId': familyId?.toJson(),
      if (familyName != null) 'familyName': familyName,
      if (inviterName != null) 'inviterName': inviterName,
    };
  }

  @override
  String toString() {
    return _isc.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _InvitePreviewDtoImpl extends InvitePreviewDto {
  _InvitePreviewDtoImpl({
    required bool valid,
    _isc.UuidValue? familyId,
    String? familyName,
    String? inviterName,
  }) : super._(
         valid: valid,
         familyId: familyId,
         familyName: familyName,
         inviterName: inviterName,
       );

  /// Returns a shallow copy of this [InvitePreviewDto]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  @override
  InvitePreviewDto copyWith({
    bool? valid,
    _isc.UuidValue? familyId = const _isc.$UndefinedUuidValue(),
    Object? familyName = _Undefined,
    Object? inviterName = _Undefined,
  }) {
    return InvitePreviewDto(
      valid: valid ?? this.valid,
      familyId: familyId is _isc.UndefinedSentinel ? this.familyId : familyId,
      familyName: familyName is String? ? familyName : this.familyName,
      inviterName: inviterName is String? ? inviterName : this.inviterName,
    );
  }
}
