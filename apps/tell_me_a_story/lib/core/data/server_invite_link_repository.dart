import 'package:tell_me_a_story_client/tell_me_a_story_client.dart' as server;

import 'package:tell_me_a_story/core/data/server/server_errors.dart';
import 'package:tell_me_a_story/core/domain/invite_link_repository.dart';
import 'package:tell_me_a_story/core/domain/invite_preview.dart';
import 'package:tell_me_a_story/core/server/server_client.dart';

class ServerInviteLinkRepository implements InviteLinkRepository {
  ServerInviteLinkRepository({server.Client? client}) : _injected = client;

  final server.Client? _injected;

  server.Client get _client => _injected ?? serverClient;

  @override
  Future<InvitePreview> validateInviteToken(String token) async {
    final dto = await withServerErrors(
      () => _client.invitePublic.preview(token),
    );
    return InvitePreview(
      valid: dto.valid,
      familyId: dto.familyId?.toString(),
      familyName: dto.familyName,
      inviterName: dto.inviterName,
    );
  }
}
