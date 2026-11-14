import 'package:tell_me_a_story/data/invite_api.dart';

const kTestFamilyId = '00000000-0000-0000-0000-000000000001';

class FakeInviteApi implements InviteGateway {
  @override
  Future<AcceptInviteResult> acceptInvite({required String token}) async {
    return const AcceptInviteResult(familyId: 'f', membershipId: 'm');
  }

  @override
  Future<String> createFamily(String name) async => kTestFamilyId;

  @override
  Future<CreateInviteResult> createInvite({
    required String familyId,
    String? email,
    String? personId,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<String?> currentFamilyId() async => kTestFamilyId;

  @override
  Future<void> sendInviteEmail({required String inviteId}) async {}
}
