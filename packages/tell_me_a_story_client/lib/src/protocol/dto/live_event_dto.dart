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
import '../dto/live_kind.dart' as _iuy9h9wl;
import '../story_status.dart' as _irz424ig;

/// Posted after commit to family:<familyId>, tree:<treeId> and, when storyId
/// is set, story:<storyId>. A `family` event goes to tree:<treeId> only.
abstract class LiveEventDto
    implements _isc.SerializableModel, _isc.ProtocolSerialization {
  LiveEventDto._({
    required this.familyId,
    this.storyId,
    required this.kind,
    this.storyStatus,
    required this.deleted,
  });

  factory LiveEventDto({
    required _isc.UuidValue familyId,
    _isc.UuidValue? storyId,
    required _iuy9h9wl.LiveKind kind,
    _irz424ig.StoryStatus? storyStatus,
    required bool deleted,
  }) = _LiveEventDtoImpl;

  factory LiveEventDto.fromJson(Map<String, dynamic> jsonSerialization) {
    return LiveEventDto(
      familyId: _isc.UuidValueJsonExtension.fromJson(
        jsonSerialization['familyId'],
      ),
      storyId: jsonSerialization['storyId'] == null
          ? null
          : _isc.UuidValueJsonExtension.fromJson(jsonSerialization['storyId']),
      kind: _iuy9h9wl.LiveKind.fromJson((jsonSerialization['kind'] as String)),
      storyStatus: jsonSerialization['storyStatus'] == null
          ? null
          : _irz424ig.StoryStatus.fromJson(
              (jsonSerialization['storyStatus'] as String),
            ),
      deleted: _isc.BoolJsonExtension.fromJson(jsonSerialization['deleted']),
    );
  }

  _isc.UuidValue familyId;

  _isc.UuidValue? storyId;

  _iuy9h9wl.LiveKind kind;

  _irz424ig.StoryStatus? storyStatus;

  bool deleted;

  /// Returns a shallow copy of this [LiveEventDto]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  LiveEventDto copyWith({
    _isc.UuidValue? familyId,
    _isc.UuidValue? storyId = const _isc.$UndefinedUuidValue(),
    _iuy9h9wl.LiveKind? kind,
    _irz424ig.StoryStatus? storyStatus,
    bool? deleted,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'LiveEventDto',
      'familyId': familyId.toJson(),
      if (storyId != null) 'storyId': storyId?.toJson(),
      'kind': kind.toJson(),
      if (storyStatus != null) 'storyStatus': storyStatus?.toJson(),
      'deleted': deleted,
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'LiveEventDto',
      'familyId': familyId.toJson(),
      if (storyId != null) 'storyId': storyId?.toJson(),
      'kind': kind.toJson(),
      if (storyStatus != null) 'storyStatus': storyStatus?.toJson(),
      'deleted': deleted,
    };
  }

  @override
  String toString() {
    return _isc.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _LiveEventDtoImpl extends LiveEventDto {
  _LiveEventDtoImpl({
    required _isc.UuidValue familyId,
    _isc.UuidValue? storyId,
    required _iuy9h9wl.LiveKind kind,
    _irz424ig.StoryStatus? storyStatus,
    required bool deleted,
  }) : super._(
         familyId: familyId,
         storyId: storyId,
         kind: kind,
         storyStatus: storyStatus,
         deleted: deleted,
       );

  /// Returns a shallow copy of this [LiveEventDto]
  /// with some or all fields replaced by the given arguments.
  @_isc.useResult
  @override
  LiveEventDto copyWith({
    _isc.UuidValue? familyId,
    _isc.UuidValue? storyId = const _isc.$UndefinedUuidValue(),
    _iuy9h9wl.LiveKind? kind,
    Object? storyStatus = _Undefined,
    bool? deleted,
  }) {
    return LiveEventDto(
      familyId: familyId ?? this.familyId,
      storyId: storyId is _isc.UndefinedSentinel ? this.storyId : storyId,
      kind: kind ?? this.kind,
      storyStatus: storyStatus is _irz424ig.StoryStatus?
          ? storyStatus
          : this.storyStatus,
      deleted: deleted ?? this.deleted,
    );
  }
}
