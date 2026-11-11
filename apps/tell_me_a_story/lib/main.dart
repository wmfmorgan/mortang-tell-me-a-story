import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:serverpod_auth_core_flutter/serverpod_auth_core_flutter.dart';

import 'package:tell_me_a_story/app.dart';
import 'package:tell_me_a_story/core/data/server_comments_repository.dart';
import 'package:tell_me_a_story/core/data/server_families_repository.dart';
import 'package:tell_me_a_story/core/data/server_family_covers_repository.dart';
import 'package:tell_me_a_story/core/data/server_invite_link_repository.dart';
import 'package:tell_me_a_story/core/data/server_invite_repository.dart';
import 'package:tell_me_a_story/core/data/server_manage_families_repository.dart';
import 'package:tell_me_a_story/core/data/server_mapbox_search_repository.dart';
import 'package:tell_me_a_story/core/data/server_people_repository.dart';
import 'package:tell_me_a_story/core/data/server_perspectives_repository.dart';
import 'package:tell_me_a_story/core/data/server_photos_repository.dart';
import 'package:tell_me_a_story/core/data/server_places_repository.dart';
import 'package:tell_me_a_story/core/data/server_profile_repository.dart';
import 'package:tell_me_a_story/core/data/server_stories_repository.dart';
import 'package:tell_me_a_story/core/domain/comments_repository.dart';
import 'package:tell_me_a_story/core/domain/families_repository.dart';
import 'package:tell_me_a_story/core/domain/family_covers_repository.dart';
import 'package:tell_me_a_story/core/domain/family_directory_repository.dart';
import 'package:tell_me_a_story/core/domain/invite_link_repository.dart';
import 'package:tell_me_a_story/core/domain/invite_repository.dart';
import 'package:tell_me_a_story/core/domain/manage_families_repository.dart';
import 'package:tell_me_a_story/core/domain/mapbox_search_repository.dart';
import 'package:tell_me_a_story/core/domain/people_repository.dart';
import 'package:tell_me_a_story/core/domain/perspectives_repository.dart';
import 'package:tell_me_a_story/core/domain/photos_repository.dart';
import 'package:tell_me_a_story/core/domain/places_repository.dart';
import 'package:tell_me_a_story/core/domain/profile_repository.dart';
import 'package:tell_me_a_story/core/domain/stories_repository.dart';
import 'package:tell_me_a_story/core/domain/story_thumbs.dart';
import 'package:tell_me_a_story/core/env.dart';
import 'package:tell_me_a_story/core/router/url_strategy_stub.dart'
    if (dart.library.html) 'package:tell_me_a_story/core/router/url_strategy_web.dart';
import 'package:tell_me_a_story/core/server/app_session.dart';
import 'package:tell_me_a_story/core/server/server_client.dart';
import 'package:tell_me_a_story/core/session/auth_info.dart';
import 'package:tell_me_a_story/core/session/family_selection.dart';
import 'package:tell_me_a_story/core/widgets/navigation/before_unload_stub.dart'
    if (dart.library.js_interop) 'package:tell_me_a_story/core/widgets/navigation/before_unload_web.dart';
import 'package:tell_me_a_story/features/auth/data/server_otp_sign_in.dart';
import 'package:tell_me_a_story/features/auth/domain/otp_sign_in.dart';
import 'package:tell_me_a_story/features/search/data/server_search_repository.dart';
import 'package:tell_me_a_story/features/search/domain/search_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  configureUrlStrategy();
  installBeforeUnloadGuard();
  Env.validate();
  // An unreadable saved session starts the app signed out.
  await initServer(storage: appAuthStorage());

  runApp(ProviderScope(overrides: _serverOverrides(), child: const App()));
}

/// Composition root: every repository provider gets its server implementation.
List<Override> _serverOverrides() {
  final families = ServerFamiliesRepository();
  return [
    authInfoProvider.overrideWithValue(serverClient.auth.authInfoListenable),
    commentsRepositoryProvider.overrideWithValue(ServerCommentsRepository()),
    familiesRepositoryProvider.overrideWithValue(families),
    familyDirectoryRepositoryProvider.overrideWithValue(families),
    familyCoversRepositoryProvider.overrideWithValue(
      ServerFamilyCoversRepository(),
    ),
    inviteLinkRepositoryProvider.overrideWithValue(
      ServerInviteLinkRepository(),
    ),
    inviteRepositoryProvider.overrideWith(
      (ref) => ServerInviteRepository(
        currentFamilyId: () => ref.read(familySelectionProvider),
      ),
    ),
    manageFamiliesRepositoryProvider.overrideWithValue(
      ServerManageFamiliesRepository(),
    ),
    mapboxSearchRepositoryProvider.overrideWithValue(
      ServerMapboxSearchRepository(),
    ),
    peopleRepositoryProvider.overrideWithValue(ServerPeopleRepository()),
    perspectivesRepositoryProvider.overrideWithValue(
      ServerPerspectivesRepository(),
    ),
    photosRepositoryProvider.overrideWithValue(ServerPhotosRepository()),
    placesRepositoryProvider.overrideWithValue(ServerPlacesRepository()),
    profileRepositoryProvider.overrideWithValue(ServerProfileRepository()),
    storiesRepositoryProvider.overrideWithValue(ServerStoriesRepository()),
    storyThumbsLoaderProvider.overrideWithValue(
      (stories) => downloadFirstThumbs(stories, null),
    ),
    otpSignInProvider.overrideWithValue(ServerOtpSignIn()),
    searchRepositoryProvider.overrideWithValue(ServerSearchRepository()),
  ];
}
