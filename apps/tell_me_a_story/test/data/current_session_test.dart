import 'package:flutter_test/flutter_test.dart';
import 'package:tell_me_a_story/data/current_session.dart';
import 'package:tell_me_a_story/data/families_api.dart';

void main() {
  test('signed-out session has no user id and requireUserId throws', () {
    expect(CurrentSession.userId, isNull);
    expect(CurrentSession.isSignedIn, isFalse);
    expect(CurrentSession.requireUserId, throwsA(isA<NotSignedInException>()));
  });
}
