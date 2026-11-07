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
import 'dart:async' as _ida;
import 'dart:typed_data' as _idt;

import 'package:http/http.dart' as _i85jenna;
import 'package:serverpod_auth_core_client/serverpod_auth_core_client.dart'
    as _iacc;
import 'package:serverpod_auth_idp_client/serverpod_auth_idp_client.dart'
    as _iaic;
import 'package:serverpod_client/serverpod_client.dart' as _isc;
import 'package:tell_me_a_story_client/src/protocol/birth_visibility.dart'
    as _iie7eme0;
import 'package:tell_me_a_story_client/src/protocol/date_precision.dart'
    as _i3omm4g5;
import 'package:tell_me_a_story_client/src/protocol/dto/family_detail_dto.dart'
    as _is49z41e;
import 'package:tell_me_a_story_client/src/protocol/dto/family_directory_dto.dart'
    as _itkjk2qa;
import 'package:tell_me_a_story_client/src/protocol/dto/family_member_dto.dart'
    as _ie59njid;
import 'package:tell_me_a_story_client/src/protocol/dto/member_family_dto.dart'
    as _ii9mmjc2;
import 'package:tell_me_a_story_client/src/protocol/dto/own_profile_dto.dart'
    as _il07dlrf;
import 'package:tell_me_a_story_client/src/protocol/dto/place_dto.dart'
    as _irx46cwk;
import 'package:tell_me_a_story_client/src/protocol/dto/place_input_dto.dart'
    as _iyhrnw9c;
import 'package:tell_me_a_story_client/src/protocol/dto/steward_family_dto.dart'
    as _iy83v9y2;
import 'package:tell_me_a_story_client/src/protocol/dto/tree_family_dto.dart'
    as _iwn4wr2j;
import 'package:tell_me_a_story_client/src/protocol/membership_role.dart'
    as _ivz934fu;

import 'protocol.dart' as _il2as5qe;

/// By extending [EmailOtpIdpBaseEndpoint], the email identity provider
/// endpoints, including the passwordless sign-in with one-time passwords, are
/// made available on the server and enable the corresponding sign-in widget on
/// the client.
///
/// Extend [EmailIdpBaseEndpoint] instead for the password based sign-in only.
/// {@category Endpoint}
class EndpointEmailIdp extends _iaic.EndpointEmailOtpIdpBase {
  EndpointEmailIdp(_isc.EndpointCaller caller) : super(caller);

  @override
  String get name => 'emailIdp';

  /// Starts a passwordless login by sending a one-time password to [email].
  ///
  /// The code is sent whether or not an account is registered for the email.
  /// If none is, verifying the code lets the user create a new account.
  ///
  /// Always returns a login request ID, which must be passed to
  /// [verifyOtpLoginCode] together with the one-time password.
  ///
  /// Throws an [EmailAccountRequestException] in case of errors, with reason:
  /// - [EmailAccountRequestExceptionReason.policyViolation] if the email is
  ///   not valid.
  /// - [EmailAccountRequestExceptionReason.tooManyAttempts] if too many
  ///   one-time passwords have been requested for the email.
  @override
  _ida.Future<_isc.UuidValue> startOtpLogin({required String email}) =>
      caller.callServerEndpoint<_isc.UuidValue>(
        'emailIdp',
        'startOtpLogin',
        {'email': email},
      );

  /// Verifies a one-time password and returns a token to complete the login.
  ///
  /// If [EmailAccountOtpVerificationResult.accountExists] is `true`, pass the
  /// token to [finishOtpLogin] to sign in. Otherwise, have the user accept the
  /// terms (and optionally set a password if
  /// [EmailAccountOtpVerificationResult.allowPassword] is `true`) and pass it
  /// to [finishOtpRegistration] to create the account.
  ///
  /// Throws an [EmailAccountRequestException] in case of errors, with reason:
  /// - [EmailAccountRequestExceptionReason.expired] if the login request has
  ///   already expired.
  /// - [EmailAccountRequestExceptionReason.tooManyAttempts] if the user has
  ///   made too many attempts to verify the code.
  /// - [EmailAccountRequestExceptionReason.invalid] if no request exists for
  ///   the given [otpLoginRequestId] or [verificationCode] is invalid.
  @override
  _ida.Future<_iaic.EmailAccountOtpVerificationResult> verifyOtpLoginCode({
    required _isc.UuidValue otpLoginRequestId,
    required String verificationCode,
  }) => caller.callServerEndpoint<_iaic.EmailAccountOtpVerificationResult>(
    'emailIdp',
    'verifyOtpLoginCode',
    {
      'otpLoginRequestId': otpLoginRequestId,
      'verificationCode': verificationCode,
    },
  );

  /// Completes a passwordless login for an existing account and returns a new
  /// session.
  ///
  /// Throws an [EmailAccountRequestException] in case of errors, with reason:
  /// - [EmailAccountRequestExceptionReason.expired] if the login request has
  ///   already expired.
  /// - [EmailAccountRequestExceptionReason.invalid] if the [otpLoginToken] is
  ///   invalid or no account exists for the email.
  ///
  /// Throws an [AuthUserBlockedException] if the auth user is blocked.
  @override
  _ida.Future<_iacc.AuthSuccess> finishOtpLogin({
    required String otpLoginToken,
  }) => caller.callServerEndpoint<_iacc.AuthSuccess>(
    'emailIdp',
    'finishOtpLogin',
    {'otpLoginToken': otpLoginToken},
  );

  /// Completes a passwordless login for an email without an account, by
  /// creating a new auth user with a profile and attaching the verified email
  /// to it.
  ///
  /// Must only be called after the user accepted the terms. The [password] is
  /// optional, and may only be set if
  /// [EmailAccountOtpVerificationResult.allowPassword] was `true`.
  ///
  /// Throws an [EmailAccountRequestException] in case of errors, with reason:
  /// - [EmailAccountRequestExceptionReason.expired] if the login request has
  ///   already expired.
  /// - [EmailAccountRequestExceptionReason.policyViolation] if a password is
  ///   given but not allowed, or it does not comply with the password policy.
  /// - [EmailAccountRequestExceptionReason.invalid] if the [otpLoginToken] is
  ///   invalid or an account already exists for the email.
  ///
  /// Returns a session for the newly created user.
  @override
  _ida.Future<_iacc.AuthSuccess> finishOtpRegistration({
    required String otpLoginToken,
    String? password,
  }) => caller.callServerEndpoint<_iacc.AuthSuccess>(
    'emailIdp',
    'finishOtpRegistration',
    {
      'otpLoginToken': otpLoginToken,
      'password': password,
    },
  );

  /// Logs in the user and returns a new session.
  ///
  /// Throws an [EmailAccountLoginException] in case of errors, with reason:
  /// - [EmailAccountLoginExceptionReason.invalidCredentials] if the email or
  ///   password is incorrect.
  /// - [EmailAccountLoginExceptionReason.tooManyAttempts] if there have been
  ///   too many failed login attempts.
  ///
  /// Throws an [AuthUserBlockedException] if the auth user is blocked.
  @override
  _ida.Future<_iacc.AuthSuccess> login({
    required String email,
    required String password,
  }) => caller.callServerEndpoint<_iacc.AuthSuccess>(
    'emailIdp',
    'login',
    {
      'email': email,
      'password': password,
    },
  );

  /// Starts the registration for a new user account with an email-based login
  /// associated to it.
  ///
  /// Upon successful completion of this method, an email will have been
  /// sent to [email] with a verification link, which the user must open to
  /// complete the registration.
  ///
  /// Always returns a account request ID, which can be used to complete the
  /// registration. If the email is already registered, the returned ID will not
  /// be valid.
  @override
  _ida.Future<_isc.UuidValue> startRegistration({required String email}) =>
      caller.callServerEndpoint<_isc.UuidValue>(
        'emailIdp',
        'startRegistration',
        {'email': email},
      );

  /// Verifies an account request code and returns a token
  /// that can be used to complete the account creation.
  ///
  /// Throws an [EmailAccountRequestException] in case of errors, with reason:
  /// - [EmailAccountRequestExceptionReason.expired] if the account request has
  ///   already expired.
  /// - [EmailAccountRequestExceptionReason.policyViolation] if the password
  ///   does not comply with the password policy.
  /// - [EmailAccountRequestExceptionReason.invalid] if no request exists
  ///   for the given [accountRequestId] or [verificationCode] is invalid.
  @override
  _ida.Future<String> verifyRegistrationCode({
    required _isc.UuidValue accountRequestId,
    required String verificationCode,
  }) => caller.callServerEndpoint<String>(
    'emailIdp',
    'verifyRegistrationCode',
    {
      'accountRequestId': accountRequestId,
      'verificationCode': verificationCode,
    },
  );

  /// Completes a new account registration, creating a new auth user with a
  /// profile and attaching the given email account to it.
  ///
  /// Throws an [EmailAccountRequestException] in case of errors, with reason:
  /// - [EmailAccountRequestExceptionReason.expired] if the account request has
  ///   already expired.
  /// - [EmailAccountRequestExceptionReason.policyViolation] if the password
  ///   does not comply with the password policy.
  /// - [EmailAccountRequestExceptionReason.invalid] if the [registrationToken]
  ///   is invalid.
  ///
  /// Throws an [AuthUserBlockedException] if the auth user is blocked.
  ///
  /// Returns a session for the newly created user.
  @override
  _ida.Future<_iacc.AuthSuccess> finishRegistration({
    required String registrationToken,
    required String password,
  }) => caller.callServerEndpoint<_iacc.AuthSuccess>(
    'emailIdp',
    'finishRegistration',
    {
      'registrationToken': registrationToken,
      'password': password,
    },
  );

  /// Requests a password reset for [email].
  ///
  /// If the email address is registered, an email with reset instructions will
  /// be send out. If the email is unknown, this method will have no effect.
  ///
  /// Always returns a password reset request ID, which can be used to complete
  /// the reset. If the email is not registered, the returned ID will not be
  /// valid.
  ///
  /// Throws an [EmailAccountPasswordResetException] in case of errors, with reason:
  /// - [EmailAccountPasswordResetExceptionReason.tooManyAttempts] if the user has
  ///   made too many attempts trying to request a password reset.
  ///
  @override
  _ida.Future<_isc.UuidValue> startPasswordReset({required String email}) =>
      caller.callServerEndpoint<_isc.UuidValue>(
        'emailIdp',
        'startPasswordReset',
        {'email': email},
      );

  /// Verifies a password reset code and returns a finishPasswordResetToken
  /// that can be used to finish the password reset.
  ///
  /// Throws an [EmailAccountPasswordResetException] in case of errors, with reason:
  /// - [EmailAccountPasswordResetExceptionReason.expired] if the password reset
  ///   request has already expired.
  /// - [EmailAccountPasswordResetExceptionReason.tooManyAttempts] if the user has
  ///   made too many attempts trying to verify the password reset.
  /// - [EmailAccountPasswordResetExceptionReason.invalid] if no request exists
  ///   for the given [passwordResetRequestId] or [verificationCode] is invalid.
  ///
  /// If multiple steps are required to complete the password reset, this endpoint
  /// should be overridden to return credentials for the next step instead
  /// of the credentials for setting the password.
  @override
  _ida.Future<String> verifyPasswordResetCode({
    required _isc.UuidValue passwordResetRequestId,
    required String verificationCode,
  }) => caller.callServerEndpoint<String>(
    'emailIdp',
    'verifyPasswordResetCode',
    {
      'passwordResetRequestId': passwordResetRequestId,
      'verificationCode': verificationCode,
    },
  );

  /// Completes a password reset request by setting a new password.
  ///
  /// The [verificationCode] returned from [verifyPasswordResetCode] is used to
  /// validate the password reset request.
  ///
  /// Throws an [EmailAccountPasswordResetException] in case of errors, with reason:
  /// - [EmailAccountPasswordResetExceptionReason.expired] if the password reset
  ///   request has already expired.
  /// - [EmailAccountPasswordResetExceptionReason.policyViolation] if the new
  ///   password does not comply with the password policy.
  /// - [EmailAccountPasswordResetExceptionReason.invalid] if no request exists
  ///   for the given [passwordResetRequestId] or [verificationCode] is invalid.
  ///
  /// Throws an [AuthUserBlockedException] if the auth user is blocked.
  @override
  _ida.Future<void> finishPasswordReset({
    required String finishPasswordResetToken,
    required String newPassword,
  }) => caller.callServerEndpoint<void>(
    'emailIdp',
    'finishPasswordReset',
    {
      'finishPasswordResetToken': finishPasswordResetToken,
      'newPassword': newPassword,
    },
  );

  @override
  _ida.Future<bool> hasAccount() => caller.callServerEndpoint<bool>(
    'emailIdp',
    'hasAccount',
    {},
  );
}

/// By extending [RefreshJwtTokensEndpoint], the JWT token refresh endpoint
/// is made available on the server and enables automatic token refresh on the client.
/// {@category Endpoint}
class EndpointJwtRefresh extends _iacc.EndpointRefreshJwtTokens {
  EndpointJwtRefresh(_isc.EndpointCaller caller) : super(caller);

  @override
  String get name => 'jwtRefresh';

  /// Creates a new token pair for the given [refreshToken].
  ///
  /// If [refreshToken] is omitted, cookie-mode web clients fall back to the
  /// configured HttpOnly refresh cookie. When neither source is present this
  /// throws [RefreshTokenNotFoundException], the same public "no usable refresh
  /// credential" exception used for unknown refresh tokens.
  ///
  /// Can throw the following exceptions:
  /// -[RefreshTokenMalformedException]: refresh token is malformed and could
  ///   not be parsed. Not expected to happen for tokens issued by the server.
  /// -[RefreshTokenNotFoundException]: refresh token is unknown to the server.
  ///   Either the token was deleted or generated by a different server.
  /// -[RefreshTokenExpiredException]: refresh token has expired. Will happen
  ///   only if it has not been used within configured `refreshTokenLifetime`.
  /// -[RefreshTokenInvalidSecretException]: refresh token is incorrect, meaning
  ///   it does not refer to the current secret refresh token. This indicates
  ///   either a malfunctioning client or a malicious attempt by someone who has
  ///   obtained the refresh token. In this case the underlying refresh token
  ///   will be deleted, and access to it will expire fully when the last access
  ///   token is elapsed.
  ///
  /// This endpoint is unauthenticated, meaning the client won't include any
  /// authentication information with the call.
  @override
  _ida.Future<_iacc.AuthSuccess> refreshAccessToken({String? refreshToken}) =>
      caller.callServerEndpoint<_iacc.AuthSuccess>(
        'jwtRefresh',
        'refreshAccessToken',
        {'refreshToken': refreshToken},
        authenticated: false,
      );
}

/// Families, memberships and covers (business-rules.md §2.1, §2.2, §3.1–§3.3,
/// §3.5, §3.6; schema-design.md §3.2). Every write and member read needs a
/// live family (D6b); only `recover` and the steward reads `listStewarded`,
/// `directory` and `detail` reach a soft-deleted family.
/// {@category Endpoint}
class EndpointFamily extends _isc.EndpointRef {
  EndpointFamily(_isc.EndpointCaller caller) : super(caller);

  @override
  String get name => 'family';

  /// A new tree with one family; the caller is its owner and gets a linked
  /// person (business-rules.md §3.1).
  _ida.Future<_isc.UuidValue> createRoot(String name) =>
      caller.callServerEndpoint<_isc.UuidValue>(
        'family',
        'createRoot',
        {'name': name},
      );

  /// The caller's live families, any role.
  _ida.Future<List<_ii9mmjc2.MemberFamilyDto>> listMine() =>
      caller.callServerEndpoint<List<_ii9mmjc2.MemberFamilyDto>>(
        'family',
        'listMine',
        {},
      );

  /// Families the caller owns or co-owns: live ones and soft-deleted ones
  /// still inside the recovery window (recovery read, D6b).
  _ida.Future<List<_iy83v9y2.StewardFamilyDto>> listStewarded() =>
      caller.callServerEndpoint<List<_iy83v9y2.StewardFamilyDto>>(
        'family',
        'listStewarded',
        {},
      );

  /// Live families sharing [familyId]'s tree (D8), with their effective
  /// origin. Empty unless the caller reads that tree.
  _ida.Future<List<_iwn4wr2j.TreeFamilyDto>> listTree(
    _isc.UuidValue familyId,
  ) => caller.callServerEndpoint<List<_iwn4wr2j.TreeFamilyDto>>(
    'family',
    'listTree',
    {'familyId': familyId},
  );

  _ida.Future<List<_ie59njid.FamilyMemberDto>> listMembers(
    _isc.UuidValue familyId,
  ) => caller.callServerEndpoint<List<_ie59njid.FamilyMemberDto>>(
    'family',
    'listMembers',
    {'familyId': familyId},
  );

  /// The caller's stewarded families with member and published-story counts,
  /// in one query: live ones are `active`; soft-deleted ones inside the
  /// recovery window are `recoverable` (recovery read, D6b).
  _ida.Future<_itkjk2qa.FamilyDirectoryDto> directory() =>
      caller.callServerEndpoint<_itkjk2qa.FamilyDirectoryDto>(
        'family',
        'directory',
        {},
      );

  /// Family, members and pending invites. Live members read a live family;
  /// owners and co-owners also read a soft-deleted one (recovery read, D6b),
  /// whose invites are not readable, so `pendingInvites` is empty.
  _ida.Future<_is49z41e.FamilyDetailDto?> detail(_isc.UuidValue familyId) =>
      caller.callServerEndpoint<_is49z41e.FamilyDetailDto?>(
        'family',
        'detail',
        {'familyId': familyId},
      );

  _ida.Future<void> rename(
    _isc.UuidValue familyId,
    String name,
  ) => caller.callServerEndpoint<void>(
    'family',
    'rename',
    {
      'familyId': familyId,
      'name': name,
    },
  );

  /// Owner or co-owner promotes a plain member; at most two co-owners, counted
  /// under the family row lock.
  _ida.Future<void> addCoOwner(
    _isc.UuidValue familyId,
    _isc.UuidValue userId,
  ) => caller.callServerEndpoint<void>(
    'family',
    'addCoOwner',
    {
      'familyId': familyId,
      'userId': userId,
    },
  );

  _ida.Future<void> removeCoOwner(
    _isc.UuidValue familyId,
    _isc.UuidValue userId,
  ) => caller.callServerEndpoint<void>(
    'family',
    'removeCoOwner',
    {
      'familyId': familyId,
      'userId': userId,
    },
  );

  /// Business-rules.md §3.6. Writes demote the caller, promote the target,
  /// then make the caller co-owner if asked, so the one-owner index and the
  /// co-owner cap hold at every step.
  _ida.Future<void> transferOwnership(
    _isc.UuidValue familyId,
    _isc.UuidValue newOwnerUserId,
    _ivz934fu.MembershipRole formerOwnerBecomes,
  ) => caller.callServerEndpoint<void>(
    'family',
    'transferOwnership',
    {
      'familyId': familyId,
      'newOwnerUserId': newOwnerUserId,
      'formerOwnerBecomes': formerOwnerBecomes,
    },
  );

  /// Removes [userId] from every family in the tree, soft-deleted ones
  /// included (so recovery can't restore them), and unlinks their person in
  /// the tree; story tags stay (business-rules.md §2.2).
  _ida.Future<void> removeMember(
    _isc.UuidValue familyId,
    _isc.UuidValue userId,
  ) => caller.callServerEndpoint<void>(
    'family',
    'removeMember',
    {
      'familyId': familyId,
      'userId': userId,
    },
  );

  /// Owner only. Only sets `deletedAt`; the purge (3f) removes the family
  /// after the recovery window.
  _ida.Future<void> softDelete(_isc.UuidValue familyId) =>
      caller.callServerEndpoint<void>(
        'family',
        'softDelete',
        {'familyId': familyId},
      );

  /// Owner or co-owner of the soft-deleted family, inside the recovery
  /// window (recovery exception, D6b).
  _ida.Future<void> recover(_isc.UuidValue familyId) =>
      caller.callServerEndpoint<void>(
        'family',
        'recover',
        {'familyId': familyId},
      );
}

/// Places are shared by every family in a tree (business-rules.md §2.4, §8
/// item 1). `familyId` parameters resolve the family's tree; the caller must
/// be a live member of a live family in that tree, and the family itself must
/// be live (D6b). Place rows are checked by their `treeId` (D8).
/// {@category Endpoint}
class EndpointPlace extends _isc.EndpointRef {
  EndpointPlace(_isc.EndpointCaller caller) : super(caller);

  @override
  String get name => 'place';

  _ida.Future<List<_irx46cwk.PlaceDto>> list(_isc.UuidValue familyId) =>
      caller.callServerEndpoint<List<_irx46cwk.PlaceDto>>(
        'place',
        'list',
        {'familyId': familyId},
      );

  _ida.Future<List<_irx46cwk.PlaceDto>> favorites(_isc.UuidValue familyId) =>
      caller.callServerEndpoint<List<_irx46cwk.PlaceDto>>(
        'place',
        'favorites',
        {'familyId': familyId},
      );

  _ida.Future<List<_irx46cwk.PlaceDto>> recents(
    _isc.UuidValue familyId, {
    required int limit,
  }) => caller.callServerEndpoint<List<_irx46cwk.PlaceDto>>(
    'place',
    'recents',
    {
      'familyId': familyId,
      'limit': limit,
    },
  );

  /// Creates a place in the family's tree, marked used now. A place with the
  /// same Mapbox id already in the tree is returned instead (schema-design.md
  /// §3.2, places).
  _ida.Future<_irx46cwk.PlaceDto> create(
    _isc.UuidValue familyId,
    _iyhrnw9c.PlaceInputDto input,
  ) => caller.callServerEndpoint<_irx46cwk.PlaceDto>(
    'place',
    'create',
    {
      'familyId': familyId,
      'input': input,
    },
  );

  _ida.Future<_irx46cwk.PlaceDto> markUsed(_isc.UuidValue placeId) =>
      caller.callServerEndpoint<_irx46cwk.PlaceDto>(
        'place',
        'markUsed',
        {'placeId': placeId},
      );

  _ida.Future<_irx46cwk.PlaceDto> setFavorite(
    _isc.UuidValue placeId,
    bool isFavorite,
  ) => caller.callServerEndpoint<_irx46cwk.PlaceDto>(
    'place',
    'setFavorite',
    {
      'placeId': placeId,
      'isFavorite': isFavorite,
    },
  );

  _ida.Future<_irx46cwk.PlaceDto?> findByMapboxId(
    _isc.UuidValue familyId,
    String mapboxPlaceId,
  ) => caller.callServerEndpoint<_irx46cwk.PlaceDto?>(
    'place',
    'findByMapboxId',
    {
      'familyId': familyId,
      'mapboxPlaceId': mapboxPlaceId,
    },
  );

  /// Null when the place doesn't exist or the caller can't read its tree.
  _ida.Future<_irx46cwk.PlaceDto?> get(_isc.UuidValue placeId) =>
      caller.callServerEndpoint<_irx46cwk.PlaceDto?>(
        'place',
        'get',
        {'placeId': placeId},
      );
}

/// The caller's own account (business-rules.md §2.10). Email is the login
/// identity and read-only (D1); account deletion is not offered (D7).
/// {@category Endpoint}
class EndpointProfile extends _isc.EndpointRef {
  EndpointProfile(_isc.EndpointCaller caller) : super(caller);

  @override
  String get name => 'profile';

  _ida.Future<_il07dlrf.OwnProfileDto> me() =>
      caller.callServerEndpoint<_il07dlrf.OwnProfileDto>(
        'profile',
        'me',
        {},
      );

  /// Sets the display name (blank clears it) and renames every person linked
  /// to the caller, in every tree. A blank name leaves linked names alone.
  _ida.Future<void> saveName(String displayName) =>
      caller.callServerEndpoint<void>(
        'profile',
        'saveName',
        {'displayName': displayName},
      );

  /// One Save of the account form: display name, birth and about are written
  /// as given (null clears); a null [birthVisibility] keeps the current one.
  _ida.Future<void> saveAccount({
    required String displayName,
    DateTime? birthDate,
    _i3omm4g5.DatePrecision? birthPrecision,
    _iie7eme0.BirthVisibility? birthVisibility,
    String? about,
  }) => caller.callServerEndpoint<void>(
    'profile',
    'saveAccount',
    {
      'displayName': displayName,
      'birthDate': birthDate,
      'birthPrecision': birthPrecision,
      'birthVisibility': birthVisibility,
      'about': about,
    },
  );

  /// Stores a JPEG (≤ 2 MiB) under a fresh key and points the account at it;
  /// the previous key is queued for deletion in the same transaction.
  _ida.Future<String> saveAvatar(_idt.ByteData jpeg) =>
      caller.callServerEndpoint<String>(
        'profile',
        'saveAvatar',
        {'jpeg': jpeg},
      );

  _ida.Future<void> clearAvatar() => caller.callServerEndpoint<void>(
    'profile',
    'clearAvatar',
    {},
  );
}

class Modules {
  Modules(Client client) {
    serverpod_auth_idp = _iaic.Caller(client);
    serverpod_auth_core = _iacc.Caller(client);
  }

  late final _iaic.Caller serverpod_auth_idp;

  late final _iacc.Caller serverpod_auth_core;
}

class Client extends _isc.ServerpodClientShared {
  Client(
    String host, {
    dynamic securityContext,
    Duration? streamingConnectionTimeout,
    Duration? connectionTimeout,
    Function(
      _isc.MethodCallContext,
      Object,
      StackTrace,
    )?
    onFailedCall,
    Function(_isc.MethodCallContext)? onSucceededCall,
    bool? disconnectStreamsOnLostInternetConnection,
    _i85jenna.Client? httpClientOverride,
  }) : super(
         host,
         _il2as5qe.Protocol(),
         securityContext: securityContext,
         streamingConnectionTimeout: streamingConnectionTimeout,
         connectionTimeout: connectionTimeout,
         onFailedCall: onFailedCall,
         onSucceededCall: onSucceededCall,
         disconnectStreamsOnLostInternetConnection:
             disconnectStreamsOnLostInternetConnection,
         httpClientOverride: httpClientOverride,
       ) {
    emailIdp = EndpointEmailIdp(this);
    jwtRefresh = EndpointJwtRefresh(this);
    family = EndpointFamily(this);
    place = EndpointPlace(this);
    profile = EndpointProfile(this);
    modules = Modules(this);
  }

  late final EndpointEmailIdp emailIdp;

  late final EndpointJwtRefresh jwtRefresh;

  late final EndpointFamily family;

  late final EndpointPlace place;

  late final EndpointProfile profile;

  late final Modules modules;

  @override
  Map<String, _isc.EndpointRef> get endpointRefLookup => {
    'emailIdp': emailIdp,
    'jwtRefresh': jwtRefresh,
    'family': family,
    'place': place,
    'profile': profile,
  };

  @override
  Map<String, _isc.ModuleEndpointCaller> get moduleLookup => {
    'serverpod_auth_idp': modules.serverpod_auth_idp,
    'serverpod_auth_core': modules.serverpod_auth_core,
  };
}
