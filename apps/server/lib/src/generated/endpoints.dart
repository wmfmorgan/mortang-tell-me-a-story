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
import 'dart:typed_data' as _idt;
import 'package:serverpod/serverpod.dart' as _is;
import 'package:serverpod_auth_core_server/serverpod_auth_core_server.dart'
    as _iacs;
import 'package:serverpod_auth_idp_server/serverpod_auth_idp_server.dart'
    as _iais;
import 'package:tell_me_a_story_server/src/generated/birth_visibility.dart'
    as _i0rpsun5;
import 'package:tell_me_a_story_server/src/generated/date_precision.dart'
    as _ig52w51f;
import 'package:tell_me_a_story_server/src/generated/dto/person_write_dto.dart'
    as _imyz5bcs;
import 'package:tell_me_a_story_server/src/generated/dto/place_input_dto.dart'
    as _iqvasz3a;
import 'package:tell_me_a_story_server/src/generated/dto/story_search_dto.dart'
    as _ix1z7n33;
import 'package:tell_me_a_story_server/src/generated/dto/story_write_dto.dart'
    as _iu03akf8;
import 'package:tell_me_a_story_server/src/generated/future_calls.dart'
    as _iggapxvt;
import 'package:tell_me_a_story_server/src/generated/membership_role.dart'
    as _ic4z8goi;
import 'package:tell_me_a_story_server/src/generated/note_kind.dart'
    as _ija2hb8o;
import '../auth/email_idp_endpoint.dart' as _iuc1hd5t;
import '../auth/jwt_refresh_endpoint.dart' as _inwq3ztq;
import '../endpoints/family_endpoint.dart' as _ibe5smjw;
import '../endpoints/invite_endpoint.dart' as _ip80nve4;
import '../endpoints/invite_public_endpoint.dart' as _ip1i0qvr;
import '../endpoints/live_endpoint.dart' as _ixgr9pqx;
import '../endpoints/media_endpoint.dart' as _iaymoujt;
import '../endpoints/note_endpoint.dart' as _i4n3t746;
import '../endpoints/people_endpoint.dart' as _iqqt4psm;
import '../endpoints/photo_endpoint.dart' as _ihuw68ce;
import '../endpoints/place_endpoint.dart' as _ilyqdzjc;
import '../endpoints/profile_endpoint.dart' as _i2cx2pww;
import '../endpoints/story_endpoint.dart' as _iiu4mi32;
export 'future_calls.dart' show ServerpodFutureCallsGetter;

class Endpoints extends _is.EndpointDispatch {
  @override
  void initializeEndpoints(_is.Server server) {
    var endpoints = <String, _is.Endpoint>{
      'emailIdp': _iuc1hd5t.EmailIdpEndpoint()
        ..initialize(
          server,
          'emailIdp',
          null,
        ),
      'jwtRefresh': _inwq3ztq.JwtRefreshEndpoint()
        ..initialize(
          server,
          'jwtRefresh',
          null,
        ),
      'family': _ibe5smjw.FamilyEndpoint()
        ..initialize(
          server,
          'family',
          null,
        ),
      'invite': _ip80nve4.InviteEndpoint()
        ..initialize(
          server,
          'invite',
          null,
        ),
      'invitePublic': _ip1i0qvr.InvitePublicEndpoint()
        ..initialize(
          server,
          'invitePublic',
          null,
        ),
      'live': _ixgr9pqx.LiveEndpoint()
        ..initialize(
          server,
          'live',
          null,
        ),
      'media': _iaymoujt.MediaEndpoint()
        ..initialize(
          server,
          'media',
          null,
        ),
      'note': _i4n3t746.NoteEndpoint()
        ..initialize(
          server,
          'note',
          null,
        ),
      'people': _iqqt4psm.PeopleEndpoint()
        ..initialize(
          server,
          'people',
          null,
        ),
      'photo': _ihuw68ce.PhotoEndpoint()
        ..initialize(
          server,
          'photo',
          null,
        ),
      'place': _ilyqdzjc.PlaceEndpoint()
        ..initialize(
          server,
          'place',
          null,
        ),
      'profile': _i2cx2pww.ProfileEndpoint()
        ..initialize(
          server,
          'profile',
          null,
        ),
      'story': _iiu4mi32.StoryEndpoint()
        ..initialize(
          server,
          'story',
          null,
        ),
    };
    connectors['emailIdp'] = _is.EndpointConnector(
      name: 'emailIdp',
      endpoint: endpoints['emailIdp']!,
      methodConnectors: {
        'startOtpLogin': _is.MethodConnector(
          name: 'startOtpLogin',
          params: {
            'email': _is.ParameterDescription(
              name: 'email',
              type: _is.getType<String>(),
              nullable: false,
            ),
          },
          call:
              (
                _is.Session session,
                Map<String, dynamic> params,
              ) async => (endpoints['emailIdp'] as _iuc1hd5t.EmailIdpEndpoint)
                  .startOtpLogin(
                    session,
                    email: params['email'],
                  ),
        ),
        'verifyOtpLoginCode': _is.MethodConnector(
          name: 'verifyOtpLoginCode',
          params: {
            'otpLoginRequestId': _is.ParameterDescription(
              name: 'otpLoginRequestId',
              type: _is.getType<_is.UuidValue>(),
              nullable: false,
            ),
            'verificationCode': _is.ParameterDescription(
              name: 'verificationCode',
              type: _is.getType<String>(),
              nullable: false,
            ),
          },
          call:
              (
                _is.Session session,
                Map<String, dynamic> params,
              ) async => (endpoints['emailIdp'] as _iuc1hd5t.EmailIdpEndpoint)
                  .verifyOtpLoginCode(
                    session,
                    otpLoginRequestId: params['otpLoginRequestId'],
                    verificationCode: params['verificationCode'],
                  ),
        ),
        'finishOtpLogin': _is.MethodConnector(
          name: 'finishOtpLogin',
          params: {
            'otpLoginToken': _is.ParameterDescription(
              name: 'otpLoginToken',
              type: _is.getType<String>(),
              nullable: false,
            ),
          },
          call:
              (
                _is.Session session,
                Map<String, dynamic> params,
              ) async => (endpoints['emailIdp'] as _iuc1hd5t.EmailIdpEndpoint)
                  .finishOtpLogin(
                    session,
                    otpLoginToken: params['otpLoginToken'],
                  ),
        ),
        'finishOtpRegistration': _is.MethodConnector(
          name: 'finishOtpRegistration',
          params: {
            'otpLoginToken': _is.ParameterDescription(
              name: 'otpLoginToken',
              type: _is.getType<String>(),
              nullable: false,
            ),
            'password': _is.ParameterDescription(
              name: 'password',
              type: _is.getType<String?>(),
              nullable: true,
            ),
          },
          call:
              (
                _is.Session session,
                Map<String, dynamic> params,
              ) async => (endpoints['emailIdp'] as _iuc1hd5t.EmailIdpEndpoint)
                  .finishOtpRegistration(
                    session,
                    otpLoginToken: params['otpLoginToken'],
                    password: params['password'],
                  ),
        ),
        'login': _is.MethodConnector(
          name: 'login',
          params: {
            'email': _is.ParameterDescription(
              name: 'email',
              type: _is.getType<String>(),
              nullable: false,
            ),
            'password': _is.ParameterDescription(
              name: 'password',
              type: _is.getType<String>(),
              nullable: false,
            ),
          },
          call:
              (
                _is.Session session,
                Map<String, dynamic> params,
              ) async =>
                  (endpoints['emailIdp'] as _iuc1hd5t.EmailIdpEndpoint).login(
                    session,
                    email: params['email'],
                    password: params['password'],
                  ),
        ),
        'startRegistration': _is.MethodConnector(
          name: 'startRegistration',
          params: {
            'email': _is.ParameterDescription(
              name: 'email',
              type: _is.getType<String>(),
              nullable: false,
            ),
          },
          call:
              (
                _is.Session session,
                Map<String, dynamic> params,
              ) async => (endpoints['emailIdp'] as _iuc1hd5t.EmailIdpEndpoint)
                  .startRegistration(
                    session,
                    email: params['email'],
                  ),
        ),
        'verifyRegistrationCode': _is.MethodConnector(
          name: 'verifyRegistrationCode',
          params: {
            'accountRequestId': _is.ParameterDescription(
              name: 'accountRequestId',
              type: _is.getType<_is.UuidValue>(),
              nullable: false,
            ),
            'verificationCode': _is.ParameterDescription(
              name: 'verificationCode',
              type: _is.getType<String>(),
              nullable: false,
            ),
          },
          call:
              (
                _is.Session session,
                Map<String, dynamic> params,
              ) async => (endpoints['emailIdp'] as _iuc1hd5t.EmailIdpEndpoint)
                  .verifyRegistrationCode(
                    session,
                    accountRequestId: params['accountRequestId'],
                    verificationCode: params['verificationCode'],
                  ),
        ),
        'finishRegistration': _is.MethodConnector(
          name: 'finishRegistration',
          params: {
            'registrationToken': _is.ParameterDescription(
              name: 'registrationToken',
              type: _is.getType<String>(),
              nullable: false,
            ),
            'password': _is.ParameterDescription(
              name: 'password',
              type: _is.getType<String>(),
              nullable: false,
            ),
          },
          call:
              (
                _is.Session session,
                Map<String, dynamic> params,
              ) async => (endpoints['emailIdp'] as _iuc1hd5t.EmailIdpEndpoint)
                  .finishRegistration(
                    session,
                    registrationToken: params['registrationToken'],
                    password: params['password'],
                  ),
        ),
        'startPasswordReset': _is.MethodConnector(
          name: 'startPasswordReset',
          params: {
            'email': _is.ParameterDescription(
              name: 'email',
              type: _is.getType<String>(),
              nullable: false,
            ),
          },
          call:
              (
                _is.Session session,
                Map<String, dynamic> params,
              ) async => (endpoints['emailIdp'] as _iuc1hd5t.EmailIdpEndpoint)
                  .startPasswordReset(
                    session,
                    email: params['email'],
                  ),
        ),
        'verifyPasswordResetCode': _is.MethodConnector(
          name: 'verifyPasswordResetCode',
          params: {
            'passwordResetRequestId': _is.ParameterDescription(
              name: 'passwordResetRequestId',
              type: _is.getType<_is.UuidValue>(),
              nullable: false,
            ),
            'verificationCode': _is.ParameterDescription(
              name: 'verificationCode',
              type: _is.getType<String>(),
              nullable: false,
            ),
          },
          call:
              (
                _is.Session session,
                Map<String, dynamic> params,
              ) async => (endpoints['emailIdp'] as _iuc1hd5t.EmailIdpEndpoint)
                  .verifyPasswordResetCode(
                    session,
                    passwordResetRequestId: params['passwordResetRequestId'],
                    verificationCode: params['verificationCode'],
                  ),
        ),
        'finishPasswordReset': _is.MethodConnector(
          name: 'finishPasswordReset',
          params: {
            'finishPasswordResetToken': _is.ParameterDescription(
              name: 'finishPasswordResetToken',
              type: _is.getType<String>(),
              nullable: false,
            ),
            'newPassword': _is.ParameterDescription(
              name: 'newPassword',
              type: _is.getType<String>(),
              nullable: false,
            ),
          },
          call:
              (
                _is.Session session,
                Map<String, dynamic> params,
              ) async => (endpoints['emailIdp'] as _iuc1hd5t.EmailIdpEndpoint)
                  .finishPasswordReset(
                    session,
                    finishPasswordResetToken:
                        params['finishPasswordResetToken'],
                    newPassword: params['newPassword'],
                  ),
        ),
        'hasAccount': _is.MethodConnector(
          name: 'hasAccount',
          params: {},
          call:
              (
                _is.Session session,
                Map<String, dynamic> params,
              ) async => (endpoints['emailIdp'] as _iuc1hd5t.EmailIdpEndpoint)
                  .hasAccount(session),
        ),
      },
    );
    connectors['jwtRefresh'] = _is.EndpointConnector(
      name: 'jwtRefresh',
      endpoint: endpoints['jwtRefresh']!,
      methodConnectors: {
        'refreshAccessToken': _is.MethodConnector(
          name: 'refreshAccessToken',
          params: {
            'refreshToken': _is.ParameterDescription(
              name: 'refreshToken',
              type: _is.getType<String?>(),
              nullable: true,
            ),
          },
          call:
              (
                _is.Session session,
                Map<String, dynamic> params,
              ) async =>
                  (endpoints['jwtRefresh'] as _inwq3ztq.JwtRefreshEndpoint)
                      .refreshAccessToken(
                        session,
                        refreshToken: params['refreshToken'],
                      ),
        ),
      },
    );
    connectors['family'] = _is.EndpointConnector(
      name: 'family',
      endpoint: endpoints['family']!,
      methodConnectors: {
        'createRoot': _is.MethodConnector(
          name: 'createRoot',
          params: {
            'name': _is.ParameterDescription(
              name: 'name',
              type: _is.getType<String>(),
              nullable: false,
            ),
          },
          call:
              (
                _is.Session session,
                Map<String, dynamic> params,
              ) async =>
                  (endpoints['family'] as _ibe5smjw.FamilyEndpoint).createRoot(
                    session,
                    params['name'],
                  ),
        ),
        'listMine': _is.MethodConnector(
          name: 'listMine',
          params: {},
          call:
              (
                _is.Session session,
                Map<String, dynamic> params,
              ) async => (endpoints['family'] as _ibe5smjw.FamilyEndpoint)
                  .listMine(session),
        ),
        'listStewarded': _is.MethodConnector(
          name: 'listStewarded',
          params: {},
          call:
              (
                _is.Session session,
                Map<String, dynamic> params,
              ) async => (endpoints['family'] as _ibe5smjw.FamilyEndpoint)
                  .listStewarded(session),
        ),
        'listTree': _is.MethodConnector(
          name: 'listTree',
          params: {
            'familyId': _is.ParameterDescription(
              name: 'familyId',
              type: _is.getType<_is.UuidValue>(),
              nullable: false,
            ),
          },
          call:
              (
                _is.Session session,
                Map<String, dynamic> params,
              ) async =>
                  (endpoints['family'] as _ibe5smjw.FamilyEndpoint).listTree(
                    session,
                    params['familyId'],
                  ),
        ),
        'listMembers': _is.MethodConnector(
          name: 'listMembers',
          params: {
            'familyId': _is.ParameterDescription(
              name: 'familyId',
              type: _is.getType<_is.UuidValue>(),
              nullable: false,
            ),
          },
          call:
              (
                _is.Session session,
                Map<String, dynamic> params,
              ) async =>
                  (endpoints['family'] as _ibe5smjw.FamilyEndpoint).listMembers(
                    session,
                    params['familyId'],
                  ),
        ),
        'directory': _is.MethodConnector(
          name: 'directory',
          params: {},
          call:
              (
                _is.Session session,
                Map<String, dynamic> params,
              ) async => (endpoints['family'] as _ibe5smjw.FamilyEndpoint)
                  .directory(session),
        ),
        'detail': _is.MethodConnector(
          name: 'detail',
          params: {
            'familyId': _is.ParameterDescription(
              name: 'familyId',
              type: _is.getType<_is.UuidValue>(),
              nullable: false,
            ),
          },
          call:
              (
                _is.Session session,
                Map<String, dynamic> params,
              ) async =>
                  (endpoints['family'] as _ibe5smjw.FamilyEndpoint).detail(
                    session,
                    params['familyId'],
                  ),
        ),
        'rename': _is.MethodConnector(
          name: 'rename',
          params: {
            'familyId': _is.ParameterDescription(
              name: 'familyId',
              type: _is.getType<_is.UuidValue>(),
              nullable: false,
            ),
            'name': _is.ParameterDescription(
              name: 'name',
              type: _is.getType<String>(),
              nullable: false,
            ),
          },
          call:
              (
                _is.Session session,
                Map<String, dynamic> params,
              ) async =>
                  (endpoints['family'] as _ibe5smjw.FamilyEndpoint).rename(
                    session,
                    params['familyId'],
                    params['name'],
                  ),
        ),
        'addCoOwner': _is.MethodConnector(
          name: 'addCoOwner',
          params: {
            'familyId': _is.ParameterDescription(
              name: 'familyId',
              type: _is.getType<_is.UuidValue>(),
              nullable: false,
            ),
            'userId': _is.ParameterDescription(
              name: 'userId',
              type: _is.getType<_is.UuidValue>(),
              nullable: false,
            ),
          },
          call:
              (
                _is.Session session,
                Map<String, dynamic> params,
              ) async =>
                  (endpoints['family'] as _ibe5smjw.FamilyEndpoint).addCoOwner(
                    session,
                    params['familyId'],
                    params['userId'],
                  ),
        ),
        'removeCoOwner': _is.MethodConnector(
          name: 'removeCoOwner',
          params: {
            'familyId': _is.ParameterDescription(
              name: 'familyId',
              type: _is.getType<_is.UuidValue>(),
              nullable: false,
            ),
            'userId': _is.ParameterDescription(
              name: 'userId',
              type: _is.getType<_is.UuidValue>(),
              nullable: false,
            ),
          },
          call:
              (
                _is.Session session,
                Map<String, dynamic> params,
              ) async => (endpoints['family'] as _ibe5smjw.FamilyEndpoint)
                  .removeCoOwner(
                    session,
                    params['familyId'],
                    params['userId'],
                  ),
        ),
        'transferOwnership': _is.MethodConnector(
          name: 'transferOwnership',
          params: {
            'familyId': _is.ParameterDescription(
              name: 'familyId',
              type: _is.getType<_is.UuidValue>(),
              nullable: false,
            ),
            'newOwnerUserId': _is.ParameterDescription(
              name: 'newOwnerUserId',
              type: _is.getType<_is.UuidValue>(),
              nullable: false,
            ),
            'formerOwnerBecomes': _is.ParameterDescription(
              name: 'formerOwnerBecomes',
              type: _is.getType<_ic4z8goi.MembershipRole>(),
              nullable: false,
            ),
          },
          call:
              (
                _is.Session session,
                Map<String, dynamic> params,
              ) async => (endpoints['family'] as _ibe5smjw.FamilyEndpoint)
                  .transferOwnership(
                    session,
                    params['familyId'],
                    params['newOwnerUserId'],
                    params['formerOwnerBecomes'],
                  ),
        ),
        'removeMember': _is.MethodConnector(
          name: 'removeMember',
          params: {
            'familyId': _is.ParameterDescription(
              name: 'familyId',
              type: _is.getType<_is.UuidValue>(),
              nullable: false,
            ),
            'userId': _is.ParameterDescription(
              name: 'userId',
              type: _is.getType<_is.UuidValue>(),
              nullable: false,
            ),
          },
          call:
              (
                _is.Session session,
                Map<String, dynamic> params,
              ) async => (endpoints['family'] as _ibe5smjw.FamilyEndpoint)
                  .removeMember(
                    session,
                    params['familyId'],
                    params['userId'],
                  ),
        ),
        'softDelete': _is.MethodConnector(
          name: 'softDelete',
          params: {
            'familyId': _is.ParameterDescription(
              name: 'familyId',
              type: _is.getType<_is.UuidValue>(),
              nullable: false,
            ),
          },
          call:
              (
                _is.Session session,
                Map<String, dynamic> params,
              ) async =>
                  (endpoints['family'] as _ibe5smjw.FamilyEndpoint).softDelete(
                    session,
                    params['familyId'],
                  ),
        ),
        'recover': _is.MethodConnector(
          name: 'recover',
          params: {
            'familyId': _is.ParameterDescription(
              name: 'familyId',
              type: _is.getType<_is.UuidValue>(),
              nullable: false,
            ),
          },
          call:
              (
                _is.Session session,
                Map<String, dynamic> params,
              ) async =>
                  (endpoints['family'] as _ibe5smjw.FamilyEndpoint).recover(
                    session,
                    params['familyId'],
                  ),
        ),
        'setOrigin': _is.MethodConnector(
          name: 'setOrigin',
          params: {
            'familyId': _is.ParameterDescription(
              name: 'familyId',
              type: _is.getType<_is.UuidValue>(),
              nullable: false,
            ),
            'storyId': _is.ParameterDescription(
              name: 'storyId',
              type: _is.getType<_is.UuidValue>(),
              nullable: false,
            ),
          },
          call:
              (
                _is.Session session,
                Map<String, dynamic> params,
              ) async =>
                  (endpoints['family'] as _ibe5smjw.FamilyEndpoint).setOrigin(
                    session,
                    params['familyId'],
                    params['storyId'],
                  ),
        ),
        'listOriginDependents': _is.MethodConnector(
          name: 'listOriginDependents',
          params: {
            'storyId': _is.ParameterDescription(
              name: 'storyId',
              type: _is.getType<_is.UuidValue>(),
              nullable: false,
            ),
          },
          call:
              (
                _is.Session session,
                Map<String, dynamic> params,
              ) async => (endpoints['family'] as _ibe5smjw.FamilyEndpoint)
                  .listOriginDependents(
                    session,
                    params['storyId'],
                  ),
        ),
        'createBranch': _is.MethodConnector(
          name: 'createBranch',
          params: {
            'parentFamilyId': _is.ParameterDescription(
              name: 'parentFamilyId',
              type: _is.getType<_is.UuidValue>(),
              nullable: false,
            ),
            'originStoryId': _is.ParameterDescription(
              name: 'originStoryId',
              type: _is.getType<_is.UuidValue>(),
              nullable: false,
            ),
            'name': _is.ParameterDescription(
              name: 'name',
              type: _is.getType<String>(),
              nullable: false,
            ),
            'branchYear': _is.ParameterDescription(
              name: 'branchYear',
              type: _is.getType<int>(),
              nullable: false,
            ),
            'ownerUserId': _is.ParameterDescription(
              name: 'ownerUserId',
              type: _is.getType<_is.UuidValue>(),
              nullable: false,
            ),
            'personIds': _is.ParameterDescription(
              name: 'personIds',
              type: _is.getType<List<_is.UuidValue>>(),
              nullable: false,
            ),
          },
          call:
              (
                _is.Session session,
                Map<String, dynamic> params,
              ) async => (endpoints['family'] as _ibe5smjw.FamilyEndpoint)
                  .createBranch(
                    session,
                    parentFamilyId: params['parentFamilyId'],
                    originStoryId: params['originStoryId'],
                    name: params['name'],
                    branchYear: params['branchYear'],
                    ownerUserId: params['ownerUserId'],
                    personIds: params['personIds'],
                  ),
        ),
        'startCoverUpload': _is.MethodConnector(
          name: 'startCoverUpload',
          params: {
            'familyId': _is.ParameterDescription(
              name: 'familyId',
              type: _is.getType<_is.UuidValue>(),
              nullable: false,
            ),
            'mimeType': _is.ParameterDescription(
              name: 'mimeType',
              type: _is.getType<String>(),
              nullable: false,
            ),
            'byteLength': _is.ParameterDescription(
              name: 'byteLength',
              type: _is.getType<int>(),
              nullable: false,
            ),
          },
          call:
              (
                _is.Session session,
                Map<String, dynamic> params,
              ) async => (endpoints['family'] as _ibe5smjw.FamilyEndpoint)
                  .startCoverUpload(
                    session,
                    params['familyId'],
                    params['mimeType'],
                    params['byteLength'],
                  ),
        ),
        'finishCoverUpload': _is.MethodConnector(
          name: 'finishCoverUpload',
          params: {
            'familyId': _is.ParameterDescription(
              name: 'familyId',
              type: _is.getType<_is.UuidValue>(),
              nullable: false,
            ),
            'key': _is.ParameterDescription(
              name: 'key',
              type: _is.getType<String>(),
              nullable: false,
            ),
          },
          call:
              (
                _is.Session session,
                Map<String, dynamic> params,
              ) async => (endpoints['family'] as _ibe5smjw.FamilyEndpoint)
                  .finishCoverUpload(
                    session,
                    params['familyId'],
                    params['key'],
                  ),
        ),
        'clearCover': _is.MethodConnector(
          name: 'clearCover',
          params: {
            'familyId': _is.ParameterDescription(
              name: 'familyId',
              type: _is.getType<_is.UuidValue>(),
              nullable: false,
            ),
          },
          call:
              (
                _is.Session session,
                Map<String, dynamic> params,
              ) async =>
                  (endpoints['family'] as _ibe5smjw.FamilyEndpoint).clearCover(
                    session,
                    params['familyId'],
                  ),
        ),
      },
    );
    connectors['invite'] = _is.EndpointConnector(
      name: 'invite',
      endpoint: endpoints['invite']!,
      methodConnectors: {
        'create': _is.MethodConnector(
          name: 'create',
          params: {
            'familyId': _is.ParameterDescription(
              name: 'familyId',
              type: _is.getType<_is.UuidValue>(),
              nullable: false,
            ),
            'email': _is.ParameterDescription(
              name: 'email',
              type: _is.getType<String?>(),
              nullable: true,
            ),
            'personId': _is.ParameterDescription(
              name: 'personId',
              type: _is.getType<_is.UuidValue?>(),
              nullable: true,
            ),
          },
          call:
              (
                _is.Session session,
                Map<String, dynamic> params,
              ) async =>
                  (endpoints['invite'] as _ip80nve4.InviteEndpoint).create(
                    session,
                    params['familyId'],
                    email: params['email'],
                    personId: params['personId'],
                  ),
        ),
        'sendEmail': _is.MethodConnector(
          name: 'sendEmail',
          params: {
            'inviteId': _is.ParameterDescription(
              name: 'inviteId',
              type: _is.getType<_is.UuidValue>(),
              nullable: false,
            ),
            'token': _is.ParameterDescription(
              name: 'token',
              type: _is.getType<String>(),
              nullable: false,
            ),
          },
          call:
              (
                _is.Session session,
                Map<String, dynamic> params,
              ) async =>
                  (endpoints['invite'] as _ip80nve4.InviteEndpoint).sendEmail(
                    session,
                    params['inviteId'],
                    params['token'],
                  ),
        ),
        'accept': _is.MethodConnector(
          name: 'accept',
          params: {
            'token': _is.ParameterDescription(
              name: 'token',
              type: _is.getType<String>(),
              nullable: false,
            ),
          },
          call:
              (
                _is.Session session,
                Map<String, dynamic> params,
              ) async =>
                  (endpoints['invite'] as _ip80nve4.InviteEndpoint).accept(
                    session,
                    params['token'],
                  ),
        ),
        'resend': _is.MethodConnector(
          name: 'resend',
          params: {
            'inviteId': _is.ParameterDescription(
              name: 'inviteId',
              type: _is.getType<_is.UuidValue>(),
              nullable: false,
            ),
          },
          call:
              (
                _is.Session session,
                Map<String, dynamic> params,
              ) async =>
                  (endpoints['invite'] as _ip80nve4.InviteEndpoint).resend(
                    session,
                    params['inviteId'],
                  ),
        ),
        'revoke': _is.MethodConnector(
          name: 'revoke',
          params: {
            'inviteId': _is.ParameterDescription(
              name: 'inviteId',
              type: _is.getType<_is.UuidValue>(),
              nullable: false,
            ),
          },
          call:
              (
                _is.Session session,
                Map<String, dynamic> params,
              ) async =>
                  (endpoints['invite'] as _ip80nve4.InviteEndpoint).revoke(
                    session,
                    params['inviteId'],
                  ),
        ),
      },
    );
    connectors['invitePublic'] = _is.EndpointConnector(
      name: 'invitePublic',
      endpoint: endpoints['invitePublic']!,
      methodConnectors: {
        'preview': _is.MethodConnector(
          name: 'preview',
          params: {
            'token': _is.ParameterDescription(
              name: 'token',
              type: _is.getType<String>(),
              nullable: false,
            ),
          },
          call:
              (
                _is.Session session,
                Map<String, dynamic> params,
              ) async =>
                  (endpoints['invitePublic'] as _ip1i0qvr.InvitePublicEndpoint)
                      .preview(
                        session,
                        params['token'],
                      ),
        ),
      },
    );
    connectors['live'] = _is.EndpointConnector(
      name: 'live',
      endpoint: endpoints['live']!,
      methodConnectors: {
        'watchFamily': _is.MethodStreamConnector(
          name: 'watchFamily',
          params: {
            'familyId': _is.ParameterDescription(
              name: 'familyId',
              type: _is.getType<_is.UuidValue>(),
              nullable: false,
            ),
          },
          streamParams: {},
          returnType: _is.MethodStreamReturnType.streamType,
          call:
              (
                _is.Session session,
                Map<String, dynamic> params,
                Map<String, Stream> streamParams,
              ) => (endpoints['live'] as _ixgr9pqx.LiveEndpoint).watchFamily(
                session,
                params['familyId'],
              ),
        ),
        'watchStory': _is.MethodStreamConnector(
          name: 'watchStory',
          params: {
            'storyId': _is.ParameterDescription(
              name: 'storyId',
              type: _is.getType<_is.UuidValue>(),
              nullable: false,
            ),
          },
          streamParams: {},
          returnType: _is.MethodStreamReturnType.streamType,
          call:
              (
                _is.Session session,
                Map<String, dynamic> params,
                Map<String, Stream> streamParams,
              ) => (endpoints['live'] as _ixgr9pqx.LiveEndpoint).watchStory(
                session,
                params['storyId'],
              ),
        ),
      },
    );
    connectors['media'] = _is.EndpointConnector(
      name: 'media',
      endpoint: endpoints['media']!,
      methodConnectors: {
        'get': _is.MethodConnector(
          name: 'get',
          params: {
            'key': _is.ParameterDescription(
              name: 'key',
              type: _is.getType<String>(),
              nullable: false,
            ),
          },
          call:
              (
                _is.Session session,
                Map<String, dynamic> params,
              ) async => (endpoints['media'] as _iaymoujt.MediaEndpoint).get(
                session,
                params['key'],
              ),
        ),
        'getMany': _is.MethodConnector(
          name: 'getMany',
          params: {
            'keys': _is.ParameterDescription(
              name: 'keys',
              type: _is.getType<List<String>>(),
              nullable: false,
            ),
          },
          call:
              (
                _is.Session session,
                Map<String, dynamic> params,
              ) async =>
                  (endpoints['media'] as _iaymoujt.MediaEndpoint).getMany(
                    session,
                    params['keys'],
                  ),
        ),
      },
    );
    connectors['note'] = _is.EndpointConnector(
      name: 'note',
      endpoint: endpoints['note']!,
      methodConnectors: {
        'listForStory': _is.MethodConnector(
          name: 'listForStory',
          params: {
            'storyId': _is.ParameterDescription(
              name: 'storyId',
              type: _is.getType<_is.UuidValue>(),
              nullable: false,
            ),
            'kind': _is.ParameterDescription(
              name: 'kind',
              type: _is.getType<_ija2hb8o.NoteKind?>(),
              nullable: true,
            ),
          },
          call:
              (
                _is.Session session,
                Map<String, dynamic> params,
              ) async =>
                  (endpoints['note'] as _i4n3t746.NoteEndpoint).listForStory(
                    session,
                    params['storyId'],
                    kind: params['kind'],
                  ),
        ),
        'create': _is.MethodConnector(
          name: 'create',
          params: {
            'storyId': _is.ParameterDescription(
              name: 'storyId',
              type: _is.getType<_is.UuidValue>(),
              nullable: false,
            ),
            'kind': _is.ParameterDescription(
              name: 'kind',
              type: _is.getType<_ija2hb8o.NoteKind>(),
              nullable: false,
            ),
            'body': _is.ParameterDescription(
              name: 'body',
              type: _is.getType<String>(),
              nullable: false,
            ),
          },
          call:
              (
                _is.Session session,
                Map<String, dynamic> params,
              ) async => (endpoints['note'] as _i4n3t746.NoteEndpoint).create(
                session,
                params['storyId'],
                params['kind'],
                params['body'],
              ),
        ),
        'update': _is.MethodConnector(
          name: 'update',
          params: {
            'noteId': _is.ParameterDescription(
              name: 'noteId',
              type: _is.getType<_is.UuidValue>(),
              nullable: false,
            ),
            'body': _is.ParameterDescription(
              name: 'body',
              type: _is.getType<String>(),
              nullable: false,
            ),
          },
          call:
              (
                _is.Session session,
                Map<String, dynamic> params,
              ) async => (endpoints['note'] as _i4n3t746.NoteEndpoint).update(
                session,
                params['noteId'],
                params['body'],
              ),
        ),
        'delete': _is.MethodConnector(
          name: 'delete',
          params: {
            'noteId': _is.ParameterDescription(
              name: 'noteId',
              type: _is.getType<_is.UuidValue>(),
              nullable: false,
            ),
          },
          call:
              (
                _is.Session session,
                Map<String, dynamic> params,
              ) async => (endpoints['note'] as _i4n3t746.NoteEndpoint).delete(
                session,
                params['noteId'],
              ),
        ),
      },
    );
    connectors['people'] = _is.EndpointConnector(
      name: 'people',
      endpoint: endpoints['people']!,
      methodConnectors: {
        'listFamily': _is.MethodConnector(
          name: 'listFamily',
          params: {
            'familyId': _is.ParameterDescription(
              name: 'familyId',
              type: _is.getType<_is.UuidValue>(),
              nullable: false,
            ),
          },
          call:
              (
                _is.Session session,
                Map<String, dynamic> params,
              ) async =>
                  (endpoints['people'] as _iqqt4psm.PeopleEndpoint).listFamily(
                    session,
                    params['familyId'],
                  ),
        ),
        'listTree': _is.MethodConnector(
          name: 'listTree',
          params: {
            'familyId': _is.ParameterDescription(
              name: 'familyId',
              type: _is.getType<_is.UuidValue>(),
              nullable: false,
            ),
          },
          call:
              (
                _is.Session session,
                Map<String, dynamic> params,
              ) async =>
                  (endpoints['people'] as _iqqt4psm.PeopleEndpoint).listTree(
                    session,
                    params['familyId'],
                  ),
        ),
        'create': _is.MethodConnector(
          name: 'create',
          params: {
            'familyId': _is.ParameterDescription(
              name: 'familyId',
              type: _is.getType<_is.UuidValue>(),
              nullable: false,
            ),
            'input': _is.ParameterDescription(
              name: 'input',
              type: _is.getType<_imyz5bcs.PersonWriteDto>(),
              nullable: false,
            ),
            'picture': _is.ParameterDescription(
              name: 'picture',
              type: _is.getType<_idt.ByteData?>(),
              nullable: true,
            ),
          },
          call:
              (
                _is.Session session,
                Map<String, dynamic> params,
              ) async =>
                  (endpoints['people'] as _iqqt4psm.PeopleEndpoint).create(
                    session,
                    params['familyId'],
                    params['input'],
                    params['picture'],
                  ),
        ),
        'forEdit': _is.MethodConnector(
          name: 'forEdit',
          params: {
            'personId': _is.ParameterDescription(
              name: 'personId',
              type: _is.getType<_is.UuidValue>(),
              nullable: false,
            ),
          },
          call:
              (
                _is.Session session,
                Map<String, dynamic> params,
              ) async =>
                  (endpoints['people'] as _iqqt4psm.PeopleEndpoint).forEdit(
                    session,
                    params['personId'],
                  ),
        ),
        'profile': _is.MethodConnector(
          name: 'profile',
          params: {
            'personId': _is.ParameterDescription(
              name: 'personId',
              type: _is.getType<_is.UuidValue>(),
              nullable: false,
            ),
          },
          call:
              (
                _is.Session session,
                Map<String, dynamic> params,
              ) async =>
                  (endpoints['people'] as _iqqt4psm.PeopleEndpoint).profile(
                    session,
                    params['personId'],
                  ),
        ),
        'update': _is.MethodConnector(
          name: 'update',
          params: {
            'personId': _is.ParameterDescription(
              name: 'personId',
              type: _is.getType<_is.UuidValue>(),
              nullable: false,
            ),
            'input': _is.ParameterDescription(
              name: 'input',
              type: _is.getType<_imyz5bcs.PersonWriteDto>(),
              nullable: false,
            ),
            'picture': _is.ParameterDescription(
              name: 'picture',
              type: _is.getType<_idt.ByteData?>(),
              nullable: true,
            ),
          },
          call:
              (
                _is.Session session,
                Map<String, dynamic> params,
              ) async =>
                  (endpoints['people'] as _iqqt4psm.PeopleEndpoint).update(
                    session,
                    params['personId'],
                    params['input'],
                    params['picture'],
                  ),
        ),
        'listUnlinked': _is.MethodConnector(
          name: 'listUnlinked',
          params: {
            'familyId': _is.ParameterDescription(
              name: 'familyId',
              type: _is.getType<_is.UuidValue>(),
              nullable: false,
            ),
          },
          call:
              (
                _is.Session session,
                Map<String, dynamic> params,
              ) async => (endpoints['people'] as _iqqt4psm.PeopleEndpoint)
                  .listUnlinked(
                    session,
                    params['familyId'],
                  ),
        ),
        'isHomeFamilySteward': _is.MethodConnector(
          name: 'isHomeFamilySteward',
          params: {
            'familyId': _is.ParameterDescription(
              name: 'familyId',
              type: _is.getType<_is.UuidValue>(),
              nullable: false,
            ),
          },
          call:
              (
                _is.Session session,
                Map<String, dynamic> params,
              ) async => (endpoints['people'] as _iqqt4psm.PeopleEndpoint)
                  .isHomeFamilySteward(
                    session,
                    params['familyId'],
                  ),
        ),
        'markPassedAway': _is.MethodConnector(
          name: 'markPassedAway',
          params: {
            'personId': _is.ParameterDescription(
              name: 'personId',
              type: _is.getType<_is.UuidValue>(),
              nullable: false,
            ),
            'value': _is.ParameterDescription(
              name: 'value',
              type: _is.getType<bool>(),
              nullable: false,
            ),
          },
          call:
              (
                _is.Session session,
                Map<String, dynamic> params,
              ) async => (endpoints['people'] as _iqqt4psm.PeopleEndpoint)
                  .markPassedAway(
                    session,
                    params['personId'],
                    params['value'],
                  ),
        ),
        'delete': _is.MethodConnector(
          name: 'delete',
          params: {
            'personId': _is.ParameterDescription(
              name: 'personId',
              type: _is.getType<_is.UuidValue>(),
              nullable: false,
            ),
          },
          call:
              (
                _is.Session session,
                Map<String, dynamic> params,
              ) async =>
                  (endpoints['people'] as _iqqt4psm.PeopleEndpoint).delete(
                    session,
                    params['personId'],
                  ),
        ),
      },
    );
    connectors['photo'] = _is.EndpointConnector(
      name: 'photo',
      endpoint: endpoints['photo']!,
      methodConnectors: {
        'list': _is.MethodConnector(
          name: 'list',
          params: {
            'storyId': _is.ParameterDescription(
              name: 'storyId',
              type: _is.getType<_is.UuidValue>(),
              nullable: false,
            ),
          },
          call:
              (
                _is.Session session,
                Map<String, dynamic> params,
              ) async => (endpoints['photo'] as _ihuw68ce.PhotoEndpoint).list(
                session,
                params['storyId'],
              ),
        ),
        'startUpload': _is.MethodConnector(
          name: 'startUpload',
          params: {
            'storyId': _is.ParameterDescription(
              name: 'storyId',
              type: _is.getType<_is.UuidValue>(),
              nullable: false,
            ),
            'mimeType': _is.ParameterDescription(
              name: 'mimeType',
              type: _is.getType<String>(),
              nullable: false,
            ),
            'byteLength': _is.ParameterDescription(
              name: 'byteLength',
              type: _is.getType<int>(),
              nullable: false,
            ),
          },
          call:
              (
                _is.Session session,
                Map<String, dynamic> params,
              ) async =>
                  (endpoints['photo'] as _ihuw68ce.PhotoEndpoint).startUpload(
                    session,
                    params['storyId'],
                    params['mimeType'],
                    params['byteLength'],
                  ),
        ),
        'finishUpload': _is.MethodConnector(
          name: 'finishUpload',
          params: {
            'storyId': _is.ParameterDescription(
              name: 'storyId',
              type: _is.getType<_is.UuidValue>(),
              nullable: false,
            ),
            'photoId': _is.ParameterDescription(
              name: 'photoId',
              type: _is.getType<_is.UuidValue>(),
              nullable: false,
            ),
            'sortOrder': _is.ParameterDescription(
              name: 'sortOrder',
              type: _is.getType<int>(),
              nullable: false,
            ),
          },
          call:
              (
                _is.Session session,
                Map<String, dynamic> params,
              ) async =>
                  (endpoints['photo'] as _ihuw68ce.PhotoEndpoint).finishUpload(
                    session,
                    params['storyId'],
                    params['photoId'],
                    params['sortOrder'],
                  ),
        ),
        'delete': _is.MethodConnector(
          name: 'delete',
          params: {
            'photoId': _is.ParameterDescription(
              name: 'photoId',
              type: _is.getType<_is.UuidValue>(),
              nullable: false,
            ),
          },
          call:
              (
                _is.Session session,
                Map<String, dynamic> params,
              ) async => (endpoints['photo'] as _ihuw68ce.PhotoEndpoint).delete(
                session,
                params['photoId'],
              ),
        ),
        'setHero': _is.MethodConnector(
          name: 'setHero',
          params: {
            'storyId': _is.ParameterDescription(
              name: 'storyId',
              type: _is.getType<_is.UuidValue>(),
              nullable: false,
            ),
            'photoId': _is.ParameterDescription(
              name: 'photoId',
              type: _is.getType<_is.UuidValue>(),
              nullable: false,
            ),
          },
          call:
              (
                _is.Session session,
                Map<String, dynamic> params,
              ) async =>
                  (endpoints['photo'] as _ihuw68ce.PhotoEndpoint).setHero(
                    session,
                    params['storyId'],
                    params['photoId'],
                  ),
        ),
      },
    );
    connectors['place'] = _is.EndpointConnector(
      name: 'place',
      endpoint: endpoints['place']!,
      methodConnectors: {
        'list': _is.MethodConnector(
          name: 'list',
          params: {
            'familyId': _is.ParameterDescription(
              name: 'familyId',
              type: _is.getType<_is.UuidValue>(),
              nullable: false,
            ),
          },
          call:
              (
                _is.Session session,
                Map<String, dynamic> params,
              ) async => (endpoints['place'] as _ilyqdzjc.PlaceEndpoint).list(
                session,
                params['familyId'],
              ),
        ),
        'favorites': _is.MethodConnector(
          name: 'favorites',
          params: {
            'familyId': _is.ParameterDescription(
              name: 'familyId',
              type: _is.getType<_is.UuidValue>(),
              nullable: false,
            ),
          },
          call:
              (
                _is.Session session,
                Map<String, dynamic> params,
              ) async =>
                  (endpoints['place'] as _ilyqdzjc.PlaceEndpoint).favorites(
                    session,
                    params['familyId'],
                  ),
        ),
        'recents': _is.MethodConnector(
          name: 'recents',
          params: {
            'familyId': _is.ParameterDescription(
              name: 'familyId',
              type: _is.getType<_is.UuidValue>(),
              nullable: false,
            ),
            'limit': _is.ParameterDescription(
              name: 'limit',
              type: _is.getType<int>(),
              nullable: false,
            ),
          },
          call:
              (
                _is.Session session,
                Map<String, dynamic> params,
              ) async =>
                  (endpoints['place'] as _ilyqdzjc.PlaceEndpoint).recents(
                    session,
                    params['familyId'],
                    limit: params['limit'],
                  ),
        ),
        'create': _is.MethodConnector(
          name: 'create',
          params: {
            'familyId': _is.ParameterDescription(
              name: 'familyId',
              type: _is.getType<_is.UuidValue>(),
              nullable: false,
            ),
            'input': _is.ParameterDescription(
              name: 'input',
              type: _is.getType<_iqvasz3a.PlaceInputDto>(),
              nullable: false,
            ),
          },
          call:
              (
                _is.Session session,
                Map<String, dynamic> params,
              ) async => (endpoints['place'] as _ilyqdzjc.PlaceEndpoint).create(
                session,
                params['familyId'],
                params['input'],
              ),
        ),
        'markUsed': _is.MethodConnector(
          name: 'markUsed',
          params: {
            'placeId': _is.ParameterDescription(
              name: 'placeId',
              type: _is.getType<_is.UuidValue>(),
              nullable: false,
            ),
          },
          call:
              (
                _is.Session session,
                Map<String, dynamic> params,
              ) async =>
                  (endpoints['place'] as _ilyqdzjc.PlaceEndpoint).markUsed(
                    session,
                    params['placeId'],
                  ),
        ),
        'setFavorite': _is.MethodConnector(
          name: 'setFavorite',
          params: {
            'placeId': _is.ParameterDescription(
              name: 'placeId',
              type: _is.getType<_is.UuidValue>(),
              nullable: false,
            ),
            'isFavorite': _is.ParameterDescription(
              name: 'isFavorite',
              type: _is.getType<bool>(),
              nullable: false,
            ),
          },
          call:
              (
                _is.Session session,
                Map<String, dynamic> params,
              ) async =>
                  (endpoints['place'] as _ilyqdzjc.PlaceEndpoint).setFavorite(
                    session,
                    params['placeId'],
                    params['isFavorite'],
                  ),
        ),
        'findByMapboxId': _is.MethodConnector(
          name: 'findByMapboxId',
          params: {
            'familyId': _is.ParameterDescription(
              name: 'familyId',
              type: _is.getType<_is.UuidValue>(),
              nullable: false,
            ),
            'mapboxPlaceId': _is.ParameterDescription(
              name: 'mapboxPlaceId',
              type: _is.getType<String>(),
              nullable: false,
            ),
          },
          call:
              (
                _is.Session session,
                Map<String, dynamic> params,
              ) async => (endpoints['place'] as _ilyqdzjc.PlaceEndpoint)
                  .findByMapboxId(
                    session,
                    params['familyId'],
                    params['mapboxPlaceId'],
                  ),
        ),
        'get': _is.MethodConnector(
          name: 'get',
          params: {
            'placeId': _is.ParameterDescription(
              name: 'placeId',
              type: _is.getType<_is.UuidValue>(),
              nullable: false,
            ),
          },
          call:
              (
                _is.Session session,
                Map<String, dynamic> params,
              ) async => (endpoints['place'] as _ilyqdzjc.PlaceEndpoint).get(
                session,
                params['placeId'],
              ),
        ),
      },
    );
    connectors['profile'] = _is.EndpointConnector(
      name: 'profile',
      endpoint: endpoints['profile']!,
      methodConnectors: {
        'me': _is.MethodConnector(
          name: 'me',
          params: {},
          call:
              (
                _is.Session session,
                Map<String, dynamic> params,
              ) async => (endpoints['profile'] as _i2cx2pww.ProfileEndpoint).me(
                session,
              ),
        ),
        'saveName': _is.MethodConnector(
          name: 'saveName',
          params: {
            'displayName': _is.ParameterDescription(
              name: 'displayName',
              type: _is.getType<String>(),
              nullable: false,
            ),
          },
          call:
              (
                _is.Session session,
                Map<String, dynamic> params,
              ) async =>
                  (endpoints['profile'] as _i2cx2pww.ProfileEndpoint).saveName(
                    session,
                    params['displayName'],
                  ),
        ),
        'saveAccount': _is.MethodConnector(
          name: 'saveAccount',
          params: {
            'displayName': _is.ParameterDescription(
              name: 'displayName',
              type: _is.getType<String>(),
              nullable: false,
            ),
            'birthDate': _is.ParameterDescription(
              name: 'birthDate',
              type: _is.getType<DateTime?>(),
              nullable: true,
            ),
            'birthPrecision': _is.ParameterDescription(
              name: 'birthPrecision',
              type: _is.getType<_ig52w51f.DatePrecision?>(),
              nullable: true,
            ),
            'birthVisibility': _is.ParameterDescription(
              name: 'birthVisibility',
              type: _is.getType<_i0rpsun5.BirthVisibility?>(),
              nullable: true,
            ),
            'about': _is.ParameterDescription(
              name: 'about',
              type: _is.getType<String?>(),
              nullable: true,
            ),
          },
          call:
              (
                _is.Session session,
                Map<String, dynamic> params,
              ) async => (endpoints['profile'] as _i2cx2pww.ProfileEndpoint)
                  .saveAccount(
                    session,
                    displayName: params['displayName'],
                    birthDate: params['birthDate'],
                    birthPrecision: params['birthPrecision'],
                    birthVisibility: params['birthVisibility'],
                    about: params['about'],
                  ),
        ),
        'saveAvatar': _is.MethodConnector(
          name: 'saveAvatar',
          params: {
            'jpeg': _is.ParameterDescription(
              name: 'jpeg',
              type: _is.getType<_idt.ByteData>(),
              nullable: false,
            ),
          },
          call:
              (
                _is.Session session,
                Map<String, dynamic> params,
              ) async => (endpoints['profile'] as _i2cx2pww.ProfileEndpoint)
                  .saveAvatar(
                    session,
                    params['jpeg'],
                  ),
        ),
        'clearAvatar': _is.MethodConnector(
          name: 'clearAvatar',
          params: {},
          call:
              (
                _is.Session session,
                Map<String, dynamic> params,
              ) async => (endpoints['profile'] as _i2cx2pww.ProfileEndpoint)
                  .clearAvatar(session),
        ),
      },
    );
    connectors['story'] = _is.EndpointConnector(
      name: 'story',
      endpoint: endpoints['story']!,
      methodConnectors: {
        'createDraft': _is.MethodConnector(
          name: 'createDraft',
          params: {
            'familyId': _is.ParameterDescription(
              name: 'familyId',
              type: _is.getType<_is.UuidValue>(),
              nullable: false,
            ),
            'input': _is.ParameterDescription(
              name: 'input',
              type: _is.getType<_iu03akf8.StoryWriteDto>(),
              nullable: false,
            ),
            'id': _is.ParameterDescription(
              name: 'id',
              type: _is.getType<_is.UuidValue?>(),
              nullable: true,
            ),
            'allowUndated': _is.ParameterDescription(
              name: 'allowUndated',
              type: _is.getType<bool>(),
              nullable: false,
            ),
          },
          call:
              (
                _is.Session session,
                Map<String, dynamic> params,
              ) async =>
                  (endpoints['story'] as _iiu4mi32.StoryEndpoint).createDraft(
                    session,
                    params['familyId'],
                    params['input'],
                    id: params['id'],
                    allowUndated: params['allowUndated'],
                  ),
        ),
        'updateDraft': _is.MethodConnector(
          name: 'updateDraft',
          params: {
            'storyId': _is.ParameterDescription(
              name: 'storyId',
              type: _is.getType<_is.UuidValue>(),
              nullable: false,
            ),
            'input': _is.ParameterDescription(
              name: 'input',
              type: _is.getType<_iu03akf8.StoryWriteDto>(),
              nullable: false,
            ),
          },
          call:
              (
                _is.Session session,
                Map<String, dynamic> params,
              ) async =>
                  (endpoints['story'] as _iiu4mi32.StoryEndpoint).updateDraft(
                    session,
                    params['storyId'],
                    params['input'],
                  ),
        ),
        'autosaveDraft': _is.MethodConnector(
          name: 'autosaveDraft',
          params: {
            'storyId': _is.ParameterDescription(
              name: 'storyId',
              type: _is.getType<_is.UuidValue>(),
              nullable: false,
            ),
            'input': _is.ParameterDescription(
              name: 'input',
              type: _is.getType<_iu03akf8.StoryWriteDto>(),
              nullable: false,
            ),
          },
          call:
              (
                _is.Session session,
                Map<String, dynamic> params,
              ) async =>
                  (endpoints['story'] as _iiu4mi32.StoryEndpoint).autosaveDraft(
                    session,
                    params['storyId'],
                    params['input'],
                  ),
        ),
        'get': _is.MethodConnector(
          name: 'get',
          params: {
            'storyId': _is.ParameterDescription(
              name: 'storyId',
              type: _is.getType<_is.UuidValue>(),
              nullable: false,
            ),
          },
          call:
              (
                _is.Session session,
                Map<String, dynamic> params,
              ) async => (endpoints['story'] as _iiu4mi32.StoryEndpoint).get(
                session,
                params['storyId'],
              ),
        ),
        'linkPerson': _is.MethodConnector(
          name: 'linkPerson',
          params: {
            'storyId': _is.ParameterDescription(
              name: 'storyId',
              type: _is.getType<_is.UuidValue>(),
              nullable: false,
            ),
            'personId': _is.ParameterDescription(
              name: 'personId',
              type: _is.getType<_is.UuidValue>(),
              nullable: false,
            ),
          },
          call:
              (
                _is.Session session,
                Map<String, dynamic> params,
              ) async =>
                  (endpoints['story'] as _iiu4mi32.StoryEndpoint).linkPerson(
                    session,
                    params['storyId'],
                    params['personId'],
                  ),
        ),
        'publish': _is.MethodConnector(
          name: 'publish',
          params: {
            'storyId': _is.ParameterDescription(
              name: 'storyId',
              type: _is.getType<_is.UuidValue>(),
              nullable: false,
            ),
          },
          call:
              (
                _is.Session session,
                Map<String, dynamic> params,
              ) async =>
                  (endpoints['story'] as _iiu4mi32.StoryEndpoint).publish(
                    session,
                    params['storyId'],
                  ),
        ),
        'getPublished': _is.MethodConnector(
          name: 'getPublished',
          params: {
            'storyId': _is.ParameterDescription(
              name: 'storyId',
              type: _is.getType<_is.UuidValue>(),
              nullable: false,
            ),
          },
          call:
              (
                _is.Session session,
                Map<String, dynamic> params,
              ) async =>
                  (endpoints['story'] as _iiu4mi32.StoryEndpoint).getPublished(
                    session,
                    params['storyId'],
                  ),
        ),
        'listMyDrafts': _is.MethodConnector(
          name: 'listMyDrafts',
          params: {
            'familyId': _is.ParameterDescription(
              name: 'familyId',
              type: _is.getType<_is.UuidValue>(),
              nullable: false,
            ),
          },
          call:
              (
                _is.Session session,
                Map<String, dynamic> params,
              ) async =>
                  (endpoints['story'] as _iiu4mi32.StoryEndpoint).listMyDrafts(
                    session,
                    params['familyId'],
                  ),
        ),
        'listPublished': _is.MethodConnector(
          name: 'listPublished',
          params: {
            'familyId': _is.ParameterDescription(
              name: 'familyId',
              type: _is.getType<_is.UuidValue>(),
              nullable: false,
            ),
          },
          call:
              (
                _is.Session session,
                Map<String, dynamic> params,
              ) async =>
                  (endpoints['story'] as _iiu4mi32.StoryEndpoint).listPublished(
                    session,
                    params['familyId'],
                  ),
        ),
        'listLatestPublished': _is.MethodConnector(
          name: 'listLatestPublished',
          params: {
            'familyId': _is.ParameterDescription(
              name: 'familyId',
              type: _is.getType<_is.UuidValue>(),
              nullable: false,
            ),
            'withinDays': _is.ParameterDescription(
              name: 'withinDays',
              type: _is.getType<int>(),
              nullable: false,
            ),
            'limit': _is.ParameterDescription(
              name: 'limit',
              type: _is.getType<int>(),
              nullable: false,
            ),
          },
          call:
              (
                _is.Session session,
                Map<String, dynamic> params,
              ) async => (endpoints['story'] as _iiu4mi32.StoryEndpoint)
                  .listLatestPublished(
                    session,
                    params['familyId'],
                    withinDays: params['withinDays'],
                    limit: params['limit'],
                  ),
        ),
        'listForPerson': _is.MethodConnector(
          name: 'listForPerson',
          params: {
            'personId': _is.ParameterDescription(
              name: 'personId',
              type: _is.getType<_is.UuidValue>(),
              nullable: false,
            ),
          },
          call:
              (
                _is.Session session,
                Map<String, dynamic> params,
              ) async =>
                  (endpoints['story'] as _iiu4mi32.StoryEndpoint).listForPerson(
                    session,
                    params['personId'],
                  ),
        ),
        'discard': _is.MethodConnector(
          name: 'discard',
          params: {
            'storyId': _is.ParameterDescription(
              name: 'storyId',
              type: _is.getType<_is.UuidValue>(),
              nullable: false,
            ),
          },
          call:
              (
                _is.Session session,
                Map<String, dynamic> params,
              ) async =>
                  (endpoints['story'] as _iiu4mi32.StoryEndpoint).discard(
                    session,
                    params['storyId'],
                  ),
        ),
        'search': _is.MethodConnector(
          name: 'search',
          params: {
            'q': _is.ParameterDescription(
              name: 'q',
              type: _is.getType<_ix1z7n33.StorySearchDto>(),
              nullable: false,
            ),
          },
          call:
              (
                _is.Session session,
                Map<String, dynamic> params,
              ) async => (endpoints['story'] as _iiu4mi32.StoryEndpoint).search(
                session,
                params['q'],
              ),
        ),
        'facets': _is.MethodConnector(
          name: 'facets',
          params: {
            'familyId': _is.ParameterDescription(
              name: 'familyId',
              type: _is.getType<_is.UuidValue>(),
              nullable: false,
            ),
          },
          call:
              (
                _is.Session session,
                Map<String, dynamic> params,
              ) async => (endpoints['story'] as _iiu4mi32.StoryEndpoint).facets(
                session,
                params['familyId'],
              ),
        ),
      },
    );
    modules['serverpod_auth_idp'] = _iais.Endpoints()
      ..initializeEndpoints(server);
    modules['serverpod_auth_core'] = _iacs.Endpoints()
      ..initializeEndpoints(server);
  }

  @override
  _is.FutureCallDispatch? get futureCalls {
    return _iggapxvt.FutureCalls();
  }
}
