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
import 'package:tell_me_a_story_server/src/generated/dto/person_write_dto.dart'
    as _imyz5bcs;
import 'package:tell_me_a_story_server/src/generated/future_calls.dart'
    as _iggapxvt;
import '../auth/email_idp_endpoint.dart' as _iuc1hd5t;
import '../auth/jwt_refresh_endpoint.dart' as _inwq3ztq;
import '../endpoints/live_endpoint.dart' as _ixgr9pqx;
import '../endpoints/media_endpoint.dart' as _iaymoujt;
import '../endpoints/people_endpoint.dart' as _iqqt4psm;
import '../endpoints/photo_endpoint.dart' as _ihuw68ce;
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
