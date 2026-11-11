import 'package:flutter_test/flutter_test.dart';
import 'package:tell_me_a_story/core/domain/app_exception.dart';
import 'package:tell_me_a_story/core/data/server_families_repository.dart';
import 'package:tell_me_a_story_client/tell_me_a_story_client.dart' as server;

final _a = server.UuidValue.fromString('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa');
final _b = server.UuidValue.fromString('bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb');
final _c = server.UuidValue.fromString('cccccccc-cccc-4ccc-8ccc-cccccccccccc');

void main() {
  test('MemberFamily.fromDto reads parent, year, role, cover, createdAt', () {
    final created = DateTime.utc(2024, 3, 1);
    final family = memberFamilyFromDto(
      server.MemberFamilyDto(
        id: _a,
        name: ' Ada ',
        parentId: _b,
        branchYear: 1987,
        createdAt: created,
        role: server.MembershipRole.coOwner,
        coverKey: 'covers/a.jpg',
      ),
    );
    expect(family.id, _a.toString());
    expect(family.name, 'Ada');
    expect(family.parentFamilyId, _b.toString());
    expect(family.branchYear, 1987);
    expect(family.createdAt, created);
    expect(family.role, 'co_owner');
    expect(family.coverPhotoPath, 'covers/a.jpg');

    final bare = memberFamilyFromDto(
      server.MemberFamilyDto(
        id: _a,
        name: '  ',
        createdAt: created,
        role: server.MembershipRole.member,
      ),
    );
    expect(bare.name, 'Family');
    expect(bare.parentFamilyId, isNull);
    expect(bare.coverPhotoPath, isNull);
  });

  test('StewardFamily.fromDto keeps role and deletedAt', () {
    final deleted = DateTime.utc(2026, 11, 1);
    final family = stewardFamilyFromDto(
      server.StewardFamilyDto(
        id: _a,
        name: 'Ada',
        role: server.MembershipRole.owner,
        deletedAt: deleted,
      ),
    );
    expect(family.role, 'owner');
    expect(family.deletedAt, deleted);
  });

  test('TreeFamily.fromDto reads the effective origin', () {
    final family = treeFamilyFromDto(
      server.TreeFamilyDto(
        id: _a,
        name: 'Ada',
        parentId: _b,
        branchYear: 1990,
        effectiveOriginStoryId: _c,
      ),
    );
    expect(family.parentFamilyId, _b.toString());
    expect(family.branchYear, 1990);
    expect(family.originStoryId, _c.toString());
  });

  test('FamilyRoster.fromDto reads counts', () {
    final roster = familyRosterFromDto(
      server.FamilyRosterDto(
        id: _a,
        name: 'Ada',
        role: server.MembershipRole.coOwner,
        memberCount: 3,
        publishedCount: 7,
      ),
    );
    expect(roster.role, 'co_owner');
    expect(roster.memberCount, 3);
    expect(roster.publishedCount, 7);
    expect(roster.deletedAt, isNull);
  });

  test('FamilyDetail.fromDto maps members, avatars and invite dates', () {
    final sent = DateTime.utc(2026, 11, 2);
    final created = DateTime.utc(2026, 11, 1);
    final expires = DateTime.utc(2026, 11, 9);
    final detail = familyDetailFromDto(
      server.FamilyDetailDto(
        id: _a,
        name: 'Ada',
        myRole: server.MembershipRole.owner,
        members: [
          server.FamilyMemberDto(
            userId: _b,
            role: server.MembershipRole.member,
            displayName: 'Bea',
          ),
        ],
        pendingInvites: [
          server.PendingInviteDto(
            id: _c,
            email: ' bea@x.com ',
            sentAt: sent,
            expiresAt: expires,
            createdAt: created,
          ),
        ],
      ),
      avatars: const {},
    );
    expect(detail.myRole, 'owner');
    expect(detail.people.single.userId, _b.toString());
    expect(detail.people.single.role, 'member');
    expect(detail.people.single.displayName, 'Bea');
    final invite = detail.pendingInvites.single;
    expect(invite.id, _c.toString());
    expect(invite.email, 'bea@x.com');
    expect(invite.sentAt, sent);
    expect(invite.createdAt, created);
    expect(invite.expiresAt, expires);
  });

  test('originErrorCopy keeps the old set-origin messages', () {
    AppException copy(AppErrorCode code) =>
        originErrorCopy(AppException(code: code, message: 'server text'))
            as AppException;
    expect(
      copy(AppErrorCode.forbidden).message,
      'You do not have permission to do that.',
    );
    expect(copy(AppErrorCode.forbidden).code, AppErrorCode.forbidden);
    expect(copy(AppErrorCode.notFound).message, 'Not found.');
    expect(copy(AppErrorCode.notFound).code, AppErrorCode.notFound);
    expect(copy(AppErrorCode.validation).message, 'server text');
    final other = StateError('x');
    expect(originErrorCopy(other), same(other));
  });
}
