import 'package:tell_me_a_story_server/src/invites/invites.dart';
import 'package:test/test.dart';

void main() {
  group('Given invite tokens', () {
    test('when a token is made then it is 64 lower-case hex and unique', () {
      final a = newInviteToken();
      final b = newInviteToken();
      expect(a, matches(RegExp(r'^[0-9a-f]{64}$')));
      expect(b, isNot(a));
    });

    test('when a token is hashed then it is its lower-case SHA-256 hex', () {
      expect(
        hashInviteToken('abc'),
        'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad',
      );
    });

    test('when a token is checked then only its own hash matches', () {
      final token = newInviteToken();
      final hash = hashInviteToken(token);
      expect(inviteTokenMatches(token, hash), isTrue);
      expect(inviteTokenMatches(newInviteToken(), hash), isFalse);
      expect(inviteTokenMatches(token, 'short'), isFalse);
    });
  });

  group('Given invite links and mail', () {
    test('when a link is built then it is origin/timeline?invite=token', () {
      expect(
        buildInviteUrl('https://app.example', 'ab12'),
        'https://app.example/timeline?invite=ab12',
      );
    });

    test('when the invite mail is built then it follows the §3.4 copy', () {
      final mail = inviteMail(
        to: 'kim@example.com',
        familyName: 'Smith & <Co>',
        inviteUrl: 'https://app.example/timeline?invite=ab12',
      );
      expect(mail.to, 'kim@example.com');
      expect(mail.subject, 'Invite to Smith & <Co>');
      expect(
        mail.text,
        "You're invited to join Smith & <Co> on Tell Me a Story.\n\n"
        'Accept the invite: https://app.example/timeline?invite=ab12\n\n'
        'This link expires in 7 days and can only be used once.',
      );
      expect(mail.html, contains('<strong>Smith &amp; &lt;Co&gt;</strong>'));
      expect(
        mail.html,
        contains('<a href="https://app.example/timeline?invite=ab12">'),
      );
      expect(
        mail.html,
        contains('This link expires in 7 days and can only be used once.'),
      );
    });
  });
}
