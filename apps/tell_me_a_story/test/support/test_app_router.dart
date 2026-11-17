import 'package:go_router/go_router.dart';

import 'package:tell_me_a_story/core/router/app_router.dart';
import 'package:tell_me_a_story/core/router/auth_refresh.dart';
import 'package:tell_me_a_story/data/comments_api.dart';
import 'package:tell_me_a_story/data/families_api.dart';
import 'package:tell_me_a_story/data/invite_api.dart';
import 'package:tell_me_a_story/data/people_api.dart';
import 'package:tell_me_a_story/data/photos_api.dart';
import 'package:tell_me_a_story/data/stories_api.dart';
import 'package:tell_me_a_story/data/perspectives_api.dart';

import '../fakes/fake_invite_api.dart';
import '../fakes/quiet_stories.dart';
import 'quiet_gateways.dart';

/// Signed-in router for widget tests: every gateway is stubbed (no Supabase init).
GoRouter testAppRouter({
  required AuthRefresh authRefresh,
  InviteGateway? inviteApi,
  StoriesGateway? storiesApi,
  FamiliesGateway? familiesApi,
  PhotosGateway? photosApi,
  PeopleGateway? peopleApi,
  CommentsGateway? commentsApi,
  PerspectivesGateway? perspectivesApi,
}) {
  return createAppRouter(
    authRefresh: authRefresh,
    inviteApi: inviteApi ?? FakeInviteApi(),
    storiesApi: storiesApi ?? QuietStories(),
    familiesApi: familiesApi ?? TestFamilies.member(),
    photosApi: photosApi ?? QuietPhotos(),
    peopleApi: peopleApi ?? QuietPeople(),
    commentsApi: commentsApi,
    perspectivesApi: perspectivesApi,
  );
}
