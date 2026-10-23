# E2E flow manifest

Lock: `docs/design-doc/e2e.md` (U1) and `docs/design-doc/e2e-addendum-a.md`. `e2e/check_flows.sh` checks this file in the `e2e` job. One row per flow. The test name is the exact `testWidgets` description in `e2e_test.dart`. Owning paths are relative to `apps/tell_me_a_story/lib/`.

| Flow | Test name | Spec source | Owning paths |
|---|---|---|---|
| C1 | `C1 magic-link sign-in lands on timeline` | §8 sign-in; M1; M8; `m08-profile.md`; §14 Automated #4 | `features/auth/`, `features/settings/`, `core/supabase/`, `core/router/`, `data/profile_session.dart` |
| C2 | `C2 start a family lands on its empty timeline` | US-1; M10; `m10-manage-families.md` | `features/family/`, `features/timeline/`, `data/families_api.dart` |
| C3 | `C3 capture and publish shows the card on the timeline` | US-3/3a/10; M3; M4; M14.1; publish lock; §14 Manual #1 | `features/stories/`, `features/people/`, `features/places/`, `features/timeline/`, `data/stories_api.dart`, `data/places_api.dart` |
| C4 | `C4 draft autosaves, resumes from drafts and publishes` | US-11; M14.4; `m14.4-drafts.md` | `features/drafts/`, `features/stories/`, `data/stories_api.dart` |
| C5 | `C5 reader adds a comment and a perspective` | US-6/6a; M5; M9; `m09-avatar-reader.md` | `features/stories/`, `features/comments/`, `features/perspectives/`, `data/comments_api.dart`, `data/perspectives_api.dart` |
| C6 | `C6 invite link lets a second user join and see the timeline` | US-2; M2; §8 accept-invite; `00-foundation.md` §5 | `features/invites/`, `features/auth/`, `features/timeline/`, `data/invite_api.dart` |
| C7 | `C7 search by person, place and timeframe finds the story` | US-9; M7 | `features/search/`, `data/search_api.dart` |
| C8 | `C8 user from another family sees no content on a story url` | §14 Automated #1; §13 | `features/stories/`, `core/router/` |
| C9 | `C9 sign out redirects guarded routes to the landing page` | router signed-out guard; M10 nav | `core/theme/album_header.dart`, `core/router/` |
