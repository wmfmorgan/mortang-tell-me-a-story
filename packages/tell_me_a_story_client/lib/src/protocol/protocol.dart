/* AUTOMATICALLY GENERATED CODE DO NOT MODIFY */
/*   To generate run: "serverpod generate"    */

// ignore_for_file: implementation_imports
// ignore_for_file: library_private_types_in_public_api
// ignore_for_file: non_constant_identifier_names
// ignore_for_file: public_member_api_docs
// ignore_for_file: type_literal_in_constant_pattern
// ignore_for_file: use_super_parameters
// ignore_for_file: invalid_use_of_internal_member
// ignore_for_file: dead_code, unnecessary_type_check

// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'package:serverpod_auth_core_client/serverpod_auth_core_client.dart'
    as _iacc;
import 'package:serverpod_auth_idp_client/serverpod_auth_idp_client.dart'
    as _iaic;
import 'package:serverpod_client/serverpod_client.dart' as _isc;
import 'app_error_code.dart' as _imu8gbx5;
import 'app_exception.dart' as _it4z223c;
import 'app_user.dart' as _i2j2xfrn;
import 'birth_visibility.dart' as _i2x3tia5;
import 'date_precision.dart' as _ilvyd2nu;
import 'family.dart' as _igf5ho4a;
import 'membership.dart' as _iu35fd1a;
import 'membership_role.dart' as _iur1rrwm;
import 'note_kind.dart' as _ixhn57mr;
import 'person.dart' as _iensfz4m;
import 'photo.dart' as _ii8pt9rm;
import 'place.dart' as _isaqapjx;
import 'story.dart' as _ixuwv6na;
import 'story_note.dart' as _iugi3tvg;
import 'story_person.dart' as _i0053fvj;
import 'story_status.dart' as _ixc1exsr;
import 'tree.dart' as _i5e6tmks;
export 'app_error_code.dart';
export 'app_exception.dart';
export 'app_user.dart';
export 'birth_visibility.dart';
export 'date_precision.dart';
export 'family.dart';
export 'membership.dart';
export 'membership_role.dart';
export 'note_kind.dart';
export 'person.dart';
export 'photo.dart';
export 'place.dart';
export 'story.dart';
export 'story_note.dart';
export 'story_person.dart';
export 'story_status.dart';
export 'tree.dart';
export 'client.dart';

class Protocol extends _isc.SerializationManager
    implements _isc.ProtocolDeserializationProvider {
  Protocol._();

  factory Protocol() => _instance;

  static final Protocol _instance = Protocol._().._registerHostProtocols();

  @override
  _isc.ProtocolDeserialization get deserializationMetadata =>
      _isc.ProtocolDeserialization.cached(
        this,
        types: const [
          _isc.getType<_imu8gbx5.AppErrorCode>,
          _isc.getType<_it4z223c.AppException>,
          _isc.getType<_i2j2xfrn.AppUser>,
          _isc.getType<_i2x3tia5.BirthVisibility>,
          _isc.getType<_ilvyd2nu.DatePrecision>,
          _isc.getType<_igf5ho4a.Family>,
          _isc.getType<_iu35fd1a.Membership>,
          _isc.getType<_iur1rrwm.MembershipRole>,
          _isc.getType<_ixhn57mr.NoteKind>,
          _isc.getType<_iensfz4m.Person>,
          _isc.getType<_ii8pt9rm.Photo>,
          _isc.getType<_isaqapjx.Place>,
          _isc.getType<_ixuwv6na.Story>,
          _isc.getType<_iugi3tvg.StoryNote>,
          _isc.getType<_i0053fvj.StoryPerson>,
          _isc.getType<_ixc1exsr.StoryStatus>,
          _isc.getType<_i5e6tmks.Tree>,
          _isc.getType<_imu8gbx5.AppErrorCode?>,
          _isc.getType<_it4z223c.AppException?>,
          _isc.getType<_i2j2xfrn.AppUser?>,
          _isc.getType<_i2x3tia5.BirthVisibility?>,
          _isc.getType<_ilvyd2nu.DatePrecision?>,
          _isc.getType<_igf5ho4a.Family?>,
          _isc.getType<_iu35fd1a.Membership?>,
          _isc.getType<_iur1rrwm.MembershipRole?>,
          _isc.getType<_ixhn57mr.NoteKind?>,
          _isc.getType<_iensfz4m.Person?>,
          _isc.getType<_ii8pt9rm.Photo?>,
          _isc.getType<_isaqapjx.Place?>,
          _isc.getType<_ixuwv6na.Story?>,
          _isc.getType<_iugi3tvg.StoryNote?>,
          _isc.getType<_i0053fvj.StoryPerson?>,
          _isc.getType<_ixc1exsr.StoryStatus?>,
          _isc.getType<_i5e6tmks.Tree?>,
        ],
        modules: const [
          _iaic.Protocol.new,
          _iacc.Protocol.new,
        ],
        classNames: const [
          'AppErrorCode',
          'AppException',
          'AppUser',
          'BirthVisibility',
          'DatePrecision',
          'Family',
          'Membership',
          'MembershipRole',
          'NoteKind',
          'Person',
          'Photo',
          'Place',
          'Story',
          'StoryNote',
          'StoryPerson',
          'StoryStatus',
          'Tree',
        ],
      );

  static String? getClassNameFromObjectJson(dynamic data) =>
      _isc.ProtocolDeserialization.readClassName(data);

  @override
  T deserialize<T>(
    dynamic data, [
    Type? t,
  ]) {
    t ??= T;
    final rawDataClassName = _isc.ProtocolDeserialization.readClassName(data);
    final dataClassName = rawDataClassName;
    if (dataClassName != null && dataClassName != getClassNameForType(t)) {
      try {
        return deserializeByClassName({
          'className': dataClassName,
          'data': data,
        });
      } on _isc.DeserializationClassNameNotFoundException catch (_) {
        // If the className is not recognized (e.g., older client receiving
        // data with a new subtype), fall back to deserializing without the
        // className, using the expected type T.
      }
    }

    if (t == _imu8gbx5.AppErrorCode) {
      return _imu8gbx5.AppErrorCode.fromJson(data) as T;
    }
    if (t == _it4z223c.AppException) {
      return _it4z223c.AppException.fromJson(data) as T;
    }
    if (t == _i2j2xfrn.AppUser) {
      return _i2j2xfrn.AppUser.fromJson(data) as T;
    }
    if (t == _i2x3tia5.BirthVisibility) {
      return _i2x3tia5.BirthVisibility.fromJson(data) as T;
    }
    if (t == _ilvyd2nu.DatePrecision) {
      return _ilvyd2nu.DatePrecision.fromJson(data) as T;
    }
    if (t == _igf5ho4a.Family) {
      return _igf5ho4a.Family.fromJson(data) as T;
    }
    if (t == _iu35fd1a.Membership) {
      return _iu35fd1a.Membership.fromJson(data) as T;
    }
    if (t == _iur1rrwm.MembershipRole) {
      return _iur1rrwm.MembershipRole.fromJson(data) as T;
    }
    if (t == _ixhn57mr.NoteKind) {
      return _ixhn57mr.NoteKind.fromJson(data) as T;
    }
    if (t == _iensfz4m.Person) {
      return _iensfz4m.Person.fromJson(data) as T;
    }
    if (t == _ii8pt9rm.Photo) {
      return _ii8pt9rm.Photo.fromJson(data) as T;
    }
    if (t == _isaqapjx.Place) {
      return _isaqapjx.Place.fromJson(data) as T;
    }
    if (t == _ixuwv6na.Story) {
      return _ixuwv6na.Story.fromJson(data) as T;
    }
    if (t == _iugi3tvg.StoryNote) {
      return _iugi3tvg.StoryNote.fromJson(data) as T;
    }
    if (t == _i0053fvj.StoryPerson) {
      return _i0053fvj.StoryPerson.fromJson(data) as T;
    }
    if (t == _ixc1exsr.StoryStatus) {
      return _ixc1exsr.StoryStatus.fromJson(data) as T;
    }
    if (t == _i5e6tmks.Tree) {
      return _i5e6tmks.Tree.fromJson(data) as T;
    }
    if (t == _isc.getType<_imu8gbx5.AppErrorCode?>()) {
      return (data != null ? _imu8gbx5.AppErrorCode.fromJson(data) : null) as T;
    }
    if (t == _isc.getType<_it4z223c.AppException?>()) {
      return (data != null ? _it4z223c.AppException.fromJson(data) : null) as T;
    }
    if (t == _isc.getType<_i2j2xfrn.AppUser?>()) {
      return (data != null ? _i2j2xfrn.AppUser.fromJson(data) : null) as T;
    }
    if (t == _isc.getType<_i2x3tia5.BirthVisibility?>()) {
      return (data != null ? _i2x3tia5.BirthVisibility.fromJson(data) : null)
          as T;
    }
    if (t == _isc.getType<_ilvyd2nu.DatePrecision?>()) {
      return (data != null ? _ilvyd2nu.DatePrecision.fromJson(data) : null)
          as T;
    }
    if (t == _isc.getType<_igf5ho4a.Family?>()) {
      return (data != null ? _igf5ho4a.Family.fromJson(data) : null) as T;
    }
    if (t == _isc.getType<_iu35fd1a.Membership?>()) {
      return (data != null ? _iu35fd1a.Membership.fromJson(data) : null) as T;
    }
    if (t == _isc.getType<_iur1rrwm.MembershipRole?>()) {
      return (data != null ? _iur1rrwm.MembershipRole.fromJson(data) : null)
          as T;
    }
    if (t == _isc.getType<_ixhn57mr.NoteKind?>()) {
      return (data != null ? _ixhn57mr.NoteKind.fromJson(data) : null) as T;
    }
    if (t == _isc.getType<_iensfz4m.Person?>()) {
      return (data != null ? _iensfz4m.Person.fromJson(data) : null) as T;
    }
    if (t == _isc.getType<_ii8pt9rm.Photo?>()) {
      return (data != null ? _ii8pt9rm.Photo.fromJson(data) : null) as T;
    }
    if (t == _isc.getType<_isaqapjx.Place?>()) {
      return (data != null ? _isaqapjx.Place.fromJson(data) : null) as T;
    }
    if (t == _isc.getType<_ixuwv6na.Story?>()) {
      return (data != null ? _ixuwv6na.Story.fromJson(data) : null) as T;
    }
    if (t == _isc.getType<_iugi3tvg.StoryNote?>()) {
      return (data != null ? _iugi3tvg.StoryNote.fromJson(data) : null) as T;
    }
    if (t == _isc.getType<_i0053fvj.StoryPerson?>()) {
      return (data != null ? _i0053fvj.StoryPerson.fromJson(data) : null) as T;
    }
    if (t == _isc.getType<_ixc1exsr.StoryStatus?>()) {
      return (data != null ? _ixc1exsr.StoryStatus.fromJson(data) : null) as T;
    }
    if (t == _isc.getType<_i5e6tmks.Tree?>()) {
      return (data != null ? _i5e6tmks.Tree.fromJson(data) : null) as T;
    }
    final modules = deserializationMetadata.modulesForDeserialization(
      t,
      className: rawDataClassName,
    );
    for (final module in modules) {
      try {
        return module.deserialize<T>(data, t);
      } on _isc.DeserializationTypeNotFoundException catch (_) {}
    }

    return super.deserialize<T>(data, t);
  }

  static String? getClassNameForType(Type type) {
    return switch (type) {
      _imu8gbx5.AppErrorCode => 'AppErrorCode',
      _it4z223c.AppException => 'AppException',
      _i2j2xfrn.AppUser => 'AppUser',
      _i2x3tia5.BirthVisibility => 'BirthVisibility',
      _ilvyd2nu.DatePrecision => 'DatePrecision',
      _igf5ho4a.Family => 'Family',
      _iu35fd1a.Membership => 'Membership',
      _iur1rrwm.MembershipRole => 'MembershipRole',
      _ixhn57mr.NoteKind => 'NoteKind',
      _iensfz4m.Person => 'Person',
      _ii8pt9rm.Photo => 'Photo',
      _isaqapjx.Place => 'Place',
      _ixuwv6na.Story => 'Story',
      _iugi3tvg.StoryNote => 'StoryNote',
      _i0053fvj.StoryPerson => 'StoryPerson',
      _ixc1exsr.StoryStatus => 'StoryStatus',
      _i5e6tmks.Tree => 'Tree',
      _ => null,
    };
  }

  @override
  String? getClassNameForObject(Object? data) {
    String? className = super.getClassNameForObject(data);
    if (className != null) return className;

    if (data is Map<String, dynamic> && data['__className__'] is String) {
      return (data['__className__'] as String).replaceFirst(
        'tell_me_a_story.',
        '',
      );
    }

    switch (data) {
      case _imu8gbx5.AppErrorCode():
        return 'AppErrorCode';
      case _it4z223c.AppException():
        return 'AppException';
      case _i2j2xfrn.AppUser():
        return 'AppUser';
      case _i2x3tia5.BirthVisibility():
        return 'BirthVisibility';
      case _ilvyd2nu.DatePrecision():
        return 'DatePrecision';
      case _igf5ho4a.Family():
        return 'Family';
      case _iu35fd1a.Membership():
        return 'Membership';
      case _iur1rrwm.MembershipRole():
        return 'MembershipRole';
      case _ixhn57mr.NoteKind():
        return 'NoteKind';
      case _iensfz4m.Person():
        return 'Person';
      case _ii8pt9rm.Photo():
        return 'Photo';
      case _isaqapjx.Place():
        return 'Place';
      case _ixuwv6na.Story():
        return 'Story';
      case _iugi3tvg.StoryNote():
        return 'StoryNote';
      case _i0053fvj.StoryPerson():
        return 'StoryPerson';
      case _ixc1exsr.StoryStatus():
        return 'StoryStatus';
      case _i5e6tmks.Tree():
        return 'Tree';
    }
    className = _iaic.Protocol().getClassNameForObject(data);
    if (className != null) {
      return className.contains('.')
          ? className
          : 'serverpod_auth_idp.$className';
    }
    className = _iacc.Protocol().getClassNameForObject(data);
    if (className != null) {
      return className.contains('.')
          ? className
          : 'serverpod_auth_core.$className';
    }
    return null;
  }

  @override
  dynamic deserializeByClassName(Map<String, dynamic> data) {
    var dataClassName = data['className'];
    if (dataClassName is! String) {
      return super.deserializeByClassName(data);
    }
    if (dataClassName == 'AppErrorCode') {
      return deserialize<_imu8gbx5.AppErrorCode>(data['data']);
    }
    if (dataClassName == 'AppException') {
      return deserialize<_it4z223c.AppException>(data['data']);
    }
    if (dataClassName == 'AppUser') {
      return deserialize<_i2j2xfrn.AppUser>(data['data']);
    }
    if (dataClassName == 'BirthVisibility') {
      return deserialize<_i2x3tia5.BirthVisibility>(data['data']);
    }
    if (dataClassName == 'DatePrecision') {
      return deserialize<_ilvyd2nu.DatePrecision>(data['data']);
    }
    if (dataClassName == 'Family') {
      return deserialize<_igf5ho4a.Family>(data['data']);
    }
    if (dataClassName == 'Membership') {
      return deserialize<_iu35fd1a.Membership>(data['data']);
    }
    if (dataClassName == 'MembershipRole') {
      return deserialize<_iur1rrwm.MembershipRole>(data['data']);
    }
    if (dataClassName == 'NoteKind') {
      return deserialize<_ixhn57mr.NoteKind>(data['data']);
    }
    if (dataClassName == 'Person') {
      return deserialize<_iensfz4m.Person>(data['data']);
    }
    if (dataClassName == 'Photo') {
      return deserialize<_ii8pt9rm.Photo>(data['data']);
    }
    if (dataClassName == 'Place') {
      return deserialize<_isaqapjx.Place>(data['data']);
    }
    if (dataClassName == 'Story') {
      return deserialize<_ixuwv6na.Story>(data['data']);
    }
    if (dataClassName == 'StoryNote') {
      return deserialize<_iugi3tvg.StoryNote>(data['data']);
    }
    if (dataClassName == 'StoryPerson') {
      return deserialize<_i0053fvj.StoryPerson>(data['data']);
    }
    if (dataClassName == 'StoryStatus') {
      return deserialize<_ixc1exsr.StoryStatus>(data['data']);
    }
    if (dataClassName == 'Tree') {
      return deserialize<_i5e6tmks.Tree>(data['data']);
    }
    if (dataClassName.startsWith('serverpod_auth_idp.')) {
      return _iaic.Protocol().deserializeByClassName({
        ...data,
        'className': dataClassName.substring(19),
      });
    }
    if (dataClassName.startsWith('serverpod_auth_core.')) {
      return _iacc.Protocol().deserializeByClassName({
        ...data,
        'className': dataClassName.substring(20),
      });
    }
    return super.deserializeByClassName(data);
  }

  void _registerHostProtocols() {
    _iaic.Protocol().registerHostProtocol('tell_me_a_story', this);
    _iacc.Protocol().registerHostProtocol('tell_me_a_story', this);
  }

  @override
  String getModuleName() => 'tell_me_a_story';

  /// Maps any `Record`s known to this [Protocol] to their JSON representation
  ///
  /// Throws in case the record type is not known.
  ///
  /// This method will return `null` (only) for `null` inputs.
  Map<String, dynamic>? mapRecordToJson(Record? record) {
    if (record == null) {
      return null;
    }
    try {
      return _iaic.Protocol().mapRecordToJson(record);
    } catch (_) {}
    try {
      return _iacc.Protocol().mapRecordToJson(record);
    } catch (_) {}
    throw Exception('Unsupported record type ${record.runtimeType}');
  }
}
