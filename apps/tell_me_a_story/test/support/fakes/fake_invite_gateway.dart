import 'package:tell_me_a_story/data/invite_api.dart';

/// In-memory [InviteGateway] for widget tests. Records every call. Set an
/// `*Error` field to make that call throw it. Subclass and override a method
/// for anything else.
class FakeInviteGateway implements InviteGateway {
  FakeInviteGateway({
    this.familyId = 'family-1',
    this.createdFamilyId = 'family-created',
    this.acceptedFamilyId = 'family-1',
  });

  /// What [currentFamilyId] returns.
  String? familyId;
  String createdFamilyId;
  String acceptedFamilyId;

  Object? createInviteError;
  Object? sendInviteEmailError;
  Object? acceptInviteError;

  final createdFamilyNames = <String>[];
  final createdInvites =
      <({String familyId, String? email, String? personId})>[];
  final sentInvites = <({String inviteId, String token})>[];
  final acceptedTokens = <String>[];

  @override
  Future<String?> currentFamilyId() async => familyId;

  @override
  Future<String> createFamily(String name) async {
    createdFamilyNames.add(name);
    return createdFamilyId;
  }

  @override
  Future<CreateInviteResult> createInvite({
    required String familyId,
    String? email,
    String? personId,
  }) async {
    final error = createInviteError;
    if (error != null) throw error;
    createdInvites.add((familyId: familyId, email: email, personId: personId));
    final n = createdInvites.length;
    return CreateInviteResult(
      inviteId: 'invite-$n',
      token: 'token-$n',
      expiresAt: DateTime.utc(2030),
      inviteUrl: buildInviteUrl('token-$n', origin: 'http://127.0.0.1:3000'),
    );
  }

  @override
  Future<void> sendInviteEmail({
    required String inviteId,
    required String token,
  }) async {
    final error = sendInviteEmailError;
    if (error != null) throw error;
    sentInvites.add((inviteId: inviteId, token: token));
  }

  @override
  Future<AcceptInviteResult> acceptInvite({required String token}) async {
    final error = acceptInviteError;
    if (error != null) throw error;
    acceptedTokens.add(token);
    return AcceptInviteResult(familyId: acceptedFamilyId);
  }
}
