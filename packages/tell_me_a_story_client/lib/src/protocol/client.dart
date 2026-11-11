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
import 'package:tell_me_a_story_client/src/protocol/dto/cover_upload_ticket_dto.dart'
    as _imc738lc;
import 'package:tell_me_a_story_client/src/protocol/dto/created_invite_dto.dart'
    as _iq9lh22z;
import 'package:tell_me_a_story_client/src/protocol/dto/family_detail_dto.dart'
    as _is49z41e;
import 'package:tell_me_a_story_client/src/protocol/dto/family_directory_dto.dart'
    as _itkjk2qa;
import 'package:tell_me_a_story_client/src/protocol/dto/family_member_dto.dart'
    as _ie59njid;
import 'package:tell_me_a_story_client/src/protocol/dto/invite_preview_dto.dart'
    as _i9tmm7fr;
import 'package:tell_me_a_story_client/src/protocol/dto/live_event_dto.dart'
    as _iliy4w0g;
import 'package:tell_me_a_story_client/src/protocol/dto/member_family_dto.dart'
    as _ii9mmjc2;
import 'package:tell_me_a_story_client/src/protocol/dto/note_dto.dart'
    as _i29gav6s;
import 'package:tell_me_a_story_client/src/protocol/dto/origin_dependent_dto.dart'
    as _i6upf1dr;
import 'package:tell_me_a_story_client/src/protocol/dto/own_profile_dto.dart'
    as _il07dlrf;
import 'package:tell_me_a_story_client/src/protocol/dto/person_dto.dart'
    as _ippgtqmg;
import 'package:tell_me_a_story_client/src/protocol/dto/person_profile_dto.dart'
    as _i60h803r;
import 'package:tell_me_a_story_client/src/protocol/dto/person_write_dto.dart'
    as _i9fxgjdp;
import 'package:tell_me_a_story_client/src/protocol/dto/photo_dto.dart'
    as _ighpoo1p;
import 'package:tell_me_a_story_client/src/protocol/dto/photo_upload_ticket_dto.dart'
    as _izmc1ptl;
import 'package:tell_me_a_story_client/src/protocol/dto/place_dto.dart'
    as _irx46cwk;
import 'package:tell_me_a_story_client/src/protocol/dto/place_input_dto.dart'
    as _iyhrnw9c;
import 'package:tell_me_a_story_client/src/protocol/dto/steward_family_dto.dart'
    as _iy83v9y2;
import 'package:tell_me_a_story_client/src/protocol/dto/story_dto.dart'
    as _ilx6iivj;
import 'package:tell_me_a_story_client/src/protocol/dto/story_facets_dto.dart'
    as _i29ka0kp;
import 'package:tell_me_a_story_client/src/protocol/dto/story_search_dto.dart'
    as _iv05ipkh;
import 'package:tell_me_a_story_client/src/protocol/dto/story_write_dto.dart'
    as _isb2dxzu;
import 'package:tell_me_a_story_client/src/protocol/dto/tree_family_dto.dart'
    as _iwn4wr2j;
import 'package:tell_me_a_story_client/src/protocol/membership_role.dart'
    as _ivz934fu;
import 'package:tell_me_a_story_client/src/protocol/note_kind.dart'
    as _i9uyyhv9;
import 'protocol.dart' as _il2as5qe;

/// The email identity provider endpoint. Only passwordless sign-in with
/// one-time codes (and [hasAccount]) works.
///
/// The inherited password methods (login, registration and password reset)
/// always refuse with `forbidden`. They stay generated because the client's
/// `EndpointEmailOtpIdpBase` declares them abstract.
/// {@category Endpoint}
class EndpointEmailIdp extends _iaic.EndpointEmailOtpIdpBase {
  EndpointEmailIdp(_isc.EndpointCaller caller) : super(caller);

  @override
  String get name => 'emailIdp';

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

  @override
  _ida.Future<_isc.UuidValue> startRegistration({required String email}) =>
      caller.callServerEndpoint<_isc.UuidValue>(
        'emailIdp',
        'startRegistration',
        {'email': email},
      );

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

  @override
  _ida.Future<_isc.UuidValue> startPasswordReset({required String email}) =>
      caller.callServerEndpoint<_isc.UuidValue>(
        'emailIdp',
        'startPasswordReset',
        {'email': email},
      );

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
  _ida.Future<_is49z41e.FamilyDetailDto> detail(_isc.UuidValue familyId) =>
      caller.callServerEndpoint<_is49z41e.FamilyDetailDto>(
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
  /// after the recovery window. Repeating it as the owner of an already
  /// deleted family is a no-op (business-rules.md §3.5). Posts a `family`
  /// event (deleted) to the tree channel after commit.
  _ida.Future<void> softDelete(_isc.UuidValue familyId) =>
      caller.callServerEndpoint<void>(
        'family',
        'softDelete',
        {'familyId': familyId},
      );

  /// Owner or co-owner of the soft-deleted family, inside the recovery
  /// window (recovery exception, D6b). Posts a `family` event to the tree
  /// channel after commit.
  _ida.Future<void> recover(_isc.UuidValue familyId) =>
      caller.callServerEndpoint<void>(
        'family',
        'recover',
        {'familyId': familyId},
      );

  /// Business-rules.md §3.3: bare FORBIDDEN first, then a deleted parent,
  /// then a story that is missing, unpublished or not in
  /// `coalesce(parent, family)`.
  _ida.Future<void> setOrigin(
    _isc.UuidValue familyId,
    _isc.UuidValue storyId,
  ) => caller.callServerEndpoint<void>(
    'family',
    'setOrigin',
    {
      'familyId': familyId,
      'storyId': storyId,
    },
  );

  /// Families whose effective origin is [storyId]. Empty unless the caller is
  /// a live member of the story's family.
  _ida.Future<List<_i6upf1dr.OriginDependentDto>> listOriginDependents(
    _isc.UuidValue storyId,
  ) => caller.callServerEndpoint<List<_i6upf1dr.OriginDependentDto>>(
    'family',
    'listOriginDependents',
    {'storyId': storyId},
  );

  /// "Start a new timeline" (business-rules.md §3.2, in that check order).
  /// The owner and each picked linked member get a linked person in the tree
  /// (D6d). A lost race on `people_tree_user_uidx` reruns the write once.
  /// Posts a `family` event to the tree channel after commit.
  _ida.Future<_isc.UuidValue> createBranch({
    required _isc.UuidValue parentFamilyId,
    required _isc.UuidValue originStoryId,
    required String name,
    required int branchYear,
    required _isc.UuidValue ownerUserId,
    required List<_isc.UuidValue> personIds,
  }) => caller.callServerEndpoint<_isc.UuidValue>(
    'family',
    'createBranch',
    {
      'parentFamilyId': parentFamilyId,
      'originStoryId': originStoryId,
      'name': name,
      'branchYear': branchYear,
      'ownerUserId': ownerUserId,
      'personIds': personIds,
    },
  );

  /// Steward of the live family. [mimeType] (jpeg, png or webp) picks the key
  /// extension; [byteLength] is pinned in the upload, at most 5 MiB.
  _ida.Future<_imc738lc.CoverUploadTicketDto> startCoverUpload(
    _isc.UuidValue familyId,
    String mimeType,
    int byteLength,
  ) => caller.callServerEndpoint<_imc738lc.CoverUploadTicketDto>(
    'family',
    'startCoverUpload',
    {
      'familyId': familyId,
      'mimeType': mimeType,
      'byteLength': byteLength,
    },
  );

  /// Verifies the upload at [key], checks its size and that its bytes are the
  /// image type its extension names, then makes it the cover. A rejected blob
  /// is queued for deletion; the previous cover key is queued in the same
  /// transaction that replaces it. Finishing the current cover again is a
  /// no-op; a key already queued for deletion (e.g. a replaced cover) is
  /// STORAGE_FAILED.
  _ida.Future<String> finishCoverUpload(
    _isc.UuidValue familyId,
    String key,
  ) => caller.callServerEndpoint<String>(
    'family',
    'finishCoverUpload',
    {
      'familyId': familyId,
      'key': key,
    },
  );

  _ida.Future<void> clearCover(_isc.UuidValue familyId) =>
      caller.callServerEndpoint<void>(
        'family',
        'clearCover',
        {'familyId': familyId},
      );
}

/// Invites (business-rules.md §2.9, §3.4; decisions D2, D3, D6a, D6b).
/// {@category Endpoint}
class EndpointInvite extends _isc.EndpointRef {
  EndpointInvite(_isc.EndpointCaller caller) : super(caller);

  @override
  String get name => 'invite';

  /// Any live member invites (D3). [email] is trimmed and lower-cased; blank
  /// means a link-only invite. The raw token is returned once; only its hash
  /// is stored.
  _ida.Future<_iq9lh22z.CreatedInviteDto> create(
    _isc.UuidValue familyId, {
    String? email,
    _isc.UuidValue? personId,
  }) => caller.callServerEndpoint<_iq9lh22z.CreatedInviteDto>(
    'invite',
    'create',
    {
      'familyId': familyId,
      'email': email,
      'personId': personId,
    },
  );

  /// Any live member emails a pending invite. [token] is the raw token from
  /// [create]: only its hash is stored, so the link can't be rebuilt without
  /// it.
  _ida.Future<void> sendEmail(
    _isc.UuidValue inviteId,
    String token,
  ) => caller.callServerEndpoint<void>(
    'invite',
    'sendEmail',
    {
      'inviteId': inviteId,
      'token': token,
    },
  );

  /// Joins the invite's family and returns its id. Single transaction:
  /// membership, person link, invite marked accepted. A double-tapped accept
  /// that loses the linked-person race reruns once and finds the committed
  /// person.
  _ida.Future<_isc.UuidValue> accept(String token) =>
      caller.callServerEndpoint<_isc.UuidValue>(
        'invite',
        'accept',
        {'token': token},
      );

  /// Owner or co-owner: rotates the token, moves `expiresAt` to now + 7 days
  /// (reviving an expired pending invite) and emails the new link. When the
  /// email fails the token stays rotated, so a retry is safe.
  _ida.Future<DateTime> resend(_isc.UuidValue inviteId) =>
      caller.callServerEndpoint<DateTime>(
        'invite',
        'resend',
        {'inviteId': inviteId},
      );

  /// Owner or co-owner. The row and its token hash stay, so accepting that
  /// token later fails INVITE_INVALID. Revoking twice is a no-op.
  _ida.Future<void> revoke(_isc.UuidValue inviteId) =>
      caller.callServerEndpoint<void>(
        'invite',
        'revoke',
        {'inviteId': inviteId},
      );
}

/// The anonymous invite landing (business-rules.md §3.4, validate).
/// {@category Endpoint}
class EndpointInvitePublic extends _isc.EndpointRef {
  EndpointInvitePublic(_isc.EndpointCaller caller) : super(caller);

  @override
  String get name => 'invitePublic';

  /// Anyone, signed in or not. An unknown token, a soft-deleted family (D6a),
  /// an accepted, revoked or expired invite all give `valid: false` with no
  /// family or inviter.
  _ida.Future<_i9tmm7fr.InvitePreviewDto> preview(String token) =>
      caller.callServerEndpoint<_i9tmm7fr.InvitePreviewDto>(
        'invitePublic',
        'preview',
        {'token': token},
      );
}

/// Live change streams. Authorized once, at subscribe.
/// {@category Endpoint}
class EndpointLive extends _isc.EndpointRef {
  EndpointLive(_isc.EndpointCaller caller) : super(caller);

  @override
  String get name => 'live';

  /// Events for [familyId]: live members and tree readers.
  _ida.Stream<_iliy4w0g.LiveEventDto> watchFamily(_isc.UuidValue familyId) =>
      caller.callStreamingServerEndpoint<
        _ida.Stream<_iliy4w0g.LiveEventDto>,
        _iliy4w0g.LiveEventDto
      >(
        'live',
        'watchFamily',
        {'familyId': familyId},
        {},
      );

  /// Events for every live family in [familyId]'s tree (`tree:<treeId>`):
  /// story, photo and note events of each family, and a `family` event when
  /// a family of the tree is created, soft-deleted or recovered. Tree readers
  /// of live [familyId] (`isTreeReadable`, which every live member passes).
  _ida.Stream<_iliy4w0g.LiveEventDto> watchTree(_isc.UuidValue familyId) =>
      caller.callStreamingServerEndpoint<
        _ida.Stream<_iliy4w0g.LiveEventDto>,
        _iliy4w0g.LiveEventDto
      >(
        'live',
        'watchTree',
        {'familyId': familyId},
        {},
      );

  /// Events for [storyId]: whoever may read the story (`canReadStory`).
  _ida.Stream<_iliy4w0g.LiveEventDto> watchStory(_isc.UuidValue storyId) =>
      caller.callStreamingServerEndpoint<
        _ida.Stream<_iliy4w0g.LiveEventDto>,
        _iliy4w0g.LiveEventDto
      >(
        'live',
        'watchStory',
        {'storyId': storyId},
        {},
      );
}

/// Authorized blob reads (endpoint-contract.md §2.0): every key is resolved
/// to the row that holds it and access is checked on that row. Nobody parses
/// keys. Unknown, unreadable and missing blobs all look the same: null from
/// [get], absent from [getMany].
/// {@category Endpoint}
class EndpointMedia extends _isc.EndpointRef {
  EndpointMedia(_isc.EndpointCaller caller) : super(caller);

  @override
  String get name => 'media';

  _ida.Future<_idt.ByteData?> get(String key) =>
      caller.callServerEndpoint<_idt.ByteData?>(
        'media',
        'get',
        {'key': key},
      );

  /// At most [mediaManyMaxKeys] keys per call, else VALIDATION.
  _ida.Future<Map<String, _idt.ByteData>> getMany(List<String> keys) =>
      caller.callServerEndpoint<Map<String, _idt.ByteData>>(
        'media',
        'getMany',
        {'keys': keys},
      );
}

/// Comments and perspectives (`story_notes`; business-rules §2.8, §4.8;
/// D4). Only the body is editable. Writes post a `note` live event after
/// commit, only while the story is published.
/// {@category Endpoint}
class EndpointNote extends _isc.EndpointRef {
  EndpointNote(_isc.EndpointCaller caller) : super(caller);

  @override
  String get name => 'note';

  /// The story's notes ([kind], or both when null), oldest first. A missing
  /// or unreadable story is `NOT_FOUND: story`.
  _ida.Future<List<_i29gav6s.NoteDto>> listForStory(
    _isc.UuidValue storyId, {
    _i9uyyhv9.NoteKind? kind,
  }) => caller.callServerEndpoint<List<_i29gav6s.NoteDto>>(
    'note',
    'listForStory',
    {
      'storyId': storyId,
      'kind': kind,
    },
  );

  /// A note by the caller; needs `canContribute` on the story.
  _ida.Future<_i29gav6s.NoteDto> create(
    _isc.UuidValue storyId,
    _i9uyyhv9.NoteKind kind,
    String body,
  ) => caller.callServerEndpoint<_i29gav6s.NoteDto>(
    'note',
    'create',
    {
      'storyId': storyId,
      'kind': kind,
      'body': body,
    },
  );

  /// Replaces the body of the caller's own note while they can contribute.
  _ida.Future<void> update(
    _isc.UuidValue noteId,
    String body,
  ) => caller.callServerEndpoint<void>(
    'note',
    'update',
    {
      'noteId': noteId,
      'body': body,
    },
  );

  /// Deletes a note: its author while they can contribute, or an owner or
  /// co-owner of the story's live family on a published story (D4).
  _ida.Future<void> delete(_isc.UuidValue noteId) =>
      caller.callServerEndpoint<void>(
        'note',
        'delete',
        {'noteId': noteId},
      );
}

/// People are tree-scoped: reads and unlinked edits need a live membership
/// somewhere in the person's tree (`Authz.isTreeMemberOf(person.treeId)`).
/// Steward-only actions (mark passed away, delete) check the live home family.
/// {@category Endpoint}
class EndpointPeople extends _isc.EndpointRef {
  EndpointPeople(_isc.EndpointCaller caller) : super(caller);

  @override
  String get name => 'people';

  /// People whose home is [familyId], by name. The family must be live and
  /// in the caller's tree.
  _ida.Future<List<_ippgtqmg.PersonDto>> listFamily(_isc.UuidValue familyId) =>
      caller.callServerEndpoint<List<_ippgtqmg.PersonDto>>(
        'people',
        'listFamily',
        {'familyId': familyId},
      );

  /// Every person in [familyId]'s tree, by name, in one call. Linked people
  /// carry their account birth, coarsened for everyone but themselves.
  _ida.Future<List<_ippgtqmg.PersonDto>> listTree(_isc.UuidValue familyId) =>
      caller.callServerEndpoint<List<_ippgtqmg.PersonDto>>(
        'people',
        'listTree',
        {'familyId': familyId},
      );

  /// Adds an unlinked person with [familyId] as home. A [picture] (JPEG,
  /// ≤ 2 MiB) is stored inline under a fresh `personAvatarKey`.
  _ida.Future<_ippgtqmg.PersonDto> create(
    _isc.UuidValue familyId,
    _i9fxgjdp.PersonWriteDto input,
    _idt.ByteData? picture,
  ) => caller.callServerEndpoint<_ippgtqmg.PersonDto>(
    'people',
    'create',
    {
      'familyId': familyId,
      'input': input,
      'picture': picture,
    },
  );

  /// The person row for the edit dialog, including `userId` and `email`, for
  /// any tree member; null when missing or outside the caller's trees.
  _ida.Future<_ippgtqmg.PersonDto?> forEdit(_isc.UuidValue personId) =>
      caller.callServerEndpoint<_ippgtqmg.PersonDto?>(
        'people',
        'forEdit',
        {'personId': personId},
      );

  /// The profile dialog (old `person_profile`). Never carries `userId` or
  /// `email`. A linked account's about and avatar win when set; its birth is
  /// coarsened by `birthVisibility` for everyone but the linked self.
  _ida.Future<_i60h803r.PersonProfileDto> profile(_isc.UuidValue personId) =>
      caller.callServerEndpoint<_i60h803r.PersonProfileDto>(
        'people',
        'profile',
        {'personId': personId},
      );

  /// Edits a person. Unlinked: any tree member. Linked: only the linked self,
  /// with the name locked to the account, and no passed-away or death change.
  /// A [picture] replaces the avatar; [PersonWriteDto.clearPicture] removes
  /// it. The old key is queued for deletion in the same transaction.
  _ida.Future<_ippgtqmg.PersonDto> update(
    _isc.UuidValue personId,
    _i9fxgjdp.PersonWriteDto input,
    _idt.ByteData? picture,
  ) => caller.callServerEndpoint<_ippgtqmg.PersonDto>(
    'people',
    'update',
    {
      'personId': personId,
      'input': input,
      'picture': picture,
    },
  );

  /// The invite picker: people in [familyId]'s tree who are unlinked, not
  /// passed away, and have no pending invite (not accepted, not revoked,
  /// unexpired), by name.
  _ida.Future<List<_ippgtqmg.PersonDto>> listUnlinked(
    _isc.UuidValue familyId,
  ) => caller.callServerEndpoint<List<_ippgtqmg.PersonDto>>(
    'people',
    'listUnlinked',
    {'familyId': familyId},
  );

  /// Whether the caller is an owner or co-owner of live [familyId].
  _ida.Future<bool> isHomeFamilySteward(_isc.UuidValue familyId) =>
      caller.callServerEndpoint<bool>(
        'people',
        'isHomeFamilySteward',
        {'familyId': familyId},
      );

  /// Sets or clears a linked person's passed-away flag (old
  /// `mark_passed_away`). Checks in the business-rules.md §4.3 order;
  /// clearing the flag clears the death fields.
  _ida.Future<void> markPassedAway(
    _isc.UuidValue personId,
    bool value,
  ) => caller.callServerEndpoint<void>(
    'people',
    'markPassedAway',
    {
      'personId': personId,
      'value': value,
    },
  );

  /// Sets or clears a passed linked person's death date. Owner of the live
  /// home family only, never the person themselves (decision 2026-11-07;
  /// co-owners may toggle the flag but not the date). Same check order as
  /// [markPassedAway]. Unlinked people's death dates go through [update].
  _ida.Future<void> setDeathDate(
    _isc.UuidValue personId,
    DateTime? deathDate,
    _i3omm4g5.DatePrecision? deathPrecision,
  ) => caller.callServerEndpoint<void>(
    'people',
    'setDeathDate',
    {
      'personId': personId,
      'deathDate': deathDate,
      'deathPrecision': deathPrecision,
    },
  );

  /// Deletes an unlinked person (D5): owner or co-owner of the live home
  /// family only. Tags and kinships cascade; invites keep a null person. The
  /// avatar key is queued for deletion in the same transaction.
  _ida.Future<void> delete(_isc.UuidValue personId) =>
      caller.callServerEndpoint<void>(
        'people',
        'delete',
        {'personId': personId},
      );
}

/// Story photos (business-rules.md §2.7 without edit save/reset, §4.5; upload
/// flow schema-design.md §4.2).
/// {@category Endpoint}
class EndpointPhoto extends _isc.EndpointRef {
  EndpointPhoto(_isc.EndpointCaller caller) : super(caller);

  @override
  String get name => 'photo';

  /// The story's photos, hero first.
  _ida.Future<List<_ighpoo1p.PhotoDto>> list(_isc.UuidValue storyId) =>
      caller.callServerEndpoint<List<_ighpoo1p.PhotoDto>>(
        'photo',
        'list',
        {'storyId': storyId},
      );

  /// Authorizes an upload of [byteLength] bytes of [mimeType] and returns the
  /// server-built key with its upload description.
  _ida.Future<_izmc1ptl.PhotoUploadTicketDto> startUpload(
    _isc.UuidValue storyId,
    String mimeType,
    int byteLength,
  ) => caller.callServerEndpoint<_izmc1ptl.PhotoUploadTicketDto>(
    'photo',
    'startUpload',
    {
      'storyId': storyId,
      'mimeType': mimeType,
      'byteLength': byteLength,
    },
  );

  /// Verifies the uploaded blob for [photoId], checks its bytes and the cap,
  /// and writes the row. On any failure the candidate blobs are queued for
  /// deletion, except when the row already exists (the blob is that row's).
  _ida.Future<_ighpoo1p.PhotoDto> finishUpload(
    _isc.UuidValue storyId,
    _isc.UuidValue photoId,
    int sortOrder,
  ) => caller.callServerEndpoint<_ighpoo1p.PhotoDto>(
    'photo',
    'finishUpload',
    {
      'storyId': storyId,
      'photoId': photoId,
      'sortOrder': sortOrder,
    },
  );

  /// Deletes the row; its original and edited keys are queued in the same
  /// transaction.
  _ida.Future<void> delete(_isc.UuidValue photoId) =>
      caller.callServerEndpoint<void>(
        'photo',
        'delete',
        {'photoId': photoId},
      );

  /// Makes [photoId] the hero: one transaction rewrites the story's
  /// `sortOrder` to 0..n-1 with it first, keeping the others' order.
  _ida.Future<void> setHero(
    _isc.UuidValue storyId,
    _isc.UuidValue photoId,
  ) => caller.callServerEndpoint<void>(
    'photo',
    'setHero',
    {
      'storyId': storyId,
      'photoId': photoId,
    },
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

/// Stories, their people tags, and search (endpoint-contract §2.2;
/// business-rules §2.5, §2.6, §4.4).
///
/// Writes post a `story` live event after commit, only while the story is
/// published (and on the publish transition); draft edits post nothing.
/// {@category Endpoint}
class EndpointStory extends _isc.EndpointRef {
  EndpointStory(_isc.EndpointCaller caller) : super(caller);

  @override
  String get name => 'story';

  /// A new draft by the caller in live [familyId]. Idempotent on [id]: when
  /// that story exists and the caller wrote it in [familyId], [input] is
  /// applied as an update and the story returned. Without [allowUndated] a
  /// start date is required.
  _ida.Future<_ilx6iivj.StoryDto> createDraft(
    _isc.UuidValue familyId,
    _isb2dxzu.StoryWriteDto input, {
    _isc.UuidValue? id,
    required bool allowUndated,
  }) => caller.callServerEndpoint<_ilx6iivj.StoryDto>(
    'story',
    'createDraft',
    {
      'familyId': familyId,
      'input': input,
      'id': id,
      'allowUndated': allowUndated,
    },
  );

  /// Applies [input] (null fields keep their value; a list in
  /// `personIds` replaces the tags). Author, or steward on a published story.
  _ida.Future<_ilx6iivj.StoryDto> updateDraft(
    _isc.UuidValue storyId,
    _isb2dxzu.StoryWriteDto input,
  ) => caller.callServerEndpoint<_ilx6iivj.StoryDto>(
    'story',
    'updateDraft',
    {
      'storyId': storyId,
      'input': input,
    },
  );

  /// Like [updateDraft], but only while the story is a draft: false once it
  /// is published, and nothing changes.
  _ida.Future<bool> autosaveDraft(
    _isc.UuidValue storyId,
    _isb2dxzu.StoryWriteDto input,
  ) => caller.callServerEndpoint<bool>(
    'story',
    'autosaveDraft',
    {
      'storyId': storyId,
      'input': input,
    },
  );

  /// The story when the caller may read it, else `NOT_FOUND: story`.
  _ida.Future<_ilx6iivj.StoryDto> get(_isc.UuidValue storyId) =>
      caller.callServerEndpoint<_ilx6iivj.StoryDto>(
        'story',
        'get',
        {'storyId': storyId},
      );

  /// Tags [personId] (same tree) on the story; a repeat is a no-op.
  _ida.Future<void> linkPerson(
    _isc.UuidValue storyId,
    _isc.UuidValue personId,
  ) => caller.callServerEndpoint<void>(
    'story',
    'linkPerson',
    {
      'storyId': storyId,
      'personId': personId,
    },
  );

  /// Publishes the caller's own draft after the readiness check. A
  /// non-author editor gets `FORBIDDEN: field is locked`. Publishing a
  /// published story returns it unchanged.
  _ida.Future<_ilx6iivj.StoryDto> publish(_isc.UuidValue storyId) =>
      caller.callServerEndpoint<_ilx6iivj.StoryDto>(
        'story',
        'publish',
        {'storyId': storyId},
      );

  /// The story when it is published and readable by the caller, else null.
  /// Serves both the app's getPublished and getPublishedOrigin.
  _ida.Future<_ilx6iivj.StoryDto?> getPublished(_isc.UuidValue storyId) =>
      caller.callServerEndpoint<_ilx6iivj.StoryDto?>(
        'story',
        'getPublished',
        {'storyId': storyId},
      );

  /// The caller's drafts in live [familyId], in timeline order (undated
  /// last).
  _ida.Future<List<_ilx6iivj.StoryDto>> listMyDrafts(_isc.UuidValue familyId) =>
      caller.callServerEndpoint<List<_ilx6iivj.StoryDto>>(
        'story',
        'listMyDrafts',
        {'familyId': familyId},
      );

  /// [familyId]'s published stories in timeline order (schema-design §0.5).
  _ida.Future<List<_ilx6iivj.StoryDto>> listPublished(
    _isc.UuidValue familyId,
  ) => caller.callServerEndpoint<List<_ilx6iivj.StoryDto>>(
    'story',
    'listPublished',
    {'familyId': familyId},
  );

  /// Published stories of every live family in [familyId]'s tree, in
  /// timeline order (G1). A soft-deleted family's stories are left out, and
  /// it doesn't split the tree (D6b, D8). Tree readers of live [familyId]
  /// only.
  _ida.Future<List<_ilx6iivj.StoryDto>> listPublishedInTree(
    _isc.UuidValue familyId,
  ) => caller.callServerEndpoint<List<_ilx6iivj.StoryDto>>(
    'story',
    'listPublishedInTree',
    {'familyId': familyId},
  );

  /// Published in the last [withinDays] days, newest first (`latestOrder`),
  /// at most [limit].
  _ida.Future<List<_ilx6iivj.StoryDto>> listLatestPublished(
    _isc.UuidValue familyId, {
    required int withinDays,
    required int limit,
  }) => caller.callServerEndpoint<List<_ilx6iivj.StoryDto>>(
    'story',
    'listLatestPublished',
    {
      'familyId': familyId,
      'withinDays': withinDays,
      'limit': limit,
    },
  );

  /// Published stories in live families of the person's tree that tag
  /// [personId], oldest first. A person outside the caller's tree is
  /// `NOT_FOUND: person`.
  _ida.Future<List<_ilx6iivj.StoryDto>> listForPerson(
    _isc.UuidValue personId,
  ) => caller.callServerEndpoint<List<_ilx6iivj.StoryDto>>(
    'story',
    'listForPerson',
    {'personId': personId},
  );

  /// Deletes the caller's own story (any status) with its photos, notes and
  /// tags. Owners can't delete other people's stories (D4). Photo blob keys
  /// are queued for deletion in the same transaction.
  _ida.Future<void> discard(_isc.UuidValue storyId) =>
      caller.callServerEndpoint<void>(
        'story',
        'discard',
        {'storyId': storyId},
      );

  /// Published stories of `q.familyId` matching [q] (endpoint-contract §2.2
  /// search semantics). Live members and tree readers only.
  _ida.Future<List<_ilx6iivj.StoryDto>> search(_iv05ipkh.StorySearchDto q) =>
      caller.callServerEndpoint<List<_ilx6iivj.StoryDto>>(
        'story',
        'search',
        {'q': q},
      );

  /// Decade, person and place facets over [familyId]'s published stories.
  _ida.Future<_i29ka0kp.StoryFacetsDto> facets(_isc.UuidValue familyId) =>
      caller.callServerEndpoint<_i29ka0kp.StoryFacetsDto>(
        'story',
        'facets',
        {'familyId': familyId},
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
    invite = EndpointInvite(this);
    invitePublic = EndpointInvitePublic(this);
    live = EndpointLive(this);
    media = EndpointMedia(this);
    note = EndpointNote(this);
    people = EndpointPeople(this);
    photo = EndpointPhoto(this);
    place = EndpointPlace(this);
    profile = EndpointProfile(this);
    story = EndpointStory(this);
    modules = Modules(this);
  }

  late final EndpointEmailIdp emailIdp;

  late final EndpointJwtRefresh jwtRefresh;

  late final EndpointFamily family;

  late final EndpointInvite invite;

  late final EndpointInvitePublic invitePublic;

  late final EndpointLive live;

  late final EndpointMedia media;

  late final EndpointNote note;

  late final EndpointPeople people;

  late final EndpointPhoto photo;

  late final EndpointPlace place;

  late final EndpointProfile profile;

  late final EndpointStory story;

  late final Modules modules;

  @override
  Map<String, _isc.EndpointRef> get endpointRefLookup => {
    'emailIdp': emailIdp,
    'jwtRefresh': jwtRefresh,
    'family': family,
    'invite': invite,
    'invitePublic': invitePublic,
    'live': live,
    'media': media,
    'note': note,
    'people': people,
    'photo': photo,
    'place': place,
    'profile': profile,
    'story': story,
  };

  @override
  Map<String, _isc.ModuleEndpointCaller> get moduleLookup => {
    'serverpod_auth_idp': modules.serverpod_auth_idp,
    'serverpod_auth_core': modules.serverpod_auth_core,
  };
}
