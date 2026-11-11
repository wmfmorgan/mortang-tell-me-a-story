# E2E flow manifest

Lock: `docs/archive/design-doc/e2e.md` (U1) and `docs/archive/design-doc/e2e-addendum-a.md`. `test/architecture/e2e_flow_manifest_test.dart` checks this file in `flutter test`. One row per flow. The test name is the exact `testWidgets` description in `e2e_test.dart`. Owning paths are relative to `apps/tell_me_a_story/lib/`.

| Flow | Test name | Spec source | Owning paths |
|---|---|---|---|
| C1 | `C1 email-code sign-in lands on timeline` | §8 sign-in; M1; M8; `m08-profile.md`; §14 Automated #4 | `features/auth/`, `features/settings/`, `core/server/`, `core/router/`, `app.dart`, `core/session/` |
| C2 | `C2 start a family lands on family landing` | US-1; M10; M22; `79-family-landing.md` | `features/family/`, `core/data/` |
| C3 | `C3 capture and publish shows the card on the timeline` | US-3/3a/10; M3; M4; M14.1; publish lock; §14 Manual #1 | `features/stories/`, `features/people/`, `features/places/`, `features/timeline/`, `core/data/` |
| C4 | `C4 draft autosaves, resumes from drafts and publishes` | US-11; M14.4; `m14.4-drafts.md` | `features/drafts/`, `features/stories/`, `core/data/` |
| C5 | `C5 reader adds a comment and a perspective` | US-6/6a; M5; M9; `m09-avatar-reader.md` | `features/stories/`, `features/comments/`, `features/perspectives/`, `core/data/` |
| C6 | `C6 invite link lets a second user join and see the timeline` | US-2; M2; §8 accept-invite; `00-foundation.md` §5 | `features/invites/`, `features/auth/`, `features/timeline/`, `core/data/` |
| C7 | `C7 search by person, place and timeframe finds the story` | US-9; M7 | `features/search/`, `core/data/` |
| C8 | `C8 user from another family sees no content on a story url` | §14 Automated #1; §13 | `features/stories/`, `core/router/`, `app.dart` |
| C9 | `C9 sign out redirects guarded routes to the landing page` | router signed-out guard; M10 nav | `core/widgets/album/album_header.dart`, `core/router/`, `app.dart` |
