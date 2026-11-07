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
import 'package:serverpod/protocol.dart' as _isp;
import 'package:serverpod/serverpod.dart' as _is;
import 'package:serverpod_auth_core_server/serverpod_auth_core_server.dart'
    as _iacs;
import 'package:serverpod_auth_idp_server/serverpod_auth_idp_server.dart'
    as _iais;
import 'package:tell_me_a_story_server/src/generated/dto/place_dto.dart'
    as _i3xh6672;
import 'app_error_code.dart' as _imu8gbx5;
import 'app_exception.dart' as _it4z223c;
import 'app_user.dart' as _i2j2xfrn;
import 'birth_visibility.dart' as _i2x3tia5;
import 'blob_deletion.dart' as _ig8q6jh0;
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
import 'invite.dart' as _ibtb2p99;
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
export 'blob_deletion.dart';
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
export 'invite.dart';
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

class Protocol extends _is.DatabaseSerializationManager
    implements _is.DatabaseProtocolDeserializationProvider {
  Protocol._();

  factory Protocol() => _instance;

  static final Protocol _instance = Protocol._().._registerHostProtocols();

  @override
  _is.ProtocolDeserialization get deserializationMetadata =>
      _is.ProtocolDeserialization.cached(
        this,
        types: const [
          _is.getType<_imu8gbx5.AppErrorCode>,
          _is.getType<_it4z223c.AppException>,
          _is.getType<_i2j2xfrn.AppUser>,
          _is.getType<_i2x3tia5.BirthVisibility>,
          _is.getType<_ig8q6jh0.BlobDeletion>,
          _is.getType<_ilvyd2nu.DatePrecision>,
          _is.getType<_ieh1xhhu.CoverUploadTicketDto>,
          _is.getType<_i5tlcydc.CreatedInviteDto>,
          _is.getType<_i3bc4i2z.DecadeFacetDto>,
          _is.getType<_i454qtto.FamilyDetailDto>,
          _is.getType<_ibjtxzev.FamilyDirectoryDto>,
          _is.getType<_i6t2z5gc.FamilyMemberDto>,
          _is.getType<_ihq257tz.FamilyRosterDto>,
          _is.getType<_in2wbmsu.InvitePreviewDto>,
          _is.getType<_ia1fjje5.KinshipDto>,
          _is.getType<_ipyvbztq.LiveEventDto>,
          _is.getType<_i67kei86.LiveKind>,
          _is.getType<_ir8o3gjk.MemberFamilyDto>,
          _is.getType<_i6e6avtv.NoteDto>,
          _is.getType<_i9h96nn2.OriginDependentDto>,
          _is.getType<_is5ywasv.OwnProfileDto>,
          _is.getType<_i5vdpx0m.PendingInviteDto>,
          _is.getType<_ig7qj6yo.PersonDto>,
          _is.getType<_ikbgxdng.PersonFacetDto>,
          _is.getType<_i38icd77.PersonProfileDto>,
          _is.getType<_imob66rg.PersonWriteDto>,
          _is.getType<_i3tneuol.PhotoDto>,
          _is.getType<_i91pkskm.PhotoRefDto>,
          _is.getType<_i5l4kjca.PhotoUploadTicketDto>,
          _is.getType<_ijvrvfy5.PlaceDto>,
          _is.getType<_ioxclq7u.PlaceFacetDto>,
          _is.getType<_i85hzch5.PlaceInputDto>,
          _is.getType<_ikw9cscj.SearchSort>,
          _is.getType<_imtvyjr9.StewardFamilyDto>,
          _is.getType<_ipnasz46.StoryDto>,
          _is.getType<_i57prwgh.StoryFacetsDto>,
          _is.getType<_ipq9eknh.StoryPersonDto>,
          _is.getType<_i93osgfq.StorySearchDto>,
          _is.getType<_i70jvi55.StoryWriteDto>,
          _is.getType<_i91d5kcr.TreeFamilyDto>,
          _is.getType<_igf5ho4a.Family>,
          _is.getType<_ibtb2p99.Invite>,
          _is.getType<_itzlol5n.Kinship>,
          _is.getType<_iq59nsdl.KinshipKind>,
          _is.getType<_iu35fd1a.Membership>,
          _is.getType<_iur1rrwm.MembershipRole>,
          _is.getType<_ixhn57mr.NoteKind>,
          _is.getType<_iensfz4m.Person>,
          _is.getType<_ii8pt9rm.Photo>,
          _is.getType<_isaqapjx.Place>,
          _is.getType<_ixuwv6na.Story>,
          _is.getType<_iugi3tvg.StoryNote>,
          _is.getType<_i0053fvj.StoryPerson>,
          _is.getType<_ixc1exsr.StoryStatus>,
          _is.getType<_i5e6tmks.Tree>,
          _is.getType<_imu8gbx5.AppErrorCode?>,
          _is.getType<_it4z223c.AppException?>,
          _is.getType<_i2j2xfrn.AppUser?>,
          _is.getType<_i2x3tia5.BirthVisibility?>,
          _is.getType<_ig8q6jh0.BlobDeletion?>,
          _is.getType<_ilvyd2nu.DatePrecision?>,
          _is.getType<_ieh1xhhu.CoverUploadTicketDto?>,
          _is.getType<_i5tlcydc.CreatedInviteDto?>,
          _is.getType<_i3bc4i2z.DecadeFacetDto?>,
          _is.getType<_i454qtto.FamilyDetailDto?>,
          _is.getType<_ibjtxzev.FamilyDirectoryDto?>,
          _is.getType<_i6t2z5gc.FamilyMemberDto?>,
          _is.getType<_ihq257tz.FamilyRosterDto?>,
          _is.getType<_in2wbmsu.InvitePreviewDto?>,
          _is.getType<_ia1fjje5.KinshipDto?>,
          _is.getType<_ipyvbztq.LiveEventDto?>,
          _is.getType<_i67kei86.LiveKind?>,
          _is.getType<_ir8o3gjk.MemberFamilyDto?>,
          _is.getType<_i6e6avtv.NoteDto?>,
          _is.getType<_i9h96nn2.OriginDependentDto?>,
          _is.getType<_is5ywasv.OwnProfileDto?>,
          _is.getType<_i5vdpx0m.PendingInviteDto?>,
          _is.getType<_ig7qj6yo.PersonDto?>,
          _is.getType<_ikbgxdng.PersonFacetDto?>,
          _is.getType<_i38icd77.PersonProfileDto?>,
          _is.getType<_imob66rg.PersonWriteDto?>,
          _is.getType<_i3tneuol.PhotoDto?>,
          _is.getType<_i91pkskm.PhotoRefDto?>,
          _is.getType<_i5l4kjca.PhotoUploadTicketDto?>,
          _is.getType<_ijvrvfy5.PlaceDto?>,
          _is.getType<_ioxclq7u.PlaceFacetDto?>,
          _is.getType<_i85hzch5.PlaceInputDto?>,
          _is.getType<_ikw9cscj.SearchSort?>,
          _is.getType<_imtvyjr9.StewardFamilyDto?>,
          _is.getType<_ipnasz46.StoryDto?>,
          _is.getType<_i57prwgh.StoryFacetsDto?>,
          _is.getType<_ipq9eknh.StoryPersonDto?>,
          _is.getType<_i93osgfq.StorySearchDto?>,
          _is.getType<_i70jvi55.StoryWriteDto?>,
          _is.getType<_i91d5kcr.TreeFamilyDto?>,
          _is.getType<_igf5ho4a.Family?>,
          _is.getType<_ibtb2p99.Invite?>,
          _is.getType<_itzlol5n.Kinship?>,
          _is.getType<_iq59nsdl.KinshipKind?>,
          _is.getType<_iu35fd1a.Membership?>,
          _is.getType<_iur1rrwm.MembershipRole?>,
          _is.getType<_ixhn57mr.NoteKind?>,
          _is.getType<_iensfz4m.Person?>,
          _is.getType<_ii8pt9rm.Photo?>,
          _is.getType<_isaqapjx.Place?>,
          _is.getType<_ixuwv6na.Story?>,
          _is.getType<_iugi3tvg.StoryNote?>,
          _is.getType<_i0053fvj.StoryPerson?>,
          _is.getType<_ixc1exsr.StoryStatus?>,
          _is.getType<_i5e6tmks.Tree?>,
          _is.getType<List<_i6t2z5gc.FamilyMemberDto>>,
          _is.getType<List<_i5vdpx0m.PendingInviteDto>>,
          _is.getType<List<_ihq257tz.FamilyRosterDto>>,
          _is.getType<List<_ipq9eknh.StoryPersonDto>>,
          _is.getType<List<_i91pkskm.PhotoRefDto>>,
          _is.getType<List<_i3bc4i2z.DecadeFacetDto>>,
          _is.getType<List<_ikbgxdng.PersonFacetDto>>,
          _is.getType<List<_ioxclq7u.PlaceFacetDto>>,
          _is.getType<List<_is.UuidValue>>,
          _is.getType<List<int>>,
          _is.getType<List<_is.UuidValue>?>,
          _is.getType<List<_i3xh6672.PlaceDto>>,
        ],
        modules: const [
          _iais.Protocol.new,
          _iacs.Protocol.new,
          _isp.Protocol.new,
        ],
        classNames: const [
          'AppErrorCode',
          'AppException',
          'AppUser',
          'BirthVisibility',
          'BlobDeletion',
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
          'Invite',
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

  static List<_isp.TableDefinition> get targetTableDefinitions => [
    _isp.TableDefinition(
      name: 'blob_deletions',
      dartName: 'BlobDeletion',
      schema: 'public',
      module: 'tell_me_a_story',
      columns: [
        _isp.ColumnDefinition(
          name: 'id',
          columnType: _isp.ColumnType.uuid,
          isNullable: false,
          dartType: 'UuidValue?',
          columnDefault: 'random_v7',
        ),
        _isp.ColumnDefinition(
          name: 'key',
          columnType: _isp.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _isp.ColumnDefinition(
          name: 'createdAt',
          columnType: _isp.ColumnType.timestampWithoutTimeZone,
          isNullable: false,
          dartType: 'DateTime',
          columnDefault: 'now',
        ),
        _isp.ColumnDefinition(
          name: 'attempts',
          columnType: _isp.ColumnType.bigint,
          isNullable: false,
          dartType: 'int',
          columnDefault: '0',
        ),
      ],
      foreignKeys: [],
      indexes: [
        _isp.IndexDefinition(
          indexName: 'blob_deletions_created_idx',
          tableSpace: null,
          elements: [
            _isp.IndexElementDefinition(
              type: _isp.IndexElementDefinitionType.column,
              definition: 'createdAt',
            ),
          ],
          type: 'btree',
          isUnique: false,
          isPrimary: false,
        ),
      ],
      managed: true,
    ),
    _isp.TableDefinition(
      name: 'families',
      dartName: 'Family',
      schema: 'public',
      module: 'tell_me_a_story',
      columns: [
        _isp.ColumnDefinition(
          name: 'id',
          columnType: _isp.ColumnType.uuid,
          isNullable: false,
          dartType: 'UuidValue?',
          columnDefault: 'random_v7',
        ),
        _isp.ColumnDefinition(
          name: 'treeId',
          columnType: _isp.ColumnType.uuid,
          isNullable: false,
          dartType: 'UuidValue',
        ),
        _isp.ColumnDefinition(
          name: 'parentId',
          columnType: _isp.ColumnType.uuid,
          isNullable: true,
          dartType: 'UuidValue?',
        ),
        _isp.ColumnDefinition(
          name: 'name',
          columnType: _isp.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _isp.ColumnDefinition(
          name: 'branchYear',
          columnType: _isp.ColumnType.bigint,
          isNullable: true,
          dartType: 'int?',
        ),
        _isp.ColumnDefinition(
          name: 'originStoryId',
          columnType: _isp.ColumnType.uuid,
          isNullable: true,
          dartType: 'UuidValue?',
        ),
        _isp.ColumnDefinition(
          name: 'coverKey',
          columnType: _isp.ColumnType.text,
          isNullable: true,
          dartType: 'String?',
        ),
        _isp.ColumnDefinition(
          name: 'createdById',
          columnType: _isp.ColumnType.uuid,
          isNullable: true,
          dartType: 'UuidValue?',
        ),
        _isp.ColumnDefinition(
          name: 'createdAt',
          columnType: _isp.ColumnType.timestampWithoutTimeZone,
          isNullable: false,
          dartType: 'DateTime',
          columnDefault: 'now',
        ),
        _isp.ColumnDefinition(
          name: 'deletedAt',
          columnType: _isp.ColumnType.timestampWithoutTimeZone,
          isNullable: true,
          dartType: 'DateTime?',
        ),
      ],
      foreignKeys: [
        _isp.ForeignKeyDefinition(
          constraintName: 'families_fk_0',
          columns: ['treeId'],
          referenceTable: 'trees',
          referenceTableSchema: 'public',
          referenceColumns: ['id'],
          onUpdate: _isp.ForeignKeyAction.noAction,
          onDelete: _isp.ForeignKeyAction.restrict,
          matchType: null,
        ),
        _isp.ForeignKeyDefinition(
          constraintName: 'families_fk_1',
          columns: ['parentId'],
          referenceTable: 'families',
          referenceTableSchema: 'public',
          referenceColumns: ['id'],
          onUpdate: _isp.ForeignKeyAction.noAction,
          onDelete: _isp.ForeignKeyAction.setNull,
          matchType: null,
        ),
        _isp.ForeignKeyDefinition(
          constraintName: 'families_fk_2',
          columns: ['originStoryId'],
          referenceTable: 'stories',
          referenceTableSchema: 'public',
          referenceColumns: ['id'],
          onUpdate: _isp.ForeignKeyAction.noAction,
          onDelete: _isp.ForeignKeyAction.setNull,
          matchType: null,
        ),
        _isp.ForeignKeyDefinition(
          constraintName: 'families_fk_3',
          columns: ['createdById'],
          referenceTable: 'serverpod_auth_core_user',
          referenceTableSchema: 'public',
          referenceColumns: ['id'],
          onUpdate: _isp.ForeignKeyAction.noAction,
          onDelete: _isp.ForeignKeyAction.setNull,
          matchType: null,
        ),
      ],
      indexes: [
        _isp.IndexDefinition(
          indexName: 'families_tree_idx',
          tableSpace: null,
          elements: [
            _isp.IndexElementDefinition(
              type: _isp.IndexElementDefinitionType.column,
              definition: 'treeId',
            ),
          ],
          type: 'btree',
          isUnique: false,
          isPrimary: false,
        ),
        _isp.IndexDefinition(
          indexName: 'families_id_tree_uidx',
          tableSpace: null,
          elements: [
            _isp.IndexElementDefinition(
              type: _isp.IndexElementDefinitionType.column,
              definition: 'id',
            ),
            _isp.IndexElementDefinition(
              type: _isp.IndexElementDefinitionType.column,
              definition: 'treeId',
            ),
          ],
          type: 'btree',
          isUnique: true,
          isPrimary: false,
        ),
        _isp.IndexDefinition(
          indexName: 'families_parent_idx',
          tableSpace: null,
          elements: [
            _isp.IndexElementDefinition(
              type: _isp.IndexElementDefinitionType.column,
              definition: 'parentId',
            ),
          ],
          type: 'btree',
          isUnique: false,
          isPrimary: false,
        ),
        _isp.IndexDefinition(
          indexName: 'families_origin_story_idx',
          tableSpace: null,
          elements: [
            _isp.IndexElementDefinition(
              type: _isp.IndexElementDefinitionType.column,
              definition: 'originStoryId',
            ),
          ],
          type: 'btree',
          isUnique: false,
          isPrimary: false,
        ),
        _isp.IndexDefinition(
          indexName: 'families_deleted_at_idx',
          tableSpace: null,
          elements: [
            _isp.IndexElementDefinition(
              type: _isp.IndexElementDefinitionType.column,
              definition: 'deletedAt',
            ),
          ],
          type: 'btree',
          isUnique: false,
          isPrimary: false,
        ),
      ],
      managed: true,
    ),
    _isp.TableDefinition(
      name: 'invites',
      dartName: 'Invite',
      schema: 'public',
      module: 'tell_me_a_story',
      columns: [
        _isp.ColumnDefinition(
          name: 'id',
          columnType: _isp.ColumnType.uuid,
          isNullable: false,
          dartType: 'UuidValue?',
          columnDefault: 'random_v7',
        ),
        _isp.ColumnDefinition(
          name: 'familyId',
          columnType: _isp.ColumnType.uuid,
          isNullable: false,
          dartType: 'UuidValue',
        ),
        _isp.ColumnDefinition(
          name: 'treeId',
          columnType: _isp.ColumnType.uuid,
          isNullable: false,
          dartType: 'UuidValue',
        ),
        _isp.ColumnDefinition(
          name: 'personId',
          columnType: _isp.ColumnType.uuid,
          isNullable: true,
          dartType: 'UuidValue?',
        ),
        _isp.ColumnDefinition(
          name: 'email',
          columnType: _isp.ColumnType.text,
          isNullable: true,
          dartType: 'String?',
        ),
        _isp.ColumnDefinition(
          name: 'tokenHash',
          columnType: _isp.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _isp.ColumnDefinition(
          name: 'invitedById',
          columnType: _isp.ColumnType.uuid,
          isNullable: true,
          dartType: 'UuidValue?',
        ),
        _isp.ColumnDefinition(
          name: 'acceptedById',
          columnType: _isp.ColumnType.uuid,
          isNullable: true,
          dartType: 'UuidValue?',
        ),
        _isp.ColumnDefinition(
          name: 'acceptedAt',
          columnType: _isp.ColumnType.timestampWithoutTimeZone,
          isNullable: true,
          dartType: 'DateTime?',
        ),
        _isp.ColumnDefinition(
          name: 'revokedAt',
          columnType: _isp.ColumnType.timestampWithoutTimeZone,
          isNullable: true,
          dartType: 'DateTime?',
        ),
        _isp.ColumnDefinition(
          name: 'lastSentAt',
          columnType: _isp.ColumnType.timestampWithoutTimeZone,
          isNullable: false,
          dartType: 'DateTime',
          columnDefault: 'now',
        ),
        _isp.ColumnDefinition(
          name: 'expiresAt',
          columnType: _isp.ColumnType.timestampWithoutTimeZone,
          isNullable: false,
          dartType: 'DateTime',
        ),
        _isp.ColumnDefinition(
          name: 'createdAt',
          columnType: _isp.ColumnType.timestampWithoutTimeZone,
          isNullable: false,
          dartType: 'DateTime',
          columnDefault: 'now',
        ),
      ],
      foreignKeys: [
        _isp.ForeignKeyDefinition(
          constraintName: 'invites_fk_0',
          columns: ['familyId'],
          referenceTable: 'families',
          referenceTableSchema: 'public',
          referenceColumns: ['id'],
          onUpdate: _isp.ForeignKeyAction.noAction,
          onDelete: _isp.ForeignKeyAction.cascade,
          matchType: null,
        ),
        _isp.ForeignKeyDefinition(
          constraintName: 'invites_fk_1',
          columns: ['personId'],
          referenceTable: 'people',
          referenceTableSchema: 'public',
          referenceColumns: ['id'],
          onUpdate: _isp.ForeignKeyAction.noAction,
          onDelete: _isp.ForeignKeyAction.setNull,
          matchType: null,
        ),
        _isp.ForeignKeyDefinition(
          constraintName: 'invites_fk_2',
          columns: ['invitedById'],
          referenceTable: 'serverpod_auth_core_user',
          referenceTableSchema: 'public',
          referenceColumns: ['id'],
          onUpdate: _isp.ForeignKeyAction.noAction,
          onDelete: _isp.ForeignKeyAction.setNull,
          matchType: null,
        ),
        _isp.ForeignKeyDefinition(
          constraintName: 'invites_fk_3',
          columns: ['acceptedById'],
          referenceTable: 'serverpod_auth_core_user',
          referenceTableSchema: 'public',
          referenceColumns: ['id'],
          onUpdate: _isp.ForeignKeyAction.noAction,
          onDelete: _isp.ForeignKeyAction.setNull,
          matchType: null,
        ),
      ],
      indexes: [
        _isp.IndexDefinition(
          indexName: 'invites_token_hash_uidx',
          tableSpace: null,
          elements: [
            _isp.IndexElementDefinition(
              type: _isp.IndexElementDefinitionType.column,
              definition: 'tokenHash',
            ),
          ],
          type: 'btree',
          isUnique: true,
          isPrimary: false,
        ),
        _isp.IndexDefinition(
          indexName: 'invites_family_created_idx',
          tableSpace: null,
          elements: [
            _isp.IndexElementDefinition(
              type: _isp.IndexElementDefinitionType.column,
              definition: 'familyId',
            ),
            _isp.IndexElementDefinition(
              type: _isp.IndexElementDefinitionType.column,
              definition: 'createdAt',
            ),
          ],
          type: 'btree',
          isUnique: false,
          isPrimary: false,
        ),
        _isp.IndexDefinition(
          indexName: 'invites_person_idx',
          tableSpace: null,
          elements: [
            _isp.IndexElementDefinition(
              type: _isp.IndexElementDefinitionType.column,
              definition: 'personId',
            ),
          ],
          type: 'btree',
          isUnique: false,
          isPrimary: false,
        ),
      ],
      managed: true,
    ),
    _isp.TableDefinition(
      name: 'kinships',
      dartName: 'Kinship',
      schema: 'public',
      module: 'tell_me_a_story',
      columns: [
        _isp.ColumnDefinition(
          name: 'id',
          columnType: _isp.ColumnType.uuid,
          isNullable: false,
          dartType: 'UuidValue?',
          columnDefault: 'random_v7',
        ),
        _isp.ColumnDefinition(
          name: 'treeId',
          columnType: _isp.ColumnType.uuid,
          isNullable: false,
          dartType: 'UuidValue',
        ),
        _isp.ColumnDefinition(
          name: 'kind',
          columnType: _isp.ColumnType.text,
          isNullable: false,
          dartType: 'protocol:KinshipKind',
        ),
        _isp.ColumnDefinition(
          name: 'fromPersonId',
          columnType: _isp.ColumnType.uuid,
          isNullable: false,
          dartType: 'UuidValue',
        ),
        _isp.ColumnDefinition(
          name: 'toPersonId',
          columnType: _isp.ColumnType.uuid,
          isNullable: false,
          dartType: 'UuidValue',
        ),
        _isp.ColumnDefinition(
          name: 'createdById',
          columnType: _isp.ColumnType.uuid,
          isNullable: true,
          dartType: 'UuidValue?',
        ),
        _isp.ColumnDefinition(
          name: 'createdAt',
          columnType: _isp.ColumnType.timestampWithoutTimeZone,
          isNullable: false,
          dartType: 'DateTime',
          columnDefault: 'now',
        ),
      ],
      foreignKeys: [
        _isp.ForeignKeyDefinition(
          constraintName: 'kinships_fk_0',
          columns: ['treeId'],
          referenceTable: 'trees',
          referenceTableSchema: 'public',
          referenceColumns: ['id'],
          onUpdate: _isp.ForeignKeyAction.noAction,
          onDelete: _isp.ForeignKeyAction.cascade,
          matchType: null,
        ),
        _isp.ForeignKeyDefinition(
          constraintName: 'kinships_fk_1',
          columns: ['fromPersonId'],
          referenceTable: 'people',
          referenceTableSchema: 'public',
          referenceColumns: ['id'],
          onUpdate: _isp.ForeignKeyAction.noAction,
          onDelete: _isp.ForeignKeyAction.cascade,
          matchType: null,
        ),
        _isp.ForeignKeyDefinition(
          constraintName: 'kinships_fk_2',
          columns: ['toPersonId'],
          referenceTable: 'people',
          referenceTableSchema: 'public',
          referenceColumns: ['id'],
          onUpdate: _isp.ForeignKeyAction.noAction,
          onDelete: _isp.ForeignKeyAction.cascade,
          matchType: null,
        ),
        _isp.ForeignKeyDefinition(
          constraintName: 'kinships_fk_3',
          columns: ['createdById'],
          referenceTable: 'serverpod_auth_core_user',
          referenceTableSchema: 'public',
          referenceColumns: ['id'],
          onUpdate: _isp.ForeignKeyAction.noAction,
          onDelete: _isp.ForeignKeyAction.setNull,
          matchType: null,
        ),
      ],
      indexes: [
        _isp.IndexDefinition(
          indexName: 'kinships_from_to_kind_uidx',
          tableSpace: null,
          elements: [
            _isp.IndexElementDefinition(
              type: _isp.IndexElementDefinitionType.column,
              definition: 'fromPersonId',
            ),
            _isp.IndexElementDefinition(
              type: _isp.IndexElementDefinitionType.column,
              definition: 'toPersonId',
            ),
            _isp.IndexElementDefinition(
              type: _isp.IndexElementDefinitionType.column,
              definition: 'kind',
            ),
          ],
          type: 'btree',
          isUnique: true,
          isPrimary: false,
        ),
        _isp.IndexDefinition(
          indexName: 'kinships_to_idx',
          tableSpace: null,
          elements: [
            _isp.IndexElementDefinition(
              type: _isp.IndexElementDefinitionType.column,
              definition: 'toPersonId',
            ),
          ],
          type: 'btree',
          isUnique: false,
          isPrimary: false,
        ),
        _isp.IndexDefinition(
          indexName: 'kinships_tree_idx',
          tableSpace: null,
          elements: [
            _isp.IndexElementDefinition(
              type: _isp.IndexElementDefinitionType.column,
              definition: 'treeId',
            ),
          ],
          type: 'btree',
          isUnique: false,
          isPrimary: false,
        ),
      ],
      managed: true,
    ),
    _isp.TableDefinition(
      name: 'memberships',
      dartName: 'Membership',
      schema: 'public',
      module: 'tell_me_a_story',
      columns: [
        _isp.ColumnDefinition(
          name: 'id',
          columnType: _isp.ColumnType.uuid,
          isNullable: false,
          dartType: 'UuidValue?',
          columnDefault: 'random_v7',
        ),
        _isp.ColumnDefinition(
          name: 'familyId',
          columnType: _isp.ColumnType.uuid,
          isNullable: false,
          dartType: 'UuidValue',
        ),
        _isp.ColumnDefinition(
          name: 'userId',
          columnType: _isp.ColumnType.uuid,
          isNullable: false,
          dartType: 'UuidValue',
        ),
        _isp.ColumnDefinition(
          name: 'role',
          columnType: _isp.ColumnType.text,
          isNullable: false,
          dartType: 'protocol:MembershipRole',
          columnDefault: '\'member\'',
        ),
        _isp.ColumnDefinition(
          name: 'createdAt',
          columnType: _isp.ColumnType.timestampWithoutTimeZone,
          isNullable: false,
          dartType: 'DateTime',
          columnDefault: 'now',
        ),
      ],
      foreignKeys: [
        _isp.ForeignKeyDefinition(
          constraintName: 'memberships_fk_0',
          columns: ['familyId'],
          referenceTable: 'families',
          referenceTableSchema: 'public',
          referenceColumns: ['id'],
          onUpdate: _isp.ForeignKeyAction.noAction,
          onDelete: _isp.ForeignKeyAction.cascade,
          matchType: null,
        ),
        _isp.ForeignKeyDefinition(
          constraintName: 'memberships_fk_1',
          columns: ['userId'],
          referenceTable: 'serverpod_auth_core_user',
          referenceTableSchema: 'public',
          referenceColumns: ['id'],
          onUpdate: _isp.ForeignKeyAction.noAction,
          onDelete: _isp.ForeignKeyAction.cascade,
          matchType: null,
        ),
      ],
      indexes: [
        _isp.IndexDefinition(
          indexName: 'memberships_family_user_uidx',
          tableSpace: null,
          elements: [
            _isp.IndexElementDefinition(
              type: _isp.IndexElementDefinitionType.column,
              definition: 'familyId',
            ),
            _isp.IndexElementDefinition(
              type: _isp.IndexElementDefinitionType.column,
              definition: 'userId',
            ),
          ],
          type: 'btree',
          isUnique: true,
          isPrimary: false,
        ),
        _isp.IndexDefinition(
          indexName: 'memberships_user_idx',
          tableSpace: null,
          elements: [
            _isp.IndexElementDefinition(
              type: _isp.IndexElementDefinitionType.column,
              definition: 'userId',
            ),
          ],
          type: 'btree',
          isUnique: false,
          isPrimary: false,
        ),
      ],
      managed: true,
    ),
    _isp.TableDefinition(
      name: 'people',
      dartName: 'Person',
      schema: 'public',
      module: 'tell_me_a_story',
      columns: [
        _isp.ColumnDefinition(
          name: 'id',
          columnType: _isp.ColumnType.uuid,
          isNullable: false,
          dartType: 'UuidValue?',
          columnDefault: 'random_v7',
        ),
        _isp.ColumnDefinition(
          name: 'treeId',
          columnType: _isp.ColumnType.uuid,
          isNullable: false,
          dartType: 'UuidValue',
        ),
        _isp.ColumnDefinition(
          name: 'homeFamilyId',
          columnType: _isp.ColumnType.uuid,
          isNullable: false,
          dartType: 'UuidValue',
        ),
        _isp.ColumnDefinition(
          name: 'userId',
          columnType: _isp.ColumnType.uuid,
          isNullable: true,
          dartType: 'UuidValue?',
        ),
        _isp.ColumnDefinition(
          name: 'name',
          columnType: _isp.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _isp.ColumnDefinition(
          name: 'email',
          columnType: _isp.ColumnType.text,
          isNullable: true,
          dartType: 'String?',
        ),
        _isp.ColumnDefinition(
          name: 'about',
          columnType: _isp.ColumnType.text,
          isNullable: true,
          dartType: 'String?',
        ),
        _isp.ColumnDefinition(
          name: 'avatarKey',
          columnType: _isp.ColumnType.text,
          isNullable: true,
          dartType: 'String?',
        ),
        _isp.ColumnDefinition(
          name: 'birthDate',
          columnType: _isp.ColumnType.timestampWithoutTimeZone,
          isNullable: true,
          dartType: 'DateTime?',
        ),
        _isp.ColumnDefinition(
          name: 'birthPrecision',
          columnType: _isp.ColumnType.bigint,
          isNullable: true,
          dartType: 'protocol:DatePrecision?',
        ),
        _isp.ColumnDefinition(
          name: 'deathDate',
          columnType: _isp.ColumnType.timestampWithoutTimeZone,
          isNullable: true,
          dartType: 'DateTime?',
        ),
        _isp.ColumnDefinition(
          name: 'deathPrecision',
          columnType: _isp.ColumnType.bigint,
          isNullable: true,
          dartType: 'protocol:DatePrecision?',
        ),
        _isp.ColumnDefinition(
          name: 'passedAway',
          columnType: _isp.ColumnType.boolean,
          isNullable: false,
          dartType: 'bool',
          columnDefault: 'false',
        ),
        _isp.ColumnDefinition(
          name: 'createdById',
          columnType: _isp.ColumnType.uuid,
          isNullable: true,
          dartType: 'UuidValue?',
        ),
        _isp.ColumnDefinition(
          name: 'createdAt',
          columnType: _isp.ColumnType.timestampWithoutTimeZone,
          isNullable: false,
          dartType: 'DateTime',
          columnDefault: 'now',
        ),
        _isp.ColumnDefinition(
          name: 'updatedAt',
          columnType: _isp.ColumnType.timestampWithoutTimeZone,
          isNullable: false,
          dartType: 'DateTime',
          columnDefault: 'now',
        ),
      ],
      foreignKeys: [
        _isp.ForeignKeyDefinition(
          constraintName: 'people_fk_0',
          columns: ['treeId'],
          referenceTable: 'trees',
          referenceTableSchema: 'public',
          referenceColumns: ['id'],
          onUpdate: _isp.ForeignKeyAction.noAction,
          onDelete: _isp.ForeignKeyAction.cascade,
          matchType: null,
        ),
        _isp.ForeignKeyDefinition(
          constraintName: 'people_fk_1',
          columns: ['homeFamilyId'],
          referenceTable: 'families',
          referenceTableSchema: 'public',
          referenceColumns: ['id'],
          onUpdate: _isp.ForeignKeyAction.noAction,
          onDelete: _isp.ForeignKeyAction.restrict,
          matchType: null,
        ),
        _isp.ForeignKeyDefinition(
          constraintName: 'people_fk_2',
          columns: ['userId'],
          referenceTable: 'serverpod_auth_core_user',
          referenceTableSchema: 'public',
          referenceColumns: ['id'],
          onUpdate: _isp.ForeignKeyAction.noAction,
          onDelete: _isp.ForeignKeyAction.setNull,
          matchType: null,
        ),
        _isp.ForeignKeyDefinition(
          constraintName: 'people_fk_3',
          columns: ['createdById'],
          referenceTable: 'serverpod_auth_core_user',
          referenceTableSchema: 'public',
          referenceColumns: ['id'],
          onUpdate: _isp.ForeignKeyAction.noAction,
          onDelete: _isp.ForeignKeyAction.setNull,
          matchType: null,
        ),
      ],
      indexes: [
        _isp.IndexDefinition(
          indexName: 'people_tree_user_uidx',
          tableSpace: null,
          elements: [
            _isp.IndexElementDefinition(
              type: _isp.IndexElementDefinitionType.column,
              definition: 'treeId',
            ),
            _isp.IndexElementDefinition(
              type: _isp.IndexElementDefinitionType.column,
              definition: 'userId',
            ),
          ],
          type: 'btree',
          isUnique: true,
          isPrimary: false,
        ),
        _isp.IndexDefinition(
          indexName: 'people_id_tree_uidx',
          tableSpace: null,
          elements: [
            _isp.IndexElementDefinition(
              type: _isp.IndexElementDefinitionType.column,
              definition: 'id',
            ),
            _isp.IndexElementDefinition(
              type: _isp.IndexElementDefinitionType.column,
              definition: 'treeId',
            ),
          ],
          type: 'btree',
          isUnique: true,
          isPrimary: false,
        ),
        _isp.IndexDefinition(
          indexName: 'people_tree_name_idx',
          tableSpace: null,
          elements: [
            _isp.IndexElementDefinition(
              type: _isp.IndexElementDefinitionType.column,
              definition: 'treeId',
            ),
            _isp.IndexElementDefinition(
              type: _isp.IndexElementDefinitionType.column,
              definition: 'name',
            ),
          ],
          type: 'btree',
          isUnique: false,
          isPrimary: false,
        ),
        _isp.IndexDefinition(
          indexName: 'people_home_family_name_idx',
          tableSpace: null,
          elements: [
            _isp.IndexElementDefinition(
              type: _isp.IndexElementDefinitionType.column,
              definition: 'homeFamilyId',
            ),
            _isp.IndexElementDefinition(
              type: _isp.IndexElementDefinitionType.column,
              definition: 'name',
            ),
          ],
          type: 'btree',
          isUnique: false,
          isPrimary: false,
        ),
        _isp.IndexDefinition(
          indexName: 'people_user_idx',
          tableSpace: null,
          elements: [
            _isp.IndexElementDefinition(
              type: _isp.IndexElementDefinitionType.column,
              definition: 'userId',
            ),
          ],
          type: 'btree',
          isUnique: false,
          isPrimary: false,
        ),
      ],
      managed: true,
    ),
    _isp.TableDefinition(
      name: 'photos',
      dartName: 'Photo',
      schema: 'public',
      module: 'tell_me_a_story',
      columns: [
        _isp.ColumnDefinition(
          name: 'id',
          columnType: _isp.ColumnType.uuid,
          isNullable: false,
          dartType: 'UuidValue?',
          columnDefault: 'random_v7',
        ),
        _isp.ColumnDefinition(
          name: 'storyId',
          columnType: _isp.ColumnType.uuid,
          isNullable: false,
          dartType: 'UuidValue',
        ),
        _isp.ColumnDefinition(
          name: 'uploaderId',
          columnType: _isp.ColumnType.uuid,
          isNullable: true,
          dartType: 'UuidValue?',
        ),
        _isp.ColumnDefinition(
          name: 'originalKey',
          columnType: _isp.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _isp.ColumnDefinition(
          name: 'editedKey',
          columnType: _isp.ColumnType.text,
          isNullable: true,
          dartType: 'String?',
        ),
        _isp.ColumnDefinition(
          name: 'editVersion',
          columnType: _isp.ColumnType.bigint,
          isNullable: false,
          dartType: 'int',
          columnDefault: '0',
        ),
        _isp.ColumnDefinition(
          name: 'sortOrder',
          columnType: _isp.ColumnType.bigint,
          isNullable: false,
          dartType: 'int',
          columnDefault: '0',
        ),
        _isp.ColumnDefinition(
          name: 'createdAt',
          columnType: _isp.ColumnType.timestampWithoutTimeZone,
          isNullable: false,
          dartType: 'DateTime',
          columnDefault: 'now',
        ),
      ],
      foreignKeys: [
        _isp.ForeignKeyDefinition(
          constraintName: 'photos_fk_0',
          columns: ['storyId'],
          referenceTable: 'stories',
          referenceTableSchema: 'public',
          referenceColumns: ['id'],
          onUpdate: _isp.ForeignKeyAction.noAction,
          onDelete: _isp.ForeignKeyAction.cascade,
          matchType: null,
        ),
        _isp.ForeignKeyDefinition(
          constraintName: 'photos_fk_1',
          columns: ['uploaderId'],
          referenceTable: 'serverpod_auth_core_user',
          referenceTableSchema: 'public',
          referenceColumns: ['id'],
          onUpdate: _isp.ForeignKeyAction.noAction,
          onDelete: _isp.ForeignKeyAction.setNull,
          matchType: null,
        ),
      ],
      indexes: [
        _isp.IndexDefinition(
          indexName: 'photos_story_sort_idx',
          tableSpace: null,
          elements: [
            _isp.IndexElementDefinition(
              type: _isp.IndexElementDefinitionType.column,
              definition: 'storyId',
            ),
            _isp.IndexElementDefinition(
              type: _isp.IndexElementDefinitionType.column,
              definition: 'sortOrder',
            ),
          ],
          type: 'btree',
          isUnique: false,
          isPrimary: false,
        ),
      ],
      managed: true,
    ),
    _isp.TableDefinition(
      name: 'places',
      dartName: 'Place',
      schema: 'public',
      module: 'tell_me_a_story',
      columns: [
        _isp.ColumnDefinition(
          name: 'id',
          columnType: _isp.ColumnType.uuid,
          isNullable: false,
          dartType: 'UuidValue?',
          columnDefault: 'random_v7',
        ),
        _isp.ColumnDefinition(
          name: 'treeId',
          columnType: _isp.ColumnType.uuid,
          isNullable: false,
          dartType: 'UuidValue',
        ),
        _isp.ColumnDefinition(
          name: 'label',
          columnType: _isp.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _isp.ColumnDefinition(
          name: 'address',
          columnType: _isp.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _isp.ColumnDefinition(
          name: 'lat',
          columnType: _isp.ColumnType.doublePrecision,
          isNullable: false,
          dartType: 'double',
        ),
        _isp.ColumnDefinition(
          name: 'lng',
          columnType: _isp.ColumnType.doublePrecision,
          isNullable: false,
          dartType: 'double',
        ),
        _isp.ColumnDefinition(
          name: 'mapboxPlaceId',
          columnType: _isp.ColumnType.text,
          isNullable: true,
          dartType: 'String?',
        ),
        _isp.ColumnDefinition(
          name: 'isFavorite',
          columnType: _isp.ColumnType.boolean,
          isNullable: false,
          dartType: 'bool',
          columnDefault: 'false',
        ),
        _isp.ColumnDefinition(
          name: 'lastUsedAt',
          columnType: _isp.ColumnType.timestampWithoutTimeZone,
          isNullable: true,
          dartType: 'DateTime?',
        ),
        _isp.ColumnDefinition(
          name: 'createdAt',
          columnType: _isp.ColumnType.timestampWithoutTimeZone,
          isNullable: false,
          dartType: 'DateTime',
          columnDefault: 'now',
        ),
      ],
      foreignKeys: [
        _isp.ForeignKeyDefinition(
          constraintName: 'places_fk_0',
          columns: ['treeId'],
          referenceTable: 'trees',
          referenceTableSchema: 'public',
          referenceColumns: ['id'],
          onUpdate: _isp.ForeignKeyAction.noAction,
          onDelete: _isp.ForeignKeyAction.cascade,
          matchType: null,
        ),
      ],
      indexes: [
        _isp.IndexDefinition(
          indexName: 'places_id_tree_uidx',
          tableSpace: null,
          elements: [
            _isp.IndexElementDefinition(
              type: _isp.IndexElementDefinitionType.column,
              definition: 'id',
            ),
            _isp.IndexElementDefinition(
              type: _isp.IndexElementDefinitionType.column,
              definition: 'treeId',
            ),
          ],
          type: 'btree',
          isUnique: true,
          isPrimary: false,
        ),
        _isp.IndexDefinition(
          indexName: 'places_tree_label_idx',
          tableSpace: null,
          elements: [
            _isp.IndexElementDefinition(
              type: _isp.IndexElementDefinitionType.column,
              definition: 'treeId',
            ),
            _isp.IndexElementDefinition(
              type: _isp.IndexElementDefinitionType.column,
              definition: 'label',
            ),
          ],
          type: 'btree',
          isUnique: false,
          isPrimary: false,
        ),
        _isp.IndexDefinition(
          indexName: 'places_tree_mapbox_uidx',
          tableSpace: null,
          elements: [
            _isp.IndexElementDefinition(
              type: _isp.IndexElementDefinitionType.column,
              definition: 'treeId',
            ),
            _isp.IndexElementDefinition(
              type: _isp.IndexElementDefinitionType.column,
              definition: 'mapboxPlaceId',
            ),
          ],
          type: 'btree',
          isUnique: true,
          isPrimary: false,
        ),
        _isp.IndexDefinition(
          indexName: 'places_tree_last_used_idx',
          tableSpace: null,
          elements: [
            _isp.IndexElementDefinition(
              type: _isp.IndexElementDefinitionType.column,
              definition: 'treeId',
            ),
            _isp.IndexElementDefinition(
              type: _isp.IndexElementDefinitionType.column,
              definition: 'lastUsedAt',
            ),
          ],
          type: 'btree',
          isUnique: false,
          isPrimary: false,
        ),
      ],
      managed: true,
    ),
    _isp.TableDefinition(
      name: 'stories',
      dartName: 'Story',
      schema: 'public',
      module: 'tell_me_a_story',
      columns: [
        _isp.ColumnDefinition(
          name: 'id',
          columnType: _isp.ColumnType.uuid,
          isNullable: false,
          dartType: 'UuidValue?',
          columnDefault: 'random_v7',
        ),
        _isp.ColumnDefinition(
          name: 'familyId',
          columnType: _isp.ColumnType.uuid,
          isNullable: false,
          dartType: 'UuidValue',
        ),
        _isp.ColumnDefinition(
          name: 'treeId',
          columnType: _isp.ColumnType.uuid,
          isNullable: false,
          dartType: 'UuidValue',
        ),
        _isp.ColumnDefinition(
          name: 'authorId',
          columnType: _isp.ColumnType.uuid,
          isNullable: true,
          dartType: 'UuidValue?',
        ),
        _isp.ColumnDefinition(
          name: 'title',
          columnType: _isp.ColumnType.text,
          isNullable: true,
          dartType: 'String?',
        ),
        _isp.ColumnDefinition(
          name: 'body',
          columnType: _isp.ColumnType.text,
          isNullable: true,
          dartType: 'String?',
        ),
        _isp.ColumnDefinition(
          name: 'status',
          columnType: _isp.ColumnType.text,
          isNullable: false,
          dartType: 'protocol:StoryStatus',
          columnDefault: '\'draft\'',
        ),
        _isp.ColumnDefinition(
          name: 'dateStart',
          columnType: _isp.ColumnType.timestampWithoutTimeZone,
          isNullable: true,
          dartType: 'DateTime?',
        ),
        _isp.ColumnDefinition(
          name: 'dateEnd',
          columnType: _isp.ColumnType.timestampWithoutTimeZone,
          isNullable: true,
          dartType: 'DateTime?',
        ),
        _isp.ColumnDefinition(
          name: 'datePrecision',
          columnType: _isp.ColumnType.bigint,
          isNullable: true,
          dartType: 'protocol:DatePrecision?',
        ),
        _isp.ColumnDefinition(
          name: 'placeId',
          columnType: _isp.ColumnType.uuid,
          isNullable: true,
          dartType: 'UuidValue?',
        ),
        _isp.ColumnDefinition(
          name: 'publishedAt',
          columnType: _isp.ColumnType.timestampWithoutTimeZone,
          isNullable: true,
          dartType: 'DateTime?',
        ),
        _isp.ColumnDefinition(
          name: 'createdAt',
          columnType: _isp.ColumnType.timestampWithoutTimeZone,
          isNullable: false,
          dartType: 'DateTime',
          columnDefault: 'now',
        ),
        _isp.ColumnDefinition(
          name: 'updatedAt',
          columnType: _isp.ColumnType.timestampWithoutTimeZone,
          isNullable: false,
          dartType: 'DateTime',
          columnDefault: 'now',
        ),
      ],
      foreignKeys: [
        _isp.ForeignKeyDefinition(
          constraintName: 'stories_fk_0',
          columns: ['familyId'],
          referenceTable: 'families',
          referenceTableSchema: 'public',
          referenceColumns: ['id'],
          onUpdate: _isp.ForeignKeyAction.noAction,
          onDelete: _isp.ForeignKeyAction.cascade,
          matchType: null,
        ),
        _isp.ForeignKeyDefinition(
          constraintName: 'stories_fk_1',
          columns: ['authorId'],
          referenceTable: 'serverpod_auth_core_user',
          referenceTableSchema: 'public',
          referenceColumns: ['id'],
          onUpdate: _isp.ForeignKeyAction.noAction,
          onDelete: _isp.ForeignKeyAction.setNull,
          matchType: null,
        ),
        _isp.ForeignKeyDefinition(
          constraintName: 'stories_fk_2',
          columns: ['placeId'],
          referenceTable: 'places',
          referenceTableSchema: 'public',
          referenceColumns: ['id'],
          onUpdate: _isp.ForeignKeyAction.noAction,
          onDelete: _isp.ForeignKeyAction.setNull,
          matchType: null,
        ),
      ],
      indexes: [
        _isp.IndexDefinition(
          indexName: 'stories_family_order_idx',
          tableSpace: null,
          elements: [
            _isp.IndexElementDefinition(
              type: _isp.IndexElementDefinitionType.column,
              definition: 'familyId',
            ),
            _isp.IndexElementDefinition(
              type: _isp.IndexElementDefinitionType.column,
              definition: 'status',
            ),
            _isp.IndexElementDefinition(
              type: _isp.IndexElementDefinitionType.column,
              definition: 'dateStart',
            ),
            _isp.IndexElementDefinition(
              type: _isp.IndexElementDefinitionType.column,
              definition: 'datePrecision',
            ),
            _isp.IndexElementDefinition(
              type: _isp.IndexElementDefinitionType.column,
              definition: 'createdAt',
            ),
            _isp.IndexElementDefinition(
              type: _isp.IndexElementDefinitionType.column,
              definition: 'id',
            ),
          ],
          type: 'btree',
          isUnique: false,
          isPrimary: false,
        ),
        _isp.IndexDefinition(
          indexName: 'stories_author_status_idx',
          tableSpace: null,
          elements: [
            _isp.IndexElementDefinition(
              type: _isp.IndexElementDefinitionType.column,
              definition: 'authorId',
            ),
            _isp.IndexElementDefinition(
              type: _isp.IndexElementDefinitionType.column,
              definition: 'status',
            ),
          ],
          type: 'btree',
          isUnique: false,
          isPrimary: false,
        ),
        _isp.IndexDefinition(
          indexName: 'stories_family_published_at_idx',
          tableSpace: null,
          elements: [
            _isp.IndexElementDefinition(
              type: _isp.IndexElementDefinitionType.column,
              definition: 'familyId',
            ),
            _isp.IndexElementDefinition(
              type: _isp.IndexElementDefinitionType.column,
              definition: 'publishedAt',
            ),
          ],
          type: 'btree',
          isUnique: false,
          isPrimary: false,
        ),
        _isp.IndexDefinition(
          indexName: 'stories_place_idx',
          tableSpace: null,
          elements: [
            _isp.IndexElementDefinition(
              type: _isp.IndexElementDefinitionType.column,
              definition: 'placeId',
            ),
          ],
          type: 'btree',
          isUnique: false,
          isPrimary: false,
        ),
        _isp.IndexDefinition(
          indexName: 'stories_id_tree_uidx',
          tableSpace: null,
          elements: [
            _isp.IndexElementDefinition(
              type: _isp.IndexElementDefinitionType.column,
              definition: 'id',
            ),
            _isp.IndexElementDefinition(
              type: _isp.IndexElementDefinitionType.column,
              definition: 'treeId',
            ),
          ],
          type: 'btree',
          isUnique: true,
          isPrimary: false,
        ),
      ],
      managed: true,
    ),
    _isp.TableDefinition(
      name: 'story_notes',
      dartName: 'StoryNote',
      schema: 'public',
      module: 'tell_me_a_story',
      columns: [
        _isp.ColumnDefinition(
          name: 'id',
          columnType: _isp.ColumnType.uuid,
          isNullable: false,
          dartType: 'UuidValue?',
          columnDefault: 'random_v7',
        ),
        _isp.ColumnDefinition(
          name: 'storyId',
          columnType: _isp.ColumnType.uuid,
          isNullable: false,
          dartType: 'UuidValue',
        ),
        _isp.ColumnDefinition(
          name: 'authorId',
          columnType: _isp.ColumnType.uuid,
          isNullable: true,
          dartType: 'UuidValue?',
        ),
        _isp.ColumnDefinition(
          name: 'kind',
          columnType: _isp.ColumnType.text,
          isNullable: false,
          dartType: 'protocol:NoteKind',
        ),
        _isp.ColumnDefinition(
          name: 'body',
          columnType: _isp.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _isp.ColumnDefinition(
          name: 'createdAt',
          columnType: _isp.ColumnType.timestampWithoutTimeZone,
          isNullable: false,
          dartType: 'DateTime',
          columnDefault: 'now',
        ),
        _isp.ColumnDefinition(
          name: 'updatedAt',
          columnType: _isp.ColumnType.timestampWithoutTimeZone,
          isNullable: false,
          dartType: 'DateTime',
          columnDefault: 'now',
        ),
      ],
      foreignKeys: [
        _isp.ForeignKeyDefinition(
          constraintName: 'story_notes_fk_0',
          columns: ['storyId'],
          referenceTable: 'stories',
          referenceTableSchema: 'public',
          referenceColumns: ['id'],
          onUpdate: _isp.ForeignKeyAction.noAction,
          onDelete: _isp.ForeignKeyAction.cascade,
          matchType: null,
        ),
        _isp.ForeignKeyDefinition(
          constraintName: 'story_notes_fk_1',
          columns: ['authorId'],
          referenceTable: 'serverpod_auth_core_user',
          referenceTableSchema: 'public',
          referenceColumns: ['id'],
          onUpdate: _isp.ForeignKeyAction.noAction,
          onDelete: _isp.ForeignKeyAction.setNull,
          matchType: null,
        ),
      ],
      indexes: [
        _isp.IndexDefinition(
          indexName: 'story_notes_story_kind_created_idx',
          tableSpace: null,
          elements: [
            _isp.IndexElementDefinition(
              type: _isp.IndexElementDefinitionType.column,
              definition: 'storyId',
            ),
            _isp.IndexElementDefinition(
              type: _isp.IndexElementDefinitionType.column,
              definition: 'kind',
            ),
            _isp.IndexElementDefinition(
              type: _isp.IndexElementDefinitionType.column,
              definition: 'createdAt',
            ),
          ],
          type: 'btree',
          isUnique: false,
          isPrimary: false,
        ),
      ],
      managed: true,
    ),
    _isp.TableDefinition(
      name: 'story_people',
      dartName: 'StoryPerson',
      schema: 'public',
      module: 'tell_me_a_story',
      columns: [
        _isp.ColumnDefinition(
          name: 'id',
          columnType: _isp.ColumnType.uuid,
          isNullable: false,
          dartType: 'UuidValue?',
          columnDefault: 'random_v7',
        ),
        _isp.ColumnDefinition(
          name: 'storyId',
          columnType: _isp.ColumnType.uuid,
          isNullable: false,
          dartType: 'UuidValue',
        ),
        _isp.ColumnDefinition(
          name: 'personId',
          columnType: _isp.ColumnType.uuid,
          isNullable: false,
          dartType: 'UuidValue',
        ),
        _isp.ColumnDefinition(
          name: 'treeId',
          columnType: _isp.ColumnType.uuid,
          isNullable: false,
          dartType: 'UuidValue',
        ),
      ],
      foreignKeys: [
        _isp.ForeignKeyDefinition(
          constraintName: 'story_people_fk_0',
          columns: ['storyId'],
          referenceTable: 'stories',
          referenceTableSchema: 'public',
          referenceColumns: ['id'],
          onUpdate: _isp.ForeignKeyAction.noAction,
          onDelete: _isp.ForeignKeyAction.cascade,
          matchType: null,
        ),
        _isp.ForeignKeyDefinition(
          constraintName: 'story_people_fk_1',
          columns: ['personId'],
          referenceTable: 'people',
          referenceTableSchema: 'public',
          referenceColumns: ['id'],
          onUpdate: _isp.ForeignKeyAction.noAction,
          onDelete: _isp.ForeignKeyAction.cascade,
          matchType: null,
        ),
      ],
      indexes: [
        _isp.IndexDefinition(
          indexName: 'story_people_story_person_uidx',
          tableSpace: null,
          elements: [
            _isp.IndexElementDefinition(
              type: _isp.IndexElementDefinitionType.column,
              definition: 'storyId',
            ),
            _isp.IndexElementDefinition(
              type: _isp.IndexElementDefinitionType.column,
              definition: 'personId',
            ),
          ],
          type: 'btree',
          isUnique: true,
          isPrimary: false,
        ),
        _isp.IndexDefinition(
          indexName: 'story_people_person_idx',
          tableSpace: null,
          elements: [
            _isp.IndexElementDefinition(
              type: _isp.IndexElementDefinitionType.column,
              definition: 'personId',
            ),
          ],
          type: 'btree',
          isUnique: false,
          isPrimary: false,
        ),
      ],
      managed: true,
    ),
    _isp.TableDefinition(
      name: 'trees',
      dartName: 'Tree',
      schema: 'public',
      module: 'tell_me_a_story',
      columns: [
        _isp.ColumnDefinition(
          name: 'id',
          columnType: _isp.ColumnType.uuid,
          isNullable: false,
          dartType: 'UuidValue?',
          columnDefault: 'random_v7',
        ),
        _isp.ColumnDefinition(
          name: 'createdAt',
          columnType: _isp.ColumnType.timestampWithoutTimeZone,
          isNullable: false,
          dartType: 'DateTime',
          columnDefault: 'now',
        ),
      ],
      foreignKeys: [],
      indexes: [],
      managed: true,
    ),
    _isp.TableDefinition(
      name: 'users',
      dartName: 'AppUser',
      schema: 'public',
      module: 'tell_me_a_story',
      columns: [
        _isp.ColumnDefinition(
          name: 'id',
          columnType: _isp.ColumnType.uuid,
          isNullable: false,
          dartType: 'UuidValue?',
          columnDefault: 'random_v7',
        ),
        _isp.ColumnDefinition(
          name: 'authUserId',
          columnType: _isp.ColumnType.uuid,
          isNullable: false,
          dartType: 'UuidValue',
        ),
        _isp.ColumnDefinition(
          name: 'displayName',
          columnType: _isp.ColumnType.text,
          isNullable: true,
          dartType: 'String?',
        ),
        _isp.ColumnDefinition(
          name: 'avatarKey',
          columnType: _isp.ColumnType.text,
          isNullable: true,
          dartType: 'String?',
        ),
        _isp.ColumnDefinition(
          name: 'about',
          columnType: _isp.ColumnType.text,
          isNullable: true,
          dartType: 'String?',
        ),
        _isp.ColumnDefinition(
          name: 'birthDate',
          columnType: _isp.ColumnType.timestampWithoutTimeZone,
          isNullable: true,
          dartType: 'DateTime?',
        ),
        _isp.ColumnDefinition(
          name: 'birthPrecision',
          columnType: _isp.ColumnType.bigint,
          isNullable: true,
          dartType: 'protocol:DatePrecision?',
        ),
        _isp.ColumnDefinition(
          name: 'birthVisibility',
          columnType: _isp.ColumnType.text,
          isNullable: false,
          dartType: 'protocol:BirthVisibility',
          columnDefault: '\'hidden\'',
        ),
        _isp.ColumnDefinition(
          name: 'createdAt',
          columnType: _isp.ColumnType.timestampWithoutTimeZone,
          isNullable: false,
          dartType: 'DateTime',
          columnDefault: 'now',
        ),
        _isp.ColumnDefinition(
          name: 'updatedAt',
          columnType: _isp.ColumnType.timestampWithoutTimeZone,
          isNullable: false,
          dartType: 'DateTime',
          columnDefault: 'now',
        ),
      ],
      foreignKeys: [
        _isp.ForeignKeyDefinition(
          constraintName: 'users_fk_0',
          columns: ['authUserId'],
          referenceTable: 'serverpod_auth_core_user',
          referenceTableSchema: 'public',
          referenceColumns: ['id'],
          onUpdate: _isp.ForeignKeyAction.noAction,
          onDelete: _isp.ForeignKeyAction.cascade,
          matchType: null,
        ),
      ],
      indexes: [
        _isp.IndexDefinition(
          indexName: 'users_auth_user_uidx',
          tableSpace: null,
          elements: [
            _isp.IndexElementDefinition(
              type: _isp.IndexElementDefinitionType.column,
              definition: 'authUserId',
            ),
          ],
          type: 'btree',
          isUnique: true,
          isPrimary: false,
        ),
      ],
      managed: true,
    ),
    ..._iais.Protocol.targetTableDefinitions,
    ..._iacs.Protocol.targetTableDefinitions,
    ..._isp.Protocol.targetTableDefinitions,
  ];

  static String? getClassNameFromObjectJson(dynamic data) =>
      _is.ProtocolDeserialization.readClassName(data);

  @override
  T deserialize<T>(
    dynamic data, [
    Type? t,
  ]) {
    t ??= T;
    final rawDataClassName = _is.ProtocolDeserialization.readClassName(data);
    final dataClassName = rawDataClassName;
    if (dataClassName != null && dataClassName != getClassNameForType(t)) {
      try {
        return deserializeByClassName({
          'className': dataClassName,
          'data': data,
        });
      } on _is.DeserializationClassNameNotFoundException catch (_) {
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
    if (t == _ig8q6jh0.BlobDeletion) {
      return _ig8q6jh0.BlobDeletion.fromJson(data) as T;
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
    if (t == _ibtb2p99.Invite) {
      return _ibtb2p99.Invite.fromJson(data) as T;
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
    if (t == _is.getType<_imu8gbx5.AppErrorCode?>()) {
      return (data != null ? _imu8gbx5.AppErrorCode.fromJson(data) : null) as T;
    }
    if (t == _is.getType<_it4z223c.AppException?>()) {
      return (data != null ? _it4z223c.AppException.fromJson(data) : null) as T;
    }
    if (t == _is.getType<_i2j2xfrn.AppUser?>()) {
      return (data != null ? _i2j2xfrn.AppUser.fromJson(data) : null) as T;
    }
    if (t == _is.getType<_i2x3tia5.BirthVisibility?>()) {
      return (data != null ? _i2x3tia5.BirthVisibility.fromJson(data) : null)
          as T;
    }
    if (t == _is.getType<_ig8q6jh0.BlobDeletion?>()) {
      return (data != null ? _ig8q6jh0.BlobDeletion.fromJson(data) : null) as T;
    }
    if (t == _is.getType<_ilvyd2nu.DatePrecision?>()) {
      return (data != null ? _ilvyd2nu.DatePrecision.fromJson(data) : null)
          as T;
    }
    if (t == _is.getType<_ieh1xhhu.CoverUploadTicketDto?>()) {
      return (data != null
              ? _ieh1xhhu.CoverUploadTicketDto.fromJson(data)
              : null)
          as T;
    }
    if (t == _is.getType<_i5tlcydc.CreatedInviteDto?>()) {
      return (data != null ? _i5tlcydc.CreatedInviteDto.fromJson(data) : null)
          as T;
    }
    if (t == _is.getType<_i3bc4i2z.DecadeFacetDto?>()) {
      return (data != null ? _i3bc4i2z.DecadeFacetDto.fromJson(data) : null)
          as T;
    }
    if (t == _is.getType<_i454qtto.FamilyDetailDto?>()) {
      return (data != null ? _i454qtto.FamilyDetailDto.fromJson(data) : null)
          as T;
    }
    if (t == _is.getType<_ibjtxzev.FamilyDirectoryDto?>()) {
      return (data != null ? _ibjtxzev.FamilyDirectoryDto.fromJson(data) : null)
          as T;
    }
    if (t == _is.getType<_i6t2z5gc.FamilyMemberDto?>()) {
      return (data != null ? _i6t2z5gc.FamilyMemberDto.fromJson(data) : null)
          as T;
    }
    if (t == _is.getType<_ihq257tz.FamilyRosterDto?>()) {
      return (data != null ? _ihq257tz.FamilyRosterDto.fromJson(data) : null)
          as T;
    }
    if (t == _is.getType<_in2wbmsu.InvitePreviewDto?>()) {
      return (data != null ? _in2wbmsu.InvitePreviewDto.fromJson(data) : null)
          as T;
    }
    if (t == _is.getType<_ia1fjje5.KinshipDto?>()) {
      return (data != null ? _ia1fjje5.KinshipDto.fromJson(data) : null) as T;
    }
    if (t == _is.getType<_ipyvbztq.LiveEventDto?>()) {
      return (data != null ? _ipyvbztq.LiveEventDto.fromJson(data) : null) as T;
    }
    if (t == _is.getType<_i67kei86.LiveKind?>()) {
      return (data != null ? _i67kei86.LiveKind.fromJson(data) : null) as T;
    }
    if (t == _is.getType<_ir8o3gjk.MemberFamilyDto?>()) {
      return (data != null ? _ir8o3gjk.MemberFamilyDto.fromJson(data) : null)
          as T;
    }
    if (t == _is.getType<_i6e6avtv.NoteDto?>()) {
      return (data != null ? _i6e6avtv.NoteDto.fromJson(data) : null) as T;
    }
    if (t == _is.getType<_i9h96nn2.OriginDependentDto?>()) {
      return (data != null ? _i9h96nn2.OriginDependentDto.fromJson(data) : null)
          as T;
    }
    if (t == _is.getType<_is5ywasv.OwnProfileDto?>()) {
      return (data != null ? _is5ywasv.OwnProfileDto.fromJson(data) : null)
          as T;
    }
    if (t == _is.getType<_i5vdpx0m.PendingInviteDto?>()) {
      return (data != null ? _i5vdpx0m.PendingInviteDto.fromJson(data) : null)
          as T;
    }
    if (t == _is.getType<_ig7qj6yo.PersonDto?>()) {
      return (data != null ? _ig7qj6yo.PersonDto.fromJson(data) : null) as T;
    }
    if (t == _is.getType<_ikbgxdng.PersonFacetDto?>()) {
      return (data != null ? _ikbgxdng.PersonFacetDto.fromJson(data) : null)
          as T;
    }
    if (t == _is.getType<_i38icd77.PersonProfileDto?>()) {
      return (data != null ? _i38icd77.PersonProfileDto.fromJson(data) : null)
          as T;
    }
    if (t == _is.getType<_imob66rg.PersonWriteDto?>()) {
      return (data != null ? _imob66rg.PersonWriteDto.fromJson(data) : null)
          as T;
    }
    if (t == _is.getType<_i3tneuol.PhotoDto?>()) {
      return (data != null ? _i3tneuol.PhotoDto.fromJson(data) : null) as T;
    }
    if (t == _is.getType<_i91pkskm.PhotoRefDto?>()) {
      return (data != null ? _i91pkskm.PhotoRefDto.fromJson(data) : null) as T;
    }
    if (t == _is.getType<_i5l4kjca.PhotoUploadTicketDto?>()) {
      return (data != null
              ? _i5l4kjca.PhotoUploadTicketDto.fromJson(data)
              : null)
          as T;
    }
    if (t == _is.getType<_ijvrvfy5.PlaceDto?>()) {
      return (data != null ? _ijvrvfy5.PlaceDto.fromJson(data) : null) as T;
    }
    if (t == _is.getType<_ioxclq7u.PlaceFacetDto?>()) {
      return (data != null ? _ioxclq7u.PlaceFacetDto.fromJson(data) : null)
          as T;
    }
    if (t == _is.getType<_i85hzch5.PlaceInputDto?>()) {
      return (data != null ? _i85hzch5.PlaceInputDto.fromJson(data) : null)
          as T;
    }
    if (t == _is.getType<_ikw9cscj.SearchSort?>()) {
      return (data != null ? _ikw9cscj.SearchSort.fromJson(data) : null) as T;
    }
    if (t == _is.getType<_imtvyjr9.StewardFamilyDto?>()) {
      return (data != null ? _imtvyjr9.StewardFamilyDto.fromJson(data) : null)
          as T;
    }
    if (t == _is.getType<_ipnasz46.StoryDto?>()) {
      return (data != null ? _ipnasz46.StoryDto.fromJson(data) : null) as T;
    }
    if (t == _is.getType<_i57prwgh.StoryFacetsDto?>()) {
      return (data != null ? _i57prwgh.StoryFacetsDto.fromJson(data) : null)
          as T;
    }
    if (t == _is.getType<_ipq9eknh.StoryPersonDto?>()) {
      return (data != null ? _ipq9eknh.StoryPersonDto.fromJson(data) : null)
          as T;
    }
    if (t == _is.getType<_i93osgfq.StorySearchDto?>()) {
      return (data != null ? _i93osgfq.StorySearchDto.fromJson(data) : null)
          as T;
    }
    if (t == _is.getType<_i70jvi55.StoryWriteDto?>()) {
      return (data != null ? _i70jvi55.StoryWriteDto.fromJson(data) : null)
          as T;
    }
    if (t == _is.getType<_i91d5kcr.TreeFamilyDto?>()) {
      return (data != null ? _i91d5kcr.TreeFamilyDto.fromJson(data) : null)
          as T;
    }
    if (t == _is.getType<_igf5ho4a.Family?>()) {
      return (data != null ? _igf5ho4a.Family.fromJson(data) : null) as T;
    }
    if (t == _is.getType<_ibtb2p99.Invite?>()) {
      return (data != null ? _ibtb2p99.Invite.fromJson(data) : null) as T;
    }
    if (t == _is.getType<_itzlol5n.Kinship?>()) {
      return (data != null ? _itzlol5n.Kinship.fromJson(data) : null) as T;
    }
    if (t == _is.getType<_iq59nsdl.KinshipKind?>()) {
      return (data != null ? _iq59nsdl.KinshipKind.fromJson(data) : null) as T;
    }
    if (t == _is.getType<_iu35fd1a.Membership?>()) {
      return (data != null ? _iu35fd1a.Membership.fromJson(data) : null) as T;
    }
    if (t == _is.getType<_iur1rrwm.MembershipRole?>()) {
      return (data != null ? _iur1rrwm.MembershipRole.fromJson(data) : null)
          as T;
    }
    if (t == _is.getType<_ixhn57mr.NoteKind?>()) {
      return (data != null ? _ixhn57mr.NoteKind.fromJson(data) : null) as T;
    }
    if (t == _is.getType<_iensfz4m.Person?>()) {
      return (data != null ? _iensfz4m.Person.fromJson(data) : null) as T;
    }
    if (t == _is.getType<_ii8pt9rm.Photo?>()) {
      return (data != null ? _ii8pt9rm.Photo.fromJson(data) : null) as T;
    }
    if (t == _is.getType<_isaqapjx.Place?>()) {
      return (data != null ? _isaqapjx.Place.fromJson(data) : null) as T;
    }
    if (t == _is.getType<_ixuwv6na.Story?>()) {
      return (data != null ? _ixuwv6na.Story.fromJson(data) : null) as T;
    }
    if (t == _is.getType<_iugi3tvg.StoryNote?>()) {
      return (data != null ? _iugi3tvg.StoryNote.fromJson(data) : null) as T;
    }
    if (t == _is.getType<_i0053fvj.StoryPerson?>()) {
      return (data != null ? _i0053fvj.StoryPerson.fromJson(data) : null) as T;
    }
    if (t == _is.getType<_ixc1exsr.StoryStatus?>()) {
      return (data != null ? _ixc1exsr.StoryStatus.fromJson(data) : null) as T;
    }
    if (t == _is.getType<_i5e6tmks.Tree?>()) {
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
    if (t == List<_is.UuidValue>) {
      return (data as List).map((e) => deserialize<_is.UuidValue>(e)).toList()
          as T;
    }
    if (t == List<int>) {
      return (data as List).map((e) => deserialize<int>(e)).toList() as T;
    }
    if (t == _is.getType<List<_is.UuidValue>?>()) {
      return (data != null
              ? (data as List)
                    .map((e) => deserialize<_is.UuidValue>(e))
                    .toList()
              : null)
          as T;
    }
    if (t == List<_i3xh6672.PlaceDto>) {
      return (data as List)
              .map((e) => deserialize<_i3xh6672.PlaceDto>(e))
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
      } on _is.DeserializationTypeNotFoundException catch (_) {}
    }

    return super.deserialize<T>(data, t);
  }

  static String? getClassNameForType(Type type) {
    return switch (type) {
      _imu8gbx5.AppErrorCode => 'AppErrorCode',
      _it4z223c.AppException => 'AppException',
      _i2j2xfrn.AppUser => 'AppUser',
      _i2x3tia5.BirthVisibility => 'BirthVisibility',
      _ig8q6jh0.BlobDeletion => 'BlobDeletion',
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
      _ibtb2p99.Invite => 'Invite',
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
      case _ig8q6jh0.BlobDeletion():
        return 'BlobDeletion';
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
      case _ibtb2p99.Invite():
        return 'Invite';
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
    className = _iais.Protocol().getClassNameForObject(data);
    if (className != null) {
      return className.contains('.')
          ? className
          : 'serverpod_auth_idp.$className';
    }
    className = _iacs.Protocol().getClassNameForObject(data);
    if (className != null) {
      return className.contains('.')
          ? className
          : 'serverpod_auth_core.$className';
    }
    className = _isp.Protocol().getClassNameForObject(data);
    if (className != null) {
      return className.contains('.') ? className : 'serverpod.$className';
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
    if (dataClassName == 'BlobDeletion') {
      return deserialize<_ig8q6jh0.BlobDeletion>(data['data']);
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
    if (dataClassName == 'Invite') {
      return deserialize<_ibtb2p99.Invite>(data['data']);
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
      return _iais.Protocol().deserializeByClassName({
        ...data,
        'className': dataClassName.substring(19),
      });
    }
    if (dataClassName.startsWith('serverpod_auth_core.')) {
      return _iacs.Protocol().deserializeByClassName({
        ...data,
        'className': dataClassName.substring(20),
      });
    }
    if (dataClassName.startsWith('serverpod.')) {
      return _isp.Protocol().deserializeByClassName({
        ...data,
        'className': dataClassName.substring(10),
      });
    }
    return super.deserializeByClassName(data);
  }

  void _registerHostProtocols() {
    _iais.Protocol().registerHostProtocol('tell_me_a_story', this);
    _iacs.Protocol().registerHostProtocol('tell_me_a_story', this);
  }

  @override
  _is.Table? getTableForType(Type t) {
    {
      var table = _iais.Protocol().getTableForType(t);
      if (table != null) {
        return table;
      }
    }
    {
      var table = _iacs.Protocol().getTableForType(t);
      if (table != null) {
        return table;
      }
    }
    {
      var table = _isp.Protocol().getTableForType(t);
      if (table != null) {
        return table;
      }
    }
    switch (t) {
      case _i2j2xfrn.AppUser:
        return _i2j2xfrn.AppUser.t;
      case _ig8q6jh0.BlobDeletion:
        return _ig8q6jh0.BlobDeletion.t;
      case _igf5ho4a.Family:
        return _igf5ho4a.Family.t;
      case _ibtb2p99.Invite:
        return _ibtb2p99.Invite.t;
      case _itzlol5n.Kinship:
        return _itzlol5n.Kinship.t;
      case _iu35fd1a.Membership:
        return _iu35fd1a.Membership.t;
      case _iensfz4m.Person:
        return _iensfz4m.Person.t;
      case _ii8pt9rm.Photo:
        return _ii8pt9rm.Photo.t;
      case _isaqapjx.Place:
        return _isaqapjx.Place.t;
      case _ixuwv6na.Story:
        return _ixuwv6na.Story.t;
      case _iugi3tvg.StoryNote:
        return _iugi3tvg.StoryNote.t;
      case _i0053fvj.StoryPerson:
        return _i0053fvj.StoryPerson.t;
      case _i5e6tmks.Tree:
        return _i5e6tmks.Tree.t;
    }
    return null;
  }

  @override
  List<_isp.TableDefinition> getTargetTableDefinitions() =>
      targetTableDefinitions;

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
      return _iais.Protocol().mapRecordToJson(record);
    } catch (_) {}
    try {
      return _iacs.Protocol().mapRecordToJson(record);
    } catch (_) {}
    throw Exception('Unsupported record type ${record.runtimeType}');
  }
}
