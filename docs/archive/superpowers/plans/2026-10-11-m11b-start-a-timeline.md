# M11b Start a new timeline — revised plan

> Planning only. No branch, no code, until Bill says go.
> After approval, copy this file to `docs/superpowers/plans/2026-10-11-m11b-start-a-timeline.md` in the first commit. Worktree `.worktrees/feat-m11b-start-a-timeline`, branch `feat/m11b-start-a-timeline`, from `origin/main` `3158f38090c2`. One milestone, one PR. Do not merge. Do not stamp CLOSED.
>
> Re-read 2026-10-11T20:33Z. Impl Spec §15 M11b is still **READY**, and the plan-review amendments are in the playbook. Where this plan and §15 differ, §15 wins.

## Changelog

| Item | Resolution |
| --- | --- |
| 1 Year prefill | **RESOLVED.** YEAR prefills from the chosen origin's `timeframeStart.year` on the reader entry, on a picker pick or Change, and when write-and-publish reopens create. One flutter test per path. |
| 2 Error copy | **RESOLVED.** Inline under the form, modal stays open. Never paint the bare Edge words `story` or `member only`. VALIDATION shows the Edge message. Menu NOT_FOUND: `That story isn't available anymore. Pick another one.` Reader NOT_FOUND: `That story isn't available anymore.` FORBIDDEN: `You're not a member of {Parent} anymore.` |
| 3 Deno missing parent | **RESOLVED.** Missing `parent_family_id` returns 400. Covered once, with T2. |
| 4 Edge pre-checks (OPENs 1 and 2) | **RESOLVED.** Messages `parent_family_id is required`, `origin_story_id is required`, `name is required`, `attach year must be four digits`. Code and message are separate fields, same shape as `create-root-family`. A year that is not a JSON integer (decimal, string, null, missing) is rejected here. The 1000–9999 check stays in the RPC only. |
| 5 OPEN 3 | **RESOLVED.** No "Your families" label. The shipped M10 menu block stays, plus one row `Start a new timeline` with no "+". |
| 6 OPEN 4 | **RESOLVED.** Bill dropped the indented Related-families tree from M11b. It stays on the carry list. The M12 Related families block ships unchanged. |
| 7 OPEN 5 | **RESOLVED.** The new row is only in the timeline page's header menu. |
| 8 OPEN 6 | **RESOLVED.** Cancel on the write path means leaving New Story without publishing (back or close). No new control. |
| 9 OPEN 7 | **RESOLVED.** A blank owner or member name shows `Member`, via the existing `displayNameOrMember`. |
| 10 OPEN 8 | **RESOLVED.** Picker search is a case-insensitive substring of the title. An empty search lists every published story. |
| 11 OPEN 9 | **RESOLVED.** Shared blur shell (sigma 4, scrim `0x662C2416`) becomes a private helper. `showFamilyBlurDialog`'s signature does not change. |
| 12 OPEN 10 | **RESOLVED.** In `a narrow origin ring opens the parent timeline`, delete the `parentDot` lookup and the if/else. After `expect(FamilySelection.id, parent)`, assert no `Child tale`, no `timeline-dot-child-story`, and one `The beginning`. |
| 13 OPEN 11 | **RESOLVED.** Dial-label ellipsis stays inside the label's existing slot. No new width limit. |
| T1 | **RESOLVED.** `create_branch_family` body as specified below. `search_path = ''`. Every table and function name schema-qualified. |
| T2 | **RESOLVED.** Same Deno case as item 3. One test. |
| T3 | **RESOLVED.** Three pgTAP order tests: non-member plus a bad origin raises `FORBIDDEN`; a null parent raises `FORBIDDEN`; a bad origin plus a blank name raises `NOT_FOUND`. |
| T4 | **RESOLVED.** Validate every UUID and each `person_ids` entry before the RPC. `mapRpcError` passes through only when the trimmed message starts with `VALIDATION:`, `NOT_FOUND:`, `FORBIDDEN:`, or `INVITE_INVALID:`. Anything else, including a prefix in the middle, becomes `Try again`. The client shows the message field only. |
| T5 | **RESOLVED.** No `FOR SHARE` on the parent or origin rows. Foreign keys are enough. Add no locking. |

## Still open

**Malformed UUID message, for Mugatu.** T4 says the Edge rejects a bad `parent_family_id`, `origin_story_id`, `owner_user_id`, or `person_ids` entry before the RPC. §15 does not give that sentence. The code uses `That id is not valid.` Status stays 400 `VALIDATION`. No new error code. The RPC is not called. Do not treat that sentence as renamed.

## Unchanged locks

- Seven RPC checks, this order, these strings: `FORBIDDEN: member only`, `NOT_FOUND: story` (colon required), `VALIDATION: name is required`, `VALIDATION: attach year must be four digits`, `VALIDATION: owner must be a member of the parent family`, `VALIDATION: members must come from the parent family`, `VALIDATION: too many levels`.
- Nesting cap 63. M12 walk cap 64 stays. Depth count: copied upward walk, start at the parent with depth 0, levels below the root are `max(depth)`, refuse when that max is 63 or more. A create whose parent walks to 62 succeeds (the new row is 63 down). The next create raises `VALIDATION: too many levels` and writes nothing.
- The starter is not auto-added. Any integer year 1000–9999 is allowed, including 2099. The column CHECK stays `null or 1..9999`.
- One migration: `supabase/migrations/20261011200000_start_a_timeline.sql`, after `20261011190823_origin_stories_hardening.sql`.
- Policy count stays 44. No new policy. Exact `qual` / `with_check` pins in `supabase/tests/origin_stories_hardening.sql` stay untouched and must still pass.
- `supabase migration up --local` only. Never `db reset`, `db pull`, or `migration down`.
- `flutter analyze` stays at 29 or fewer.
- Origin tag stays `Origin · from {Parent}`. Do not edit `originTag`.
- No parent-side revoke. No "Start a branch". No "+" on the new row. No dial-mark entry. No landing on the new timeline.

## What the build does

`create_branch_family` is security definer, `set search_path = ''`, `(select auth.uid())`, null uid fails closed. No `FOR SHARE`.

Same transaction, after the seven checks: insert `families` (trimmed name, parent, `created_by` = caller, `branch_year`); `pg_catalog.set_config('app.family_origin','on', true)`; update `origin_story_id`; set the flag off; backstop `public.family_origin(new.id) = p_origin_story_id` or raise `NOT_FOUND: story` and roll back; insert the owner membership; for each distinct person, copy `name`, `relationship`, `email`, `user_id` with `created_by` = caller, then `perform public.upsert_story_member(new.id, public.resolve_person_user(user_id, email))`. Conflict does nothing, so the owner stays owner. The caller's parent role does not change. Any error rolls the transaction back.

Grants: revoke from `public` and `anon`. Execute to `authenticated` and `service_role`.

Also in that migration, and nothing else:

```sql
alter table public.families
  add constraint families_parent_not_self
  check (parent_family_id is null or parent_family_id <> id);
```

Edge `POST /create-branch-family` uses `handleManage` and one user-scoped `rpc('create_branch_family', …)`. No service role. Pre-checks, before the RPC:

| Body | Status | code | message |
| --- | --- | --- | --- |
| Missing `parent_family_id` | 400 | `VALIDATION` | `parent_family_id is required` |
| Missing `origin_story_id` | 400 | `VALIDATION` | `origin_story_id is required` |
| Blank name | 400 | `VALIDATION` | `name is required` |
| Year not a JSON integer (decimal, string, JSON null, missing) | 400 | `VALIDATION` | `attach year must be four digits` |
| UUID or `person_ids` entry that is not a UUID | 400 | `VALIDATION` | sentence still open |

A JSON integer outside 1000–9999, including 999, is sent to the RPC. `mapRpcError` returns code `VALIDATION` and message `attach year must be four digits`. The message field does not contain `VALIDATION:`.

`mapRpcError` in `supabase/functions/_shared/manage.ts`: pass a message through only when the trimmed message starts with `VALIDATION:`, `NOT_FOUND:`, `FORBIDDEN:`, or `INVITE_INVALID:` (`startsWith`, not `indexOf`). The split stays today's split (code from the prefix, message is the text after it). The `NOT_FOUND:` colon match stays. A prefix in the middle of the message, and an unprefixed message, return the generic `Try again`. No new error code.

That fallback is the only output change. These functions call `mapRpcError`, so an unprefixed database error from any of them changes. A prefixed error from them does not:

- `create-root-family`
- `rename-family`
- `add-co-owner`
- `remove-co-owner`
- `remove-member`
- `transfer-ownership`
- `soft-delete-family`
- `recover-family`
- `revoke-invite`
- `resend-invite`

`accept-invite`, `create-invite`, `send-invite-email`, and `validate-invite-token` do not call `mapRpcError`. Their responses stay as they are. The repo has no Deno tests for those functions today, so there is no existing Deno assertion to keep green. Do not change their prefixed strings.

The client reads `message` only. It never paints a code prefix.

| Edge code | What the form shows |
| --- | --- |
| `VALIDATION` | The message as returned |
| `NOT_FOUND` on the menu path, including Change and write-and-publish | `That story isn't available anymore. Pick another one.` |
| `NOT_FOUND` on the reader path | `That story isn't available anymore.` |
| `FORBIDDEN` | `You're not a member of {Parent} anymore.` |
| Unprefixed / generic | Mugatu's sentence, once named |

Inline style is the one already under Start a family: Source Sans 3, 14px, `albumTerracotta`, directly under the form fields (`start_family_dialog.dart` around the `_error` text). The modal stays open.

YEAR prefill is `timeframeStart.year` and the field stays editable. A decade-only story already stores the decade's first year, so the 1970s prefill 1970. Set it again when the origin changes.

The timeline header, and only that header, inserts `Start a new timeline` between `+ Start a family` and `Manage families` when the caller is a live member of the open family. Drafts and New story do not grow the row. `AlbumHeader` grows an optional callback. Only `TimelinePage` sets it. No "Your families" label.

Picker: published rows from the timeline's `_published`, title plus year, no drafts, no grandparent origin. Search is `title.toLowerCase().contains(query.toLowerCase())`. Empty query shows all of those rows. `Write a new story` goes to `/stories/new?newTimelineFrom=<parentFamilyId>`. Publish with that query goes to `/timeline?newTimelineOrigin=<storyId>`, opens create once with Change, prefills the year, then clears the query. Save draft does not. Leaving New Story without publishing does not. Add no Cancel button.

Create form copy stays: placeholder `e.g. The Morgan-Reyes`, owner default `You`, blank names `Member`, members from `listPeople`, sage selected and outline unselected, `Attaches in *`, `You'll stay in {Parent}.`, Cancel ink outline, Create timeline terracotta. Disabled until name, owner, and a year in 1000–9999 are set. Change exists only on the menu path.

After success: close, reload `listFamilyTree` into `TimelinePage._tree`, reload published stories, toast `{Name} timeline created`, leave `FamilySelection` and the route on the parent.

Blur: extract the sigma-4 / `0x662C2416` shell from `family_blur_dialog.dart` into a private widget in that file. `showFamilyBlurDialog` keeps its parameters and its `bool` return. The picker and the create form use the helper. Do not change `start_family_dialog.dart` (it uses sigma 5 on purpose).

Carried, still in: lone Macro mark for a dated mark whose decade has no stories; dial-label ellipsis inside the current slot; name the `8`, `16`, and `2 * (8 + 16)` constants at the narrow origin slot; the right-edge check gets its own test; the ring-tap test edit below; the soft-deleted photo-delete pgTAP.

Not carried in this PR: indented whole-tree Related families.

Ring-tap test, file `apps/tell_me_a_story/test/timeline_page_test.dart`, test `a narrow origin ring opens the parent timeline`. The two expects for `Child tale` and `timeline-dot-child-story` already sit after `expect(FamilySelection.id, parent)`. Delete the `parentDot` lookup and the if/else that follows them (the tooltip branch and the text branch). Replace that if/else with `expect(find.text('The beginning'), findsOneWidget)`.

When that test is run: if the family change resets zoom and that reset is intended, tap `timeline-zoom-full` again before the `The beginning` assert and say why in a comment. If the reset is not intended, stop and report it. Do not change the assert to hide it.

## File map

| Change | File |
| --- | --- |
| Create. Constraint, function, grants. | `supabase/migrations/20261011200000_start_a_timeline.sql` |
| Create. pgTAP, including T3 and the photo case. | `supabase/tests/start_timeline.sql` |
| Do not edit. Re-run the policy pins. | `supabase/tests/origin_stories_hardening.sql` |
| Create. Wrapper. | `supabase/functions/create-branch-family/index.ts` |
| Create. Deno. | `supabase/functions/create-branch-family/index_test.ts` |
| Edit the unprefixed fallback only. | `supabase/functions/_shared/manage.ts` |
| Add `createBranchFamily`. | `apps/tell_me_a_story/lib/data/manage_families_api.dart` |
| Add `listMembers`. `loadDetail` uses it. | `apps/tell_me_a_story/lib/data/families_api.dart` |
| Reader menu item. | `apps/tell_me_a_story/lib/features/stories/story_reader_page.dart` |
| Optional start-timeline callback. Default off. | `apps/tell_me_a_story/lib/core/theme/album_header.dart` |
| Timeline-only row, picker open, query reopen, toast, reload. | `apps/tell_me_a_story/lib/features/timeline/timeline_page.dart` |
| Publish routing only. | `apps/tell_me_a_story/lib/features/stories/new_story_page.dart` |
| Create. Picker and create form. | `apps/tell_me_a_story/lib/features/family/start_timeline_dialog.dart` |
| Extract the private blur shell. Signature unchanged. | `apps/tell_me_a_story/lib/features/family/family_blur_dialog.dart` |
| Lone mark, named constants, dial ellipsis. | `timeline_page.dart`, `apps/tell_me_a_story/lib/features/timeline/timeline_zoom.dart` |
| Menu order on the timeline. Ring-tap edit. Carried mark tests. | `apps/tell_me_a_story/test/timeline_page_test.dart` |
| Reader item hidden and shown. | `apps/tell_me_a_story/test/story_reader_page_test.dart` |
| Header without the timeline flag still has no new row. | `apps/tell_me_a_story/test/m10_navigation_test.dart` |
| Create. Picker, year, copy, gateway, toast. | `apps/tell_me_a_story/test/start_timeline_test.dart` |

No `config.toml` stanza. No new route, table, column, enum, policy, or package. Do not edit `families_guard_update`, `set_family_origin`, `family_tree_root`, or `originTag`.

## Tests

Red first, then the code that turns them green. Paste `supabase test db`, `deno test`, `flutter test`, and `flutter analyze`.

### pgTAP — `supabase/tests/start_timeline.sql`

Success for a member, a co-owner, and an owner: row fields, `family_origin` returns the origin, `list_family_tree` and `list_origin_dependents` include the new family, exactly one owner.

Future year 2099 is stored.

Not auto-added: a member starter picks user B as owner and does not pick a person who resolves to the starter. No membership for the starter on the new family. Starter's `set_family_origin` raises `FORBIDDEN`. B's succeeds. A direct `origin_story_id` update raises `FORBIDDEN: field is locked`.

People: one with `user_id`, one with a matching email, one with no account. Owner role preserved when the owner is also picked. People-row count equals the distinct picks.

`NOT_FOUND: story`, and no new family, for a random uuid, a draft, another family, a sibling, the grandparent, and null. A grandchild whose origin is a root story gets the same error.

`FORBIDDEN: member only` for a tree reader who is not a member, a stranger, a null uid, and a member of a soft-deleted parent.

**T3, check order.** A non-member whose `origin_story_id` is also bad gets `FORBIDDEN`, not `NOT_FOUND`. A null `parent_family_id` gets `FORBIDDEN`. A member whose origin is bad and whose name is blank gets `NOT_FOUND`, not `VALIDATION: name is required`.

`VALIDATION: name is required` for a blank name, once the origin is valid. `VALIDATION: attach year must be four digits` for null, 987, and 10000. 1000 and 9999 succeed. `VALIDATION: owner must be a member of the parent family` for a null owner and for a user who is not a parent member. `VALIDATION: members must come from the parent family` for a foreign person. Depth 63 succeeds. The next level is refused and writes nothing.

Atomicity: after the foreign-person error, that call wrote no family, membership, or origin.

Authenticated `insert into families` is 42501. Service-role self-parent insert is 23514. A `parent_family_id` update raises `FORBIDDEN: field is locked`.

Anon has no execute. Authenticated does. `pg_proc.proconfig` contains `search_path=""`. The function is called once in this file.

Policy count is 44 in this file. Then the unchanged hardening file still passes its exact policy text.

A member of a soft-deleted family deletes 0 `photos` rows and 0 `story-photos` objects.

### Deno — `supabase/functions/create-branch-family/index_test.ts`

Export the handler. Inject the RPC.

- No JWT → 401 `AUTH_REQUIRED`.
- Missing `parent_family_id` → 400, code `VALIDATION`, message `parent_family_id is required`. RPC not called. This is item 3 and T2.
- Missing `origin_story_id` → 400, message `origin_story_id is required`.
- Blank name → 400, message `name is required`.
- Year `1972.5`, year `"1972"`, year `null`, year omitted → 400, message `attach year must be four digits`. RPC not called.
- Year JSON integer `999` → RPC is called. Response code `VALIDATION`, message exactly `attach year must be four digits`, and that message does not contain `VALIDATION:`.
- Unprefixed database error → response message is not the raw text and has no `VALIDATION:` prefix. Exact sentence waits on Mugatu.
- Malformed UUID and a bad `person_ids` entry → 400, RPC not called. Exact sentence waits on Mugatu.
- RPC `NOT_FOUND: story` → 404, code `NOT_FOUND`, message `story`.
- RPC `FORBIDDEN: member only` → 403, code `FORBIDDEN`, message `member only`.
- Success → 201 `{ "family_id": "<id>" }`. One RPC call. No service-role client.

### Flutter

Reader: a member on a published story sees `Start a new timeline from this story`. A draft, a tree reader, and a borrowed origin for a non-member do not. Opening it shows no Change control, and the year field is that story's `timeframeStart.year`.

Timeline menu: families, divider, `+ Start a family`, `Start a new timeline`, `Manage families` when manage is shown. The new text is not `+ Start a new timeline`. A tree-read open family hides the row. `m10_navigation_test.dart` builds the header without the timeline callback and still does not show the row.

Picker: published titles only. Search `morgan` matches `The Morgans` and not a draft. Empty search lists every published row. `Write a new story` routes to `/stories/new?newTimelineFrom=<parentId>`.

Year, three tests: reader open prefills the reader story's year; Change to a second story replaces the year with that story's year; publish with `newTimelineFrom` reopens create on that new story's year.

Write path: Save draft does not call the gateway and does not set `newTimelineOrigin`. Popping New Story without publishing does not either. There is no new Cancel control.

Create form: disabled until name, owner, and a year in 1000–9999 are set. Default owner text is `You`. A blank display name reads `Member`. Year 2099 can submit. Year 987 cannot. The gateway receives the parent id, origin id, trimmed name, year, owner id, and picked person ids.

Copy tests: a VALIDATION message `name is required` is shown as that sentence. Menu-path NOT_FOUND shows `That story isn't available anymore. Pick another one.` Reader-path NOT_FOUND shows `That story isn't available anymore.` FORBIDDEN shows `You're not a member of {Parent} anymore.` The form never shows `story` or `member only`. The modal is still open. A generic failure shows Mugatu's sentence once it exists, in that same inline spot, and does not show the raw database text.

After create: toast `{Name} timeline created`, `listFamilyTree` runs again, `FamilySelection.id` is unchanged, the route stays on the parent.

Origin tag still reads `Origin · from {Parent}` and not `Origin · from {Parent} Family`.

Carried: a dated Macro mark in an empty decade paints one lone mark. A long dial label ellipsizes without a new width constant. The right-edge full-card check is its own test. The ring-tap test matches the edit above.

`flutter analyze` in `apps/tell_me_a_story`: 29 or fewer. Do not clean up the existing 29.

## Out of scope

Dial or mark entries. "Start a branch". A timeline with no origin. A pending state. Landing on the new timeline. A future-year ban. Editing `branch_year` later. Co-owner assignment. A clear-origin RPC. Copying the origin story. Parent-side revoke. Re-parenting or merging. M13. The indented Related-families tree. Any new table, column, enum, policy, route, or package. Editing earlier migrations. `db reset`, `db pull`, `migration down`. Stamping CLOSED.
