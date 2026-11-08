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
import 'package:serverpod/serverpod.dart' as _is;
import '../dto/live_kind.dart' as _iuy9h9wl;
import '../story_status.dart' as _irz424ig;

/// Posted after commit to family:<familyId>, tree:<treeId> and, when storyId
/// is set, story:<storyId>. A `family` event goes to tree:<treeId> only.
abstract class LiveEventDto
    implements _is.SerializableModel, _is.ProtocolSerialization {
  LiveEventDto._({
    required this.familyId,
    this.storyId,
    required this.kind,
    this.storyStatus,
    required this.deleted,
  });

  factory LiveEventDto({
    required _is.UuidValue familyId,
    _is.UuidValue? storyId,
    required _iuy9h9wl.LiveKind kind,
    _irz424ig.StoryStatus? storyStatus,
    required bool deleted,
  }) = _LiveEventDtoImpl;

  factory LiveEventDto.fromJson(Map<String, dynamic> jsonSerialization) {
    return LiveEventDto(
      familyId: _is.UuidValueJsonExtension.fromJson(
        jsonSerialization['familyId'],
      ),
      storyId: jsonSerialization['storyId'] == null
          ? null
          : _is.UuidValueJsonExtension.fromJson(jsonSerialization['storyId']),
      kind: _iuy9h9wl.LiveKind.fromJson((jsonSerialization['kind'] as String)),
      storyStatus: jsonSerialization['storyStatus'] == null
          ? null
          : _irz424ig.StoryStatus.fromJson(
              (jsonSerialization['storyStatus'] as String),
            ),
      deleted: _is.BoolJsonExtension.fromJson(jsonSerialization['deleted']),
    );
  }

  _is.UuidValue familyId;

  _is.UuidValue? storyId;

  _iuy9h9wl.LiveKind kind;

  _irz424ig.StoryStatus? storyStatus;

  bool deleted;

  /// Returns a shallow copy of this [LiveEventDto]
  /// with some or all fields replaced by the given arguments.
  @_is.useResult
  LiveEventDto copyWith({
    _is.UuidValue? familyId,
    _is.UuidValue? storyId = const _is.$UndefinedUuidValue(),
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
    return _is.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _LiveEventDtoImpl extends LiveEventDto {
  _LiveEventDtoImpl({
    required _is.UuidValue familyId,
    _is.UuidValue? storyId,
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
  @_is.useResult
  @override
  LiveEventDto copyWith({
    _is.UuidValue? familyId,
    _is.UuidValue? storyId = const _is.$UndefinedUuidValue(),
    _iuy9h9wl.LiveKind? kind,
    Object? storyStatus = _Undefined,
    bool? deleted,
  }) {
    return LiveEventDto(
      familyId: familyId ?? this.familyId,
      storyId: storyId is _is.UndefinedSentinel ? this.storyId : storyId,
      kind: kind ?? this.kind,
      storyStatus: storyStatus is _irz424ig.StoryStatus?
          ? storyStatus
          : this.storyStatus,
      deleted: deleted ?? this.deleted,
    );
  }
}
