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
import 'dart:typed_data' as _idt;
import 'package:serverpod_auth_core_client/serverpod_auth_core_client.dart'
    as _iacc;
import 'package:serverpod_auth_idp_client/serverpod_auth_idp_client.dart'
    as _iaic;
import 'package:serverpod_client/serverpod_client.dart' as _isc;
import 'package:tell_me_a_story_client/src/protocol/dto/family_member_dto.dart'
    as _ie59njid;
import 'package:tell_me_a_story_client/src/protocol/dto/member_family_dto.dart'
    as _ii9mmjc2;
import 'package:tell_me_a_story_client/src/protocol/dto/origin_dependent_dto.dart'
    as _i6upf1dr;
import 'package:tell_me_a_story_client/src/protocol/dto/person_dto.dart'
    as _ippgtqmg;
import 'package:tell_me_a_story_client/src/protocol/dto/photo_dto.dart'
    as _ighpoo1p;
import 'package:tell_me_a_story_client/src/protocol/dto/place_dto.dart'
    as _irx46cwk;
import 'package:tell_me_a_story_client/src/protocol/dto/steward_family_dto.dart'
    as _iy83v9y2;
import 'package:tell_me_a_story_client/src/protocol/dto/tree_family_dto.dart'
    as _iwn4wr2j;
import 'app_error_code.dart' as _imu8gbx5;
import 'app_exception.dart' as _it4z223c;
import 'app_user.dart' as _i2j2xfrn;
import 'birth_visibility.dart' as _i2x3tia5;
import 'date_precision.dart' as _ilvyd2nu;
import 'dto/cover_upload_ticket_dto.dart' as _ieh1xhhu;
import 'dto/created_invite_dto.dart' as _i5tlcydc;
import 'dto/decade_facet_dto.dart' as _i3bc4i2z;
import 'dto/family_detail_dto.dart' as _i454qtto;
import 'dto/family_directory_dto.dart' as _ibjtxzev;
import 'dto/family_member_dto.dart' as _i6t2z5gc;
import 'dto/family_roster_dto.dart' as _ihq257tz;
import 'dto/invite_preview_dto.dart' as _in2wbmsu;
import 'dto/kinship_dto.dart' as _ia1fjje5;
import 'dto/live_event_dto.dart' as _ipyvbztq;
import 'dto/live_kind.dart' as _i67kei86;
import 'dto/member_family_dto.dart' as _ir8o3gjk;
import 'dto/note_dto.dart' as _i6e6avtv;
import 'dto/origin_dependent_dto.dart' as _i9h96nn2;
import 'dto/own_profile_dto.dart' as _is5ywasv;
import 'dto/pending_invite_dto.dart' as _i5vdpx0m;
import 'dto/person_dto.dart' as _ig7qj6yo;
import 'dto/person_facet_dto.dart' as _ikbgxdng;
import 'dto/person_profile_dto.dart' as _i38icd77;
import 'dto/person_write_dto.dart' as _imob66rg;
import 'dto/photo_dto.dart' as _i3tneuol;
import 'dto/photo_ref_dto.dart' as _i91pkskm;
import 'dto/photo_upload_ticket_dto.dart' as _i5l4kjca;
import 'dto/place_dto.dart' as _ijvrvfy5;
import 'dto/place_facet_dto.dart' as _ioxclq7u;
import 'dto/place_input_dto.dart' as _i85hzch5;
import 'dto/search_sort.dart' as _ikw9cscj;
import 'dto/steward_family_dto.dart' as _imtvyjr9;
import 'dto/story_dto.dart' as _ipnasz46;
import 'dto/story_facets_dto.dart' as _i57prwgh;
import 'dto/story_person_dto.dart' as _ipq9eknh;
import 'dto/story_search_dto.dart' as _i93osgfq;
import 'dto/story_write_dto.dart' as _i70jvi55;
import 'dto/tree_family_dto.dart' as _i91d5kcr;
import 'family.dart' as _igf5ho4a;
import 'kinship.dart' as _itzlol5n;
import 'kinship_kind.dart' as _iq59nsdl;
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
export 'dto/cover_upload_ticket_dto.dart';
export 'dto/created_invite_dto.dart';
export 'dto/decade_facet_dto.dart';
export 'dto/family_detail_dto.dart';
export 'dto/family_directory_dto.dart';
export 'dto/family_member_dto.dart';
export 'dto/family_roster_dto.dart';
export 'dto/invite_preview_dto.dart';
export 'dto/kinship_dto.dart';
export 'dto/live_event_dto.dart';
export 'dto/live_kind.dart';
export 'dto/member_family_dto.dart';
export 'dto/note_dto.dart';
export 'dto/origin_dependent_dto.dart';
export 'dto/own_profile_dto.dart';
export 'dto/pending_invite_dto.dart';
export 'dto/person_dto.dart';
export 'dto/person_facet_dto.dart';
export 'dto/person_profile_dto.dart';
export 'dto/person_write_dto.dart';
export 'dto/photo_dto.dart';
export 'dto/photo_ref_dto.dart';
export 'dto/photo_upload_ticket_dto.dart';
export 'dto/place_dto.dart';
export 'dto/place_facet_dto.dart';
export 'dto/place_input_dto.dart';
export 'dto/search_sort.dart';
export 'dto/steward_family_dto.dart';
export 'dto/story_dto.dart';
export 'dto/story_facets_dto.dart';
export 'dto/story_person_dto.dart';
export 'dto/story_search_dto.dart';
export 'dto/story_write_dto.dart';
export 'dto/tree_family_dto.dart';
export 'family.dart';
export 'kinship.dart';
export 'kinship_kind.dart';
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
          _isc.getType<_ieh1xhhu.CoverUploadTicketDto>,
          _isc.getType<_i5tlcydc.CreatedInviteDto>,
          _isc.getType<_i3bc4i2z.DecadeFacetDto>,
          _isc.getType<_i454qtto.FamilyDetailDto>,
          _isc.getType<_ibjtxzev.FamilyDirectoryDto>,
          _isc.getType<_i6t2z5gc.FamilyMemberDto>,
          _isc.getType<_ihq257tz.FamilyRosterDto>,
          _isc.getType<_in2wbmsu.InvitePreviewDto>,
          _isc.getType<_ia1fjje5.KinshipDto>,
          _isc.getType<_ipyvbztq.LiveEventDto>,
          _isc.getType<_i67kei86.LiveKind>,
          _isc.getType<_ir8o3gjk.MemberFamilyDto>,
          _isc.getType<_i6e6avtv.NoteDto>,
          _isc.getType<_i9h96nn2.OriginDependentDto>,
          _isc.getType<_is5ywasv.OwnProfileDto>,
          _isc.getType<_i5vdpx0m.PendingInviteDto>,
          _isc.getType<_ig7qj6yo.PersonDto>,
          _isc.getType<_ikbgxdng.PersonFacetDto>,
          _isc.getType<_i38icd77.PersonProfileDto>,
          _isc.getType<_imob66rg.PersonWriteDto>,
          _isc.getType<_i3tneuol.PhotoDto>,
          _isc.getType<_i91pkskm.PhotoRefDto>,
          _isc.getType<_i5l4kjca.PhotoUploadTicketDto>,
          _isc.getType<_ijvrvfy5.PlaceDto>,
          _isc.getType<_ioxclq7u.PlaceFacetDto>,
          _isc.getType<_i85hzch5.PlaceInputDto>,
          _isc.getType<_ikw9cscj.SearchSort>,
          _isc.getType<_imtvyjr9.StewardFamilyDto>,
          _isc.getType<_ipnasz46.StoryDto>,
          _isc.getType<_i57prwgh.StoryFacetsDto>,
          _isc.getType<_ipq9eknh.StoryPersonDto>,
          _isc.getType<_i93osgfq.StorySearchDto>,
          _isc.getType<_i70jvi55.StoryWriteDto>,
          _isc.getType<_i91d5kcr.TreeFamilyDto>,
          _isc.getType<_igf5ho4a.Family>,
          _isc.getType<_itzlol5n.Kinship>,
          _isc.getType<_iq59nsdl.KinshipKind>,
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
          _isc.getType<_ieh1xhhu.CoverUploadTicketDto?>,
          _isc.getType<_i5tlcydc.CreatedInviteDto?>,
          _isc.getType<_i3bc4i2z.DecadeFacetDto?>,
          _isc.getType<_i454qtto.FamilyDetailDto?>,
          _isc.getType<_ibjtxzev.FamilyDirectoryDto?>,
          _isc.getType<_i6t2z5gc.FamilyMemberDto?>,
          _isc.getType<_ihq257tz.FamilyRosterDto?>,
          _isc.getType<_in2wbmsu.InvitePreviewDto?>,
          _isc.getType<_ia1fjje5.KinshipDto?>,
          _isc.getType<_ipyvbztq.LiveEventDto?>,
          _isc.getType<_i67kei86.LiveKind?>,
          _isc.getType<_ir8o3gjk.MemberFamilyDto?>,
          _isc.getType<_i6e6avtv.NoteDto?>,
          _isc.getType<_i9h96nn2.OriginDependentDto?>,
          _isc.getType<_is5ywasv.OwnProfileDto?>,
          _isc.getType<_i5vdpx0m.PendingInviteDto?>,
          _isc.getType<_ig7qj6yo.PersonDto?>,
          _isc.getType<_ikbgxdng.PersonFacetDto?>,
          _isc.getType<_i38icd77.PersonProfileDto?>,
          _isc.getType<_imob66rg.PersonWriteDto?>,
          _isc.getType<_i3tneuol.PhotoDto?>,
          _isc.getType<_i91pkskm.PhotoRefDto?>,
          _isc.getType<_i5l4kjca.PhotoUploadTicketDto?>,
          _isc.getType<_ijvrvfy5.PlaceDto?>,
          _isc.getType<_ioxclq7u.PlaceFacetDto?>,
          _isc.getType<_i85hzch5.PlaceInputDto?>,
          _isc.getType<_ikw9cscj.SearchSort?>,
          _isc.getType<_imtvyjr9.StewardFamilyDto?>,
          _isc.getType<_ipnasz46.StoryDto?>,
          _isc.getType<_i57prwgh.StoryFacetsDto?>,
          _isc.getType<_ipq9eknh.StoryPersonDto?>,
          _isc.getType<_i93osgfq.StorySearchDto?>,
          _isc.getType<_i70jvi55.StoryWriteDto?>,
          _isc.getType<_i91d5kcr.TreeFamilyDto?>,
          _isc.getType<_igf5ho4a.Family?>,
          _isc.getType<_itzlol5n.Kinship?>,
          _isc.getType<_iq59nsdl.KinshipKind?>,
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
          _isc.getType<List<_i6t2z5gc.FamilyMemberDto>>,
          _isc.getType<List<_i5vdpx0m.PendingInviteDto>>,
          _isc.getType<List<_ihq257tz.FamilyRosterDto>>,
          _isc.getType<List<_ipq9eknh.StoryPersonDto>>,
          _isc.getType<List<_i91pkskm.PhotoRefDto>>,
          _isc.getType<List<_i3bc4i2z.DecadeFacetDto>>,
          _isc.getType<List<_ikbgxdng.PersonFacetDto>>,
          _isc.getType<List<_ioxclq7u.PlaceFacetDto>>,
          _isc.getType<List<_isc.UuidValue>>,
          _isc.getType<List<int>>,
          _isc.getType<List<_isc.UuidValue>?>,
          _isc.getType<List<_ii9mmjc2.MemberFamilyDto>>,
          _isc.getType<List<_iy83v9y2.StewardFamilyDto>>,
          _isc.getType<List<_iwn4wr2j.TreeFamilyDto>>,
          _isc.getType<List<_ie59njid.FamilyMemberDto>>,
          _isc.getType<List<_i6upf1dr.OriginDependentDto>>,
          _isc.getType<List<_isc.UuidValue>>,
          _isc.getType<Map<String, _idt.ByteData>>,
          _isc.getType<List<String>>,
          _isc.getType<List<_ippgtqmg.PersonDto>>,
          _isc.getType<List<_ighpoo1p.PhotoDto>>,
          _isc.getType<List<_irx46cwk.PlaceDto>>,
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
          'CoverUploadTicketDto',
          'CreatedInviteDto',
          'DecadeFacetDto',
          'FamilyDetailDto',
          'FamilyDirectoryDto',
          'FamilyMemberDto',
          'FamilyRosterDto',
          'InvitePreviewDto',
          'KinshipDto',
          'LiveEventDto',
          'LiveKind',
          'MemberFamilyDto',
          'NoteDto',
          'OriginDependentDto',
          'OwnProfileDto',
          'PendingInviteDto',
          'PersonDto',
          'PersonFacetDto',
          'PersonProfileDto',
          'PersonWriteDto',
          'PhotoDto',
          'PhotoRefDto',
          'PhotoUploadTicketDto',
          'PlaceDto',
          'PlaceFacetDto',
          'PlaceInputDto',
          'SearchSort',
          'StewardFamilyDto',
          'StoryDto',
          'StoryFacetsDto',
          'StoryPersonDto',
          'StorySearchDto',
          'StoryWriteDto',
          'TreeFamilyDto',
          'Family',
          'Kinship',
          'KinshipKind',
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
    if (t == _ieh1xhhu.CoverUploadTicketDto) {
      return _ieh1xhhu.CoverUploadTicketDto.fromJson(data) as T;
    }
    if (t == _i5tlcydc.CreatedInviteDto) {
      return _i5tlcydc.CreatedInviteDto.fromJson(data) as T;
    }
    if (t == _i3bc4i2z.DecadeFacetDto) {
      return _i3bc4i2z.DecadeFacetDto.fromJson(data) as T;
    }
    if (t == _i454qtto.FamilyDetailDto) {
      return _i454qtto.FamilyDetailDto.fromJson(data) as T;
    }
    if (t == _ibjtxzev.FamilyDirectoryDto) {
      return _ibjtxzev.FamilyDirectoryDto.fromJson(data) as T;
    }
    if (t == _i6t2z5gc.FamilyMemberDto) {
      return _i6t2z5gc.FamilyMemberDto.fromJson(data) as T;
    }
    if (t == _ihq257tz.FamilyRosterDto) {
      return _ihq257tz.FamilyRosterDto.fromJson(data) as T;
    }
    if (t == _in2wbmsu.InvitePreviewDto) {
      return _in2wbmsu.InvitePreviewDto.fromJson(data) as T;
    }
    if (t == _ia1fjje5.KinshipDto) {
      return _ia1fjje5.KinshipDto.fromJson(data) as T;
    }
    if (t == _ipyvbztq.LiveEventDto) {
      return _ipyvbztq.LiveEventDto.fromJson(data) as T;
    }
    if (t == _i67kei86.LiveKind) {
      return _i67kei86.LiveKind.fromJson(data) as T;
    }
    if (t == _ir8o3gjk.MemberFamilyDto) {
      return _ir8o3gjk.MemberFamilyDto.fromJson(data) as T;
    }
    if (t == _i6e6avtv.NoteDto) {
      return _i6e6avtv.NoteDto.fromJson(data) as T;
    }
    if (t == _i9h96nn2.OriginDependentDto) {
      return _i9h96nn2.OriginDependentDto.fromJson(data) as T;
    }
    if (t == _is5ywasv.OwnProfileDto) {
      return _is5ywasv.OwnProfileDto.fromJson(data) as T;
    }
    if (t == _i5vdpx0m.PendingInviteDto) {
      return _i5vdpx0m.PendingInviteDto.fromJson(data) as T;
    }
    if (t == _ig7qj6yo.PersonDto) {
      return _ig7qj6yo.PersonDto.fromJson(data) as T;
    }
    if (t == _ikbgxdng.PersonFacetDto) {
      return _ikbgxdng.PersonFacetDto.fromJson(data) as T;
    }
    if (t == _i38icd77.PersonProfileDto) {
      return _i38icd77.PersonProfileDto.fromJson(data) as T;
    }
    if (t == _imob66rg.PersonWriteDto) {
      return _imob66rg.PersonWriteDto.fromJson(data) as T;
    }
    if (t == _i3tneuol.PhotoDto) {
      return _i3tneuol.PhotoDto.fromJson(data) as T;
    }
    if (t == _i91pkskm.PhotoRefDto) {
      return _i91pkskm.PhotoRefDto.fromJson(data) as T;
    }
    if (t == _i5l4kjca.PhotoUploadTicketDto) {
      return _i5l4kjca.PhotoUploadTicketDto.fromJson(data) as T;
    }
    if (t == _ijvrvfy5.PlaceDto) {
      return _ijvrvfy5.PlaceDto.fromJson(data) as T;
    }
    if (t == _ioxclq7u.PlaceFacetDto) {
      return _ioxclq7u.PlaceFacetDto.fromJson(data) as T;
    }
    if (t == _i85hzch5.PlaceInputDto) {
      return _i85hzch5.PlaceInputDto.fromJson(data) as T;
    }
    if (t == _ikw9cscj.SearchSort) {
      return _ikw9cscj.SearchSort.fromJson(data) as T;
    }
    if (t == _imtvyjr9.StewardFamilyDto) {
      return _imtvyjr9.StewardFamilyDto.fromJson(data) as T;
    }
    if (t == _ipnasz46.StoryDto) {
      return _ipnasz46.StoryDto.fromJson(data) as T;
    }
    if (t == _i57prwgh.StoryFacetsDto) {
      return _i57prwgh.StoryFacetsDto.fromJson(data) as T;
    }
    if (t == _ipq9eknh.StoryPersonDto) {
      return _ipq9eknh.StoryPersonDto.fromJson(data) as T;
    }
    if (t == _i93osgfq.StorySearchDto) {
      return _i93osgfq.StorySearchDto.fromJson(data) as T;
    }
    if (t == _i70jvi55.StoryWriteDto) {
      return _i70jvi55.StoryWriteDto.fromJson(data) as T;
    }
    if (t == _i91d5kcr.TreeFamilyDto) {
      return _i91d5kcr.TreeFamilyDto.fromJson(data) as T;
    }
    if (t == _igf5ho4a.Family) {
      return _igf5ho4a.Family.fromJson(data) as T;
    }
    if (t == _itzlol5n.Kinship) {
      return _itzlol5n.Kinship.fromJson(data) as T;
    }
    if (t == _iq59nsdl.KinshipKind) {
      return _iq59nsdl.KinshipKind.fromJson(data) as T;
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
    if (t == _isc.getType<_ieh1xhhu.CoverUploadTicketDto?>()) {
      return (data != null
              ? _ieh1xhhu.CoverUploadTicketDto.fromJson(data)
              : null)
          as T;
    }
    if (t == _isc.getType<_i5tlcydc.CreatedInviteDto?>()) {
      return (data != null ? _i5tlcydc.CreatedInviteDto.fromJson(data) : null)
          as T;
    }
    if (t == _isc.getType<_i3bc4i2z.DecadeFacetDto?>()) {
      return (data != null ? _i3bc4i2z.DecadeFacetDto.fromJson(data) : null)
          as T;
    }
    if (t == _isc.getType<_i454qtto.FamilyDetailDto?>()) {
      return (data != null ? _i454qtto.FamilyDetailDto.fromJson(data) : null)
          as T;
    }
    if (t == _isc.getType<_ibjtxzev.FamilyDirectoryDto?>()) {
      return (data != null ? _ibjtxzev.FamilyDirectoryDto.fromJson(data) : null)
          as T;
    }
    if (t == _isc.getType<_i6t2z5gc.FamilyMemberDto?>()) {
      return (data != null ? _i6t2z5gc.FamilyMemberDto.fromJson(data) : null)
          as T;
    }
    if (t == _isc.getType<_ihq257tz.FamilyRosterDto?>()) {
      return (data != null ? _ihq257tz.FamilyRosterDto.fromJson(data) : null)
          as T;
    }
    if (t == _isc.getType<_in2wbmsu.InvitePreviewDto?>()) {
      return (data != null ? _in2wbmsu.InvitePreviewDto.fromJson(data) : null)
          as T;
    }
    if (t == _isc.getType<_ia1fjje5.KinshipDto?>()) {
      return (data != null ? _ia1fjje5.KinshipDto.fromJson(data) : null) as T;
    }
    if (t == _isc.getType<_ipyvbztq.LiveEventDto?>()) {
      return (data != null ? _ipyvbztq.LiveEventDto.fromJson(data) : null) as T;
    }
    if (t == _isc.getType<_i67kei86.LiveKind?>()) {
      return (data != null ? _i67kei86.LiveKind.fromJson(data) : null) as T;
    }
    if (t == _isc.getType<_ir8o3gjk.MemberFamilyDto?>()) {
      return (data != null ? _ir8o3gjk.MemberFamilyDto.fromJson(data) : null)
          as T;
    }
    if (t == _isc.getType<_i6e6avtv.NoteDto?>()) {
      return (data != null ? _i6e6avtv.NoteDto.fromJson(data) : null) as T;
    }
    if (t == _isc.getType<_i9h96nn2.OriginDependentDto?>()) {
      return (data != null ? _i9h96nn2.OriginDependentDto.fromJson(data) : null)
          as T;
    }
    if (t == _isc.getType<_is5ywasv.OwnProfileDto?>()) {
      return (data != null ? _is5ywasv.OwnProfileDto.fromJson(data) : null)
          as T;
    }
    if (t == _isc.getType<_i5vdpx0m.PendingInviteDto?>()) {
      return (data != null ? _i5vdpx0m.PendingInviteDto.fromJson(data) : null)
          as T;
    }
    if (t == _isc.getType<_ig7qj6yo.PersonDto?>()) {
      return (data != null ? _ig7qj6yo.PersonDto.fromJson(data) : null) as T;
    }
    if (t == _isc.getType<_ikbgxdng.PersonFacetDto?>()) {
      return (data != null ? _ikbgxdng.PersonFacetDto.fromJson(data) : null)
          as T;
    }
    if (t == _isc.getType<_i38icd77.PersonProfileDto?>()) {
      return (data != null ? _i38icd77.PersonProfileDto.fromJson(data) : null)
          as T;
    }
    if (t == _isc.getType<_imob66rg.PersonWriteDto?>()) {
      return (data != null ? _imob66rg.PersonWriteDto.fromJson(data) : null)
          as T;
    }
    if (t == _isc.getType<_i3tneuol.PhotoDto?>()) {
      return (data != null ? _i3tneuol.PhotoDto.fromJson(data) : null) as T;
    }
    if (t == _isc.getType<_i91pkskm.PhotoRefDto?>()) {
      return (data != null ? _i91pkskm.PhotoRefDto.fromJson(data) : null) as T;
    }
    if (t == _isc.getType<_i5l4kjca.PhotoUploadTicketDto?>()) {
      return (data != null
              ? _i5l4kjca.PhotoUploadTicketDto.fromJson(data)
              : null)
          as T;
    }
    if (t == _isc.getType<_ijvrvfy5.PlaceDto?>()) {
      return (data != null ? _ijvrvfy5.PlaceDto.fromJson(data) : null) as T;
    }
    if (t == _isc.getType<_ioxclq7u.PlaceFacetDto?>()) {
      return (data != null ? _ioxclq7u.PlaceFacetDto.fromJson(data) : null)
          as T;
    }
    if (t == _isc.getType<_i85hzch5.PlaceInputDto?>()) {
      return (data != null ? _i85hzch5.PlaceInputDto.fromJson(data) : null)
          as T;
    }
    if (t == _isc.getType<_ikw9cscj.SearchSort?>()) {
      return (data != null ? _ikw9cscj.SearchSort.fromJson(data) : null) as T;
    }
    if (t == _isc.getType<_imtvyjr9.StewardFamilyDto?>()) {
      return (data != null ? _imtvyjr9.StewardFamilyDto.fromJson(data) : null)
          as T;
    }
    if (t == _isc.getType<_ipnasz46.StoryDto?>()) {
      return (data != null ? _ipnasz46.StoryDto.fromJson(data) : null) as T;
    }
    if (t == _isc.getType<_i57prwgh.StoryFacetsDto?>()) {
      return (data != null ? _i57prwgh.StoryFacetsDto.fromJson(data) : null)
          as T;
    }
    if (t == _isc.getType<_ipq9eknh.StoryPersonDto?>()) {
      return (data != null ? _ipq9eknh.StoryPersonDto.fromJson(data) : null)
          as T;
    }
    if (t == _isc.getType<_i93osgfq.StorySearchDto?>()) {
      return (data != null ? _i93osgfq.StorySearchDto.fromJson(data) : null)
          as T;
    }
    if (t == _isc.getType<_i70jvi55.StoryWriteDto?>()) {
      return (data != null ? _i70jvi55.StoryWriteDto.fromJson(data) : null)
          as T;
    }
    if (t == _isc.getType<_i91d5kcr.TreeFamilyDto?>()) {
      return (data != null ? _i91d5kcr.TreeFamilyDto.fromJson(data) : null)
          as T;
    }
    if (t == _isc.getType<_igf5ho4a.Family?>()) {
      return (data != null ? _igf5ho4a.Family.fromJson(data) : null) as T;
    }
    if (t == _isc.getType<_itzlol5n.Kinship?>()) {
      return (data != null ? _itzlol5n.Kinship.fromJson(data) : null) as T;
    }
    if (t == _isc.getType<_iq59nsdl.KinshipKind?>()) {
      return (data != null ? _iq59nsdl.KinshipKind.fromJson(data) : null) as T;
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
    if (t == List<_i6t2z5gc.FamilyMemberDto>) {
      return (data as List)
              .map((e) => deserialize<_i6t2z5gc.FamilyMemberDto>(e))
              .toList()
          as T;
    }
    if (t == List<_i5vdpx0m.PendingInviteDto>) {
      return (data as List)
              .map((e) => deserialize<_i5vdpx0m.PendingInviteDto>(e))
              .toList()
          as T;
    }
    if (t == List<_ihq257tz.FamilyRosterDto>) {
      return (data as List)
              .map((e) => deserialize<_ihq257tz.FamilyRosterDto>(e))
              .toList()
          as T;
    }
    if (t == List<_ipq9eknh.StoryPersonDto>) {
      return (data as List)
              .map((e) => deserialize<_ipq9eknh.StoryPersonDto>(e))
              .toList()
          as T;
    }
    if (t == List<_i91pkskm.PhotoRefDto>) {
      return (data as List)
              .map((e) => deserialize<_i91pkskm.PhotoRefDto>(e))
              .toList()
          as T;
    }
    if (t == List<_i3bc4i2z.DecadeFacetDto>) {
      return (data as List)
              .map((e) => deserialize<_i3bc4i2z.DecadeFacetDto>(e))
              .toList()
          as T;
    }
    if (t == List<_ikbgxdng.PersonFacetDto>) {
      return (data as List)
              .map((e) => deserialize<_ikbgxdng.PersonFacetDto>(e))
              .toList()
          as T;
    }
    if (t == List<_ioxclq7u.PlaceFacetDto>) {
      return (data as List)
              .map((e) => deserialize<_ioxclq7u.PlaceFacetDto>(e))
              .toList()
          as T;
    }
    if (t == List<_isc.UuidValue>) {
      return (data as List).map((e) => deserialize<_isc.UuidValue>(e)).toList()
          as T;
    }
    if (t == List<int>) {
      return (data as List).map((e) => deserialize<int>(e)).toList() as T;
    }
    if (t == _isc.getType<List<_isc.UuidValue>?>()) {
      return (data != null
              ? (data as List)
                    .map((e) => deserialize<_isc.UuidValue>(e))
                    .toList()
              : null)
          as T;
    }
    if (t == List<_ii9mmjc2.MemberFamilyDto>) {
      return (data as List)
              .map((e) => deserialize<_ii9mmjc2.MemberFamilyDto>(e))
              .toList()
          as T;
    }
    if (t == List<_iy83v9y2.StewardFamilyDto>) {
      return (data as List)
              .map((e) => deserialize<_iy83v9y2.StewardFamilyDto>(e))
              .toList()
          as T;
    }
    if (t == List<_iwn4wr2j.TreeFamilyDto>) {
      return (data as List)
              .map((e) => deserialize<_iwn4wr2j.TreeFamilyDto>(e))
              .toList()
          as T;
    }
    if (t == List<_ie59njid.FamilyMemberDto>) {
      return (data as List)
              .map((e) => deserialize<_ie59njid.FamilyMemberDto>(e))
              .toList()
          as T;
    }
    if (t == List<_i6upf1dr.OriginDependentDto>) {
      return (data as List)
              .map((e) => deserialize<_i6upf1dr.OriginDependentDto>(e))
              .toList()
          as T;
    }
    if (t == List<_isc.UuidValue>) {
      return (data as List).map((e) => deserialize<_isc.UuidValue>(e)).toList()
          as T;
    }
    if (t == Map<String, _idt.ByteData>) {
      return (data as Map).map(
            (k, v) =>
                MapEntry(deserialize<String>(k), deserialize<_idt.ByteData>(v)),
          )
          as T;
    }
    if (t == List<String>) {
      return (data as List).map((e) => deserialize<String>(e)).toList() as T;
    }
    if (t == List<_ippgtqmg.PersonDto>) {
      return (data as List)
              .map((e) => deserialize<_ippgtqmg.PersonDto>(e))
              .toList()
          as T;
    }
    if (t == List<_ighpoo1p.PhotoDto>) {
      return (data as List)
              .map((e) => deserialize<_ighpoo1p.PhotoDto>(e))
              .toList()
          as T;
    }
    if (t == List<_irx46cwk.PlaceDto>) {
      return (data as List)
              .map((e) => deserialize<_irx46cwk.PlaceDto>(e))
              .toList()
          as T;
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
      _ieh1xhhu.CoverUploadTicketDto => 'CoverUploadTicketDto',
      _i5tlcydc.CreatedInviteDto => 'CreatedInviteDto',
      _i3bc4i2z.DecadeFacetDto => 'DecadeFacetDto',
      _i454qtto.FamilyDetailDto => 'FamilyDetailDto',
      _ibjtxzev.FamilyDirectoryDto => 'FamilyDirectoryDto',
      _i6t2z5gc.FamilyMemberDto => 'FamilyMemberDto',
      _ihq257tz.FamilyRosterDto => 'FamilyRosterDto',
      _in2wbmsu.InvitePreviewDto => 'InvitePreviewDto',
      _ia1fjje5.KinshipDto => 'KinshipDto',
      _ipyvbztq.LiveEventDto => 'LiveEventDto',
      _i67kei86.LiveKind => 'LiveKind',
      _ir8o3gjk.MemberFamilyDto => 'MemberFamilyDto',
      _i6e6avtv.NoteDto => 'NoteDto',
      _i9h96nn2.OriginDependentDto => 'OriginDependentDto',
      _is5ywasv.OwnProfileDto => 'OwnProfileDto',
      _i5vdpx0m.PendingInviteDto => 'PendingInviteDto',
      _ig7qj6yo.PersonDto => 'PersonDto',
      _ikbgxdng.PersonFacetDto => 'PersonFacetDto',
      _i38icd77.PersonProfileDto => 'PersonProfileDto',
      _imob66rg.PersonWriteDto => 'PersonWriteDto',
      _i3tneuol.PhotoDto => 'PhotoDto',
      _i91pkskm.PhotoRefDto => 'PhotoRefDto',
      _i5l4kjca.PhotoUploadTicketDto => 'PhotoUploadTicketDto',
      _ijvrvfy5.PlaceDto => 'PlaceDto',
      _ioxclq7u.PlaceFacetDto => 'PlaceFacetDto',
      _i85hzch5.PlaceInputDto => 'PlaceInputDto',
      _ikw9cscj.SearchSort => 'SearchSort',
      _imtvyjr9.StewardFamilyDto => 'StewardFamilyDto',
      _ipnasz46.StoryDto => 'StoryDto',
      _i57prwgh.StoryFacetsDto => 'StoryFacetsDto',
      _ipq9eknh.StoryPersonDto => 'StoryPersonDto',
      _i93osgfq.StorySearchDto => 'StorySearchDto',
      _i70jvi55.StoryWriteDto => 'StoryWriteDto',
      _i91d5kcr.TreeFamilyDto => 'TreeFamilyDto',
      _igf5ho4a.Family => 'Family',
      _itzlol5n.Kinship => 'Kinship',
      _iq59nsdl.KinshipKind => 'KinshipKind',
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
      case _ieh1xhhu.CoverUploadTicketDto():
        return 'CoverUploadTicketDto';
      case _i5tlcydc.CreatedInviteDto():
        return 'CreatedInviteDto';
      case _i3bc4i2z.DecadeFacetDto():
        return 'DecadeFacetDto';
      case _i454qtto.FamilyDetailDto():
        return 'FamilyDetailDto';
      case _ibjtxzev.FamilyDirectoryDto():
        return 'FamilyDirectoryDto';
      case _i6t2z5gc.FamilyMemberDto():
        return 'FamilyMemberDto';
      case _ihq257tz.FamilyRosterDto():
        return 'FamilyRosterDto';
      case _in2wbmsu.InvitePreviewDto():
        return 'InvitePreviewDto';
      case _ia1fjje5.KinshipDto():
        return 'KinshipDto';
      case _ipyvbztq.LiveEventDto():
        return 'LiveEventDto';
      case _i67kei86.LiveKind():
        return 'LiveKind';
      case _ir8o3gjk.MemberFamilyDto():
        return 'MemberFamilyDto';
      case _i6e6avtv.NoteDto():
        return 'NoteDto';
      case _i9h96nn2.OriginDependentDto():
        return 'OriginDependentDto';
      case _is5ywasv.OwnProfileDto():
        return 'OwnProfileDto';
      case _i5vdpx0m.PendingInviteDto():
        return 'PendingInviteDto';
      case _ig7qj6yo.PersonDto():
        return 'PersonDto';
      case _ikbgxdng.PersonFacetDto():
        return 'PersonFacetDto';
      case _i38icd77.PersonProfileDto():
        return 'PersonProfileDto';
      case _imob66rg.PersonWriteDto():
        return 'PersonWriteDto';
      case _i3tneuol.PhotoDto():
        return 'PhotoDto';
      case _i91pkskm.PhotoRefDto():
        return 'PhotoRefDto';
      case _i5l4kjca.PhotoUploadTicketDto():
        return 'PhotoUploadTicketDto';
      case _ijvrvfy5.PlaceDto():
        return 'PlaceDto';
      case _ioxclq7u.PlaceFacetDto():
        return 'PlaceFacetDto';
      case _i85hzch5.PlaceInputDto():
        return 'PlaceInputDto';
      case _ikw9cscj.SearchSort():
        return 'SearchSort';
      case _imtvyjr9.StewardFamilyDto():
        return 'StewardFamilyDto';
      case _ipnasz46.StoryDto():
        return 'StoryDto';
      case _i57prwgh.StoryFacetsDto():
        return 'StoryFacetsDto';
      case _ipq9eknh.StoryPersonDto():
        return 'StoryPersonDto';
      case _i93osgfq.StorySearchDto():
        return 'StorySearchDto';
      case _i70jvi55.StoryWriteDto():
        return 'StoryWriteDto';
      case _i91d5kcr.TreeFamilyDto():
        return 'TreeFamilyDto';
      case _igf5ho4a.Family():
        return 'Family';
      case _itzlol5n.Kinship():
        return 'Kinship';
      case _iq59nsdl.KinshipKind():
        return 'KinshipKind';
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
    if (dataClassName == 'CoverUploadTicketDto') {
      return deserialize<_ieh1xhhu.CoverUploadTicketDto>(data['data']);
    }
    if (dataClassName == 'CreatedInviteDto') {
      return deserialize<_i5tlcydc.CreatedInviteDto>(data['data']);
    }
    if (dataClassName == 'DecadeFacetDto') {
      return deserialize<_i3bc4i2z.DecadeFacetDto>(data['data']);
    }
    if (dataClassName == 'FamilyDetailDto') {
      return deserialize<_i454qtto.FamilyDetailDto>(data['data']);
    }
    if (dataClassName == 'FamilyDirectoryDto') {
      return deserialize<_ibjtxzev.FamilyDirectoryDto>(data['data']);
    }
    if (dataClassName == 'FamilyMemberDto') {
      return deserialize<_i6t2z5gc.FamilyMemberDto>(data['data']);
    }
    if (dataClassName == 'FamilyRosterDto') {
      return deserialize<_ihq257tz.FamilyRosterDto>(data['data']);
    }
    if (dataClassName == 'InvitePreviewDto') {
      return deserialize<_in2wbmsu.InvitePreviewDto>(data['data']);
    }
    if (dataClassName == 'KinshipDto') {
      return deserialize<_ia1fjje5.KinshipDto>(data['data']);
    }
    if (dataClassName == 'LiveEventDto') {
      return deserialize<_ipyvbztq.LiveEventDto>(data['data']);
    }
    if (dataClassName == 'LiveKind') {
      return deserialize<_i67kei86.LiveKind>(data['data']);
    }
    if (dataClassName == 'MemberFamilyDto') {
      return deserialize<_ir8o3gjk.MemberFamilyDto>(data['data']);
    }
    if (dataClassName == 'NoteDto') {
      return deserialize<_i6e6avtv.NoteDto>(data['data']);
    }
    if (dataClassName == 'OriginDependentDto') {
      return deserialize<_i9h96nn2.OriginDependentDto>(data['data']);
    }
    if (dataClassName == 'OwnProfileDto') {
      return deserialize<_is5ywasv.OwnProfileDto>(data['data']);
    }
    if (dataClassName == 'PendingInviteDto') {
      return deserialize<_i5vdpx0m.PendingInviteDto>(data['data']);
    }
    if (dataClassName == 'PersonDto') {
      return deserialize<_ig7qj6yo.PersonDto>(data['data']);
    }
    if (dataClassName == 'PersonFacetDto') {
      return deserialize<_ikbgxdng.PersonFacetDto>(data['data']);
    }
    if (dataClassName == 'PersonProfileDto') {
      return deserialize<_i38icd77.PersonProfileDto>(data['data']);
    }
    if (dataClassName == 'PersonWriteDto') {
      return deserialize<_imob66rg.PersonWriteDto>(data['data']);
    }
    if (dataClassName == 'PhotoDto') {
      return deserialize<_i3tneuol.PhotoDto>(data['data']);
    }
    if (dataClassName == 'PhotoRefDto') {
      return deserialize<_i91pkskm.PhotoRefDto>(data['data']);
    }
    if (dataClassName == 'PhotoUploadTicketDto') {
      return deserialize<_i5l4kjca.PhotoUploadTicketDto>(data['data']);
    }
    if (dataClassName == 'PlaceDto') {
      return deserialize<_ijvrvfy5.PlaceDto>(data['data']);
    }
    if (dataClassName == 'PlaceFacetDto') {
      return deserialize<_ioxclq7u.PlaceFacetDto>(data['data']);
    }
    if (dataClassName == 'PlaceInputDto') {
      return deserialize<_i85hzch5.PlaceInputDto>(data['data']);
    }
    if (dataClassName == 'SearchSort') {
      return deserialize<_ikw9cscj.SearchSort>(data['data']);
    }
    if (dataClassName == 'StewardFamilyDto') {
      return deserialize<_imtvyjr9.StewardFamilyDto>(data['data']);
    }
    if (dataClassName == 'StoryDto') {
      return deserialize<_ipnasz46.StoryDto>(data['data']);
    }
    if (dataClassName == 'StoryFacetsDto') {
      return deserialize<_i57prwgh.StoryFacetsDto>(data['data']);
    }
    if (dataClassName == 'StoryPersonDto') {
      return deserialize<_ipq9eknh.StoryPersonDto>(data['data']);
    }
    if (dataClassName == 'StorySearchDto') {
      return deserialize<_i93osgfq.StorySearchDto>(data['data']);
    }
    if (dataClassName == 'StoryWriteDto') {
      return deserialize<_i70jvi55.StoryWriteDto>(data['data']);
    }
    if (dataClassName == 'TreeFamilyDto') {
      return deserialize<_i91d5kcr.TreeFamilyDto>(data['data']);
    }
    if (dataClassName == 'Family') {
      return deserialize<_igf5ho4a.Family>(data['data']);
    }
    if (dataClassName == 'Kinship') {
      return deserialize<_itzlol5n.Kinship>(data['data']);
    }
    if (dataClassName == 'KinshipKind') {
      return deserialize<_iq59nsdl.KinshipKind>(data['data']);
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
