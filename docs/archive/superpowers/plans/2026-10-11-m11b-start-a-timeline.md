# M11b Start a new timeline — revised plan

> Planning only. No branch, no code until Bill says go.
> After approval, copy file to `docs/superpowers/plans/2026-10-11-m11b-start-a-timeline.md` in first commit. Worktree `.worktrees/feat-m11b-start-a-timeline`, branch `feat/m11b-start-a-timeline`, from `origin/main` `3158f38090c2`. One milestone, one PR. No merge. No CLOSED stamp.
>
> Re-read 2026-10-11T20:33Z. Impl Spec §15 M11b still **READY**; plan-review amendments in playbook. Plan vs §15 conflict → §15 wins.

## Changelog

| Item | Resolution |
| --- | --- |
| 1 Year prefill | **RESOLVED.** YEAR prefills from chosen origin's `timeframeStart.year` on reader entry, picker pick or Change, and when write-and-publish reopens create. One flutter test per path. |
| 2 Error copy | **RESOLVED.** Inline under form, modal stays open. Never paint bare Edge words `story` or `member only`. VALIDATION shows Edge message. Menu NOT_FOUND: `That story isn't available anymore. Pick another one.` Reader NOT_FOUND: `That story isn't available anymore.` FORBIDDEN: `You're not a member of {Parent} anymore.` |
| 3 Deno missing parent | **RESOLVED.** Missing `parent_family_id` → 400. Covered once, with T2. |
| 4 Edge pre-checks (OPENs 1 and 2) | **RESOLVED.** Messages `parent_family_id is required`, `origin_story_id is required`, `name is required`, `attach year must be four digits`. Code and message separate fields, same shape as `create-root-family`. Year not JSON integer (decimal, string, null, missing) rejected here. 1000–9999 check stays RPC-only. |
| 5 OPEN 3 | **RESOLVED.** No "Your families" label. Shipped M10 menu block stays, plus one row `Start a new timeline`, no "+". |
| 6 OPEN 4 | **RESOLVED.** Bill dropped indented Related-families tree from M11b. Stays on carry list. M12 Related families block ships unchanged. |
| 7 OPEN 5 | **RESOLVED.** New row only in timeline page header menu. |
| 8 OPEN 6 | **RESOLVED.** Cancel on write path = leave New Story without publishing (back or close). No new control. |
| 9 OPEN 7 | **RESOLVED.** Blank owner/member name shows `Member`, via existing `displayNameOrMember`. |
| 10 OPEN 8 | **RESOLVED.** Picker search = case-insensitive title substring. Empty search lists every published story. |
| 11 OPEN 9 | **RESOLVED.** Shared blur shell (sigma 4, scrim `0x662C2416`) → private helper. `showFamilyBlurDialog` signature unchanged. |
| 12 OPEN 10 | **RESOLVED.** In `a narrow origin ring opens the parent timeline`, delete `parentDot` lookup and if/else. After `expect(FamilySelection.id, parent)`, assert no `Child tale`, no `timeline-dot-child-story`, one `The beginning`. |
| 13 OPEN 11 | **RESOLVED.** Dial-label ellipsis stays in label's existing slot. No new width limit. |
| T1 | **RESOLVED.** `create_branch_family` body as below. `search_path = ''`. Every table/function name schema-qualified. |
| T2 | **RESOLVED.** Same Deno case as item 3. One test. |
| T3 | **RESOLVED.** Three pgTAP order tests: non-member + bad origin raises `FORBIDDEN`; null parent raises `FORBIDDEN`; bad origin + blank name raises `NOT_FOUND`. |
| T4 | **RESOLVED.** Validate every UUID and each `person_ids` entry before RPC. `mapRpcError` passes through only when trimmed message starts with `VALIDATION:`, `NOT_FOUND:`, `FORBIDDEN:`, or `INVITE_INVALID:`. Else, incl. mid-message prefix → `Try again`. Client shows message field only. |
| T5 | **RESOLVED.** No `FOR SHARE` on parent or origin rows. Foreign keys enough. No locking. |

## Still open

**Malformed UUID message, for Mugatu.** T4: Edge rejects bad `parent_family_id`, `origin_story_id`, `owner_user_id`, or `person_ids` entry before RPC. §15 gives no sentence. Code uses `That id is not valid.` Status stays 400 `VALIDATION`. No new error code. RPC not called. Don't treat sentence as renamed.

## Unchanged locks

- Seven RPC checks, this order, these strings: `FORBIDDEN: member only`, `NOT_FOUND: story` (colon required), `VALIDATION: name is required`, `VALIDATION: attach year must be four digits`, `VALIDATION: owner must be a member of the parent family`, `VALIDATION: members must come from the parent family`, `VALIDATION: too many levels`.
- Nesting cap 63. M12 walk cap 64 stays. Depth count: copied upward walk, start at parent depth 0, levels below root = `max(depth)`, refuse when max ≥ 63. Create whose parent walks to 62 succeeds (new row 63 down). Next create raises `VALIDATION: too many levels`, writes nothing.
- Starter not auto-added. Any integer year 1000–9999 allowed, incl. 2099. Column CHECK stays `null or 1..9999`.
- One migration: `supabase/migrations/20261011200000_start_a_timeline.sql`, after `20261011190823_origin_stories_hardening.sql`.
- Policy count stays 44. No new policy. Exact `qual` / `with_check` pins in `supabase/tests/origin_stories_hardening.sql` untouched, must still pass.
- `supabase migration up --local` only. Never `db reset`, `db pull`, or `migration down`.
- `flutter analyze` stays ≤ 29.
- Origin tag stays `Origin · from {Parent}`. Don't edit `originTag`.
- No parent-side revoke. No "Start a branch". No "+" on new row. No dial-mark entry. No landing on new timeline.

## What the build does

`create_branch_family` is security definer, `set search_path = ''`, `(select auth.uid())`, null uid fails closed. No `FOR SHARE`.

Same transaction, after seven checks: insert `families` (trimmed name, parent, `created_by` = caller, `branch_year`); `pg_catalog.set_config('app.family_origin','on', true)`; update `origin_story_id`; flag off; backstop `public.family_origin(new.id) = p_origin_story_id` or raise `NOT_FOUND: story` and roll back; insert owner membership; per distinct person, copy `name`, `relationship`, `email`, `user_id` with `created_by` = caller, then `perform public.upsert_story_member(new.id, public.resolve_person_user(user_id, email))`. Conflict does nothing → owner stays owner. Caller's parent role unchanged. Any error rolls back.

Grants: revoke from `public` and `anon`. Execute to `authenticated` and `service_role`.

Also in that migration, nothing else:

```sql
alter table public.families
  add constraint families_parent_not_self
  check (parent_family_id is null or parent_family_id <> id);
```

Edge `POST /create-branch-family` uses `handleManage` and one user-scoped `rpc('create_branch_family', …)`. No service role. Pre-checks before RPC:

| Body | Status | code | message |
| --- | --- | --- | --- |
| Missing `parent_family_id` | 400 | `VALIDATION` | `parent_family_id is required` |
| Missing `origin_story_id` | 400 | `VALIDATION` | `origin_story_id is required` |
| Blank name | 400 | `VALIDATION` | `name is required` |
| Year not JSON integer (decimal, string, JSON null, missing) | 400 | `VALIDATION` | `attach year must be four digits` |
| UUID or `person_ids` entry not a UUID | 400 | `VALIDATION` | sentence still open |

JSON integer outside 1000–9999, incl. 999, goes to RPC. `mapRpcError` returns code `VALIDATION`, message `attach year must be four digits`. Message field has no `VALIDATION:`.

`mapRpcError` in `supabase/functions/_shared/manage.ts`: pass message through only when trimmed message starts with `VALIDATION:`, `NOT_FOUND:`, `FORBIDDEN:`, or `INVITE_INVALID:` (`startsWith`, not `indexOf`). Split unchanged (code from prefix, message = text after). `NOT_FOUND:` colon match stays. Mid-message prefix and unprefixed message → generic `Try again`. No new error code.

Fallback is only output change. These call `mapRpcError`, so unprefixed DB errors from them change; prefixed don't:

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

`accept-invite`, `create-invite`, `send-invite-email`, `validate-invite-token` don't call `mapRpcError`. Responses unchanged. Repo has no Deno tests for them today → no existing assertion to keep green. Don't change their prefixed strings.

Client reads `message` only. Never paints code prefix.

| Edge code | What the form shows |
| --- | --- |
| `VALIDATION` | Message as returned |
| `NOT_FOUND` on menu path, incl. Change and write-and-publish | `That story isn't available anymore. Pick another one.` |
| `NOT_FOUND` on reader path | `That story isn't available anymore.` |
| `FORBIDDEN` | `You're not a member of {Parent} anymore.` |
| Unprefixed / generic | Mugatu's sentence, once named |

Inline style = existing one under Start a family: Source Sans 3, 14px, `albumTerracotta`, directly under form fields (`start_family_dialog.dart` near `_error` text). Modal stays open.

YEAR prefill = `timeframeStart.year`, field editable. Decade-only story already stores decade's first year → 1970s prefill 1970. Reset when origin changes.

Timeline header only inserts `Start a new timeline` between `+ Start a family` and `Manage families` when caller is live member of open family. Drafts and New story don't get row. `AlbumHeader` gets optional callback. Only `TimelinePage` sets it. No "Your families" label.

Picker: published rows from timeline's `_published`, title + year, no drafts, no grandparent origin. Search `title.toLowerCase().contains(query.toLowerCase())`. Empty query → all rows. `Write a new story` → `/stories/new?newTimelineFrom=<parentFamilyId>`. Publish with that query → `/timeline?newTimelineOrigin=<storyId>`, opens create once with Change, prefills year, clears query. Save draft doesn't. Leaving New Story unpublished doesn't. No Cancel button.

Create form copy unchanged: placeholder `e.g. The Morgan-Reyes`, owner default `You`, blank names `Member`, members from `listPeople`, sage selected / outline unselected, `Attaches in *`, `You'll stay in {Parent}.`, Cancel ink outline, Create timeline terracotta. Disabled until name, owner, year 1000–9999 set. Change only on menu path.

After success: close, reload `listFamilyTree` into `TimelinePage._tree`, reload published stories, toast `{Name} timeline created`, keep `FamilySelection` and route on parent.

Blur: extract sigma-4 / `0x662C2416` shell from `family_blur_dialog.dart` into private widget in same file. `showFamilyBlurDialog` keeps params and `bool` return. Picker and create form use helper. Don't change `start_family_dialog.dart` (sigma 5 on purpose).

Carried, still in: lone Macro mark for dated mark whose decade has no stories; dial-label ellipsis in current slot; name `8`, `16`, `2 * (8 + 16)` constants at narrow origin slot; right-edge check gets own test; ring-tap test edit below; soft-deleted photo-delete pgTAP.

Not carried this PR: indented whole-tree Related families.

Ring-tap test, file `apps/tell_me_a_story/test/timeline_page_test.dart`, test `a narrow origin ring opens the parent timeline`. Two expects for `Child tale` and `timeline-dot-child-story` already after `expect(FamilySelection.id, parent)`. Delete `parentDot` lookup and following if/else (tooltip branch and text branch). Replace with `expect(find.text('The beginning'), findsOneWidget)`.

When run: if family change resets zoom and reset intended, tap `timeline-zoom-full` again before `The beginning` assert, explain in comment. If not intended, stop and report. Don't change assert to hide it.

## File map

| Change | File |
| --- | --- |
| Create. Constraint, function, grants. | `supabase/migrations/20261011200000_start_a_timeline.sql` |
| Create. pgTAP, incl. T3 and photo case. | `supabase/tests/start_timeline.sql` |
| Don't edit. Re-run policy pins. | `supabase/tests/origin_stories_hardening.sql` |
| Create. Wrapper. | `supabase/functions/create-branch-family/index.ts` |
| Create. Deno. | `supabase/functions/create-branch-family/index_test.ts` |
| Edit unprefixed fallback only. | `supabase/functions/_shared/manage.ts` |
| Add `createBranchFamily`. | `apps/tell_me_a_story/lib/data/manage_families_api.dart` |
| Add `listMembers`. `loadDetail` uses it. | `apps/tell_me_a_story/lib/data/families_api.dart` |
| Reader menu item. | `apps/tell_me_a_story/lib/features/stories/story_reader_page.dart` |
| Optional start-timeline callback. Default off. | `apps/tell_me_a_story/lib/core/theme/album_header.dart` |
| Timeline-only row, picker open, query reopen, toast, reload. | `apps/tell_me_a_story/lib/features/timeline/timeline_page.dart` |
| Publish routing only. | `apps/tell_me_a_story/lib/features/stories/new_story_page.dart` |
| Create. Picker and create form. | `apps/tell_me_a_story/lib/features/family/start_timeline_dialog.dart` |
| Extract private blur shell. Signature unchanged. | `apps/tell_me_a_story/lib/features/family/family_blur_dialog.dart` |
| Lone mark, named constants, dial ellipsis. | `timeline_page.dart`, `apps/tell_me_a_story/lib/features/timeline/timeline_zoom.dart` |
| Menu order on timeline. Ring-tap edit. Carried mark tests. | `apps/tell_me_a_story/test/timeline_page_test.dart` |
| Reader item hidden and shown. | `apps/tell_me_a_story/test/story_reader_page_test.dart` |
| Header without timeline flag still no new row. | `apps/tell_me_a_story/test/m10_navigation_test.dart` |
| Create. Picker, year, copy, gateway, toast. | `apps/tell_me_a_story/test/start_timeline_test.dart` |

No `config.toml` stanza. No new route, table, column, enum, policy, package. Don't edit `families_guard_update`, `set_family_origin`, `family_tree_root`, or `originTag`.

## Tests

Red first, then code to green. Paste `supabase test db`, `deno test`, `flutter test`, `flutter analyze`.

### pgTAP — `supabase/tests/start_timeline.sql`

Success for member, co-owner, owner: row fields, `family_origin` returns origin, `list_family_tree` and `list_origin_dependents` include new family, exactly one owner.

Future year 2099 stored.

Not auto-added: member starter picks user B as owner, doesn't pick person resolving to starter. No starter membership on new family. Starter's `set_family_origin` raises `FORBIDDEN`. B's succeeds. Direct `origin_story_id` update raises `FORBIDDEN: field is locked`.

People: one with `user_id`, one with matching email, one with no account. Owner role preserved when owner also picked. People-row count = distinct picks.

`NOT_FOUND: story`, no new family, for random uuid, draft, other family, sibling, grandparent, null. Grandchild whose origin is root story gets same error.

`FORBIDDEN: member only` for non-member tree reader, stranger, null uid, member of soft-deleted parent.

**T3, check order.** Non-member with bad `origin_story_id` gets `FORBIDDEN`, not `NOT_FOUND`. Null `parent_family_id` gets `FORBIDDEN`. Member with bad origin and blank name gets `NOT_FOUND`, not `VALIDATION: name is required`.

`VALIDATION: name is required` for blank name once origin valid. `VALIDATION: attach year must be four digits` for null, 987, 10000. 1000 and 9999 succeed. `VALIDATION: owner must be a member of the parent family` for null owner and non-parent-member user. `VALIDATION: members must come from the parent family` for foreign person. Depth 63 succeeds. Next level refused, writes nothing.

Atomicity: after foreign-person error, call wrote no family, membership, or origin.

Authenticated `insert into families` → 42501. Service-role self-parent insert → 23514. `parent_family_id` update raises `FORBIDDEN: field is locked`.

Anon no execute. Authenticated has. `pg_proc.proconfig` contains `search_path=""`. Function called once in file.

Policy count 44 in this file. Then unchanged hardening file still passes exact policy text.

Member of soft-deleted family deletes 0 `photos` rows and 0 `story-photos` objects.

### Deno — `supabase/functions/create-branch-family/index_test.ts`

Export handler. Inject RPC.

- No JWT → 401 `AUTH_REQUIRED`.
- Missing `parent_family_id` → 400, code `VALIDATION`, message `parent_family_id is required`. RPC not called. Item 3 and T2.
- Missing `origin_story_id` → 400, message `origin_story_id is required`.
- Blank name → 400, message `name is required`.
- Year `1972.5`, `"1972"`, `null`, omitted → 400, message `attach year must be four digits`. RPC not called.
- Year JSON integer `999` → RPC called. Code `VALIDATION`, message exactly `attach year must be four digits`, no `VALIDATION:` in message.
- Unprefixed DB error → message not raw text, no `VALIDATION:` prefix. Exact sentence waits on Mugatu.
- Malformed UUID and bad `person_ids` entry → 400, RPC not called. Exact sentence waits on Mugatu.
- RPC `NOT_FOUND: story` → 404, code `NOT_FOUND`, message `story`.
- RPC `FORBIDDEN: member only` → 403, code `FORBIDDEN`, message `member only`.
- Success → 201 `{ "family_id": "<id>" }`. One RPC call. No service-role client.

### Flutter

Reader: member on published story sees `Start a new timeline from this story`. Draft, tree reader, borrowed origin for non-member don't. Opening shows no Change control; year field = story's `timeframeStart.year`.

Timeline menu: families, divider, `+ Start a family`, `Start a new timeline`, `Manage families` when manage shown. New text not `+ Start a new timeline`. Tree-read open family hides row. `m10_navigation_test.dart` builds header without timeline callback, row still absent.

Picker: published titles only. Search `morgan` matches `The Morgans`, not draft. Empty search lists every published row. `Write a new story` routes to `/stories/new?newTimelineFrom=<parentId>`.

Year, three tests: reader open prefills reader story's year; Change to second story replaces year with its year; publish with `newTimelineFrom` reopens create on new story's year.

Write path: Save draft doesn't call gateway or set `newTimelineOrigin`. Popping New Story unpublished doesn't either. No new Cancel control.

Create form: disabled until name, owner, year 1000–9999 set. Default owner text `You`. Blank display name reads `Member`. Year 2099 submits. 987 can't. Gateway receives parent id, origin id, trimmed name, year, owner id, picked person ids.

Copy tests: VALIDATION message `name is required` shown as that sentence. Menu-path NOT_FOUND shows `That story isn't available anymore. Pick another one.` Reader-path NOT_FOUND shows `That story isn't available anymore.` FORBIDDEN shows `You're not a member of {Parent} anymore.` Form never shows `story` or `member only`. Modal still open. Generic failure shows Mugatu's sentence once it exists, same inline spot, no raw DB text.

After create: toast `{Name} timeline created`, `listFamilyTree` reruns, `FamilySelection.id` unchanged, route stays on parent.

Origin tag reads `Origin · from {Parent}`, not `Origin · from {Parent} Family`.

Carried: dated Macro mark in empty decade paints one lone mark. Long dial label ellipsizes without new width constant. Right-edge full-card check own test. Ring-tap test matches edit above.

`flutter analyze` in `apps/tell_me_a_story`: ≤ 29. Don't clean up existing 29.

## Out of scope

Dial or mark entries. "Start a branch". Timeline with no origin. Pending state. Landing on new timeline. Future-year ban. Editing `branch_year` later. Co-owner assignment. Clear-origin RPC. Copying origin story. Parent-side revoke. Re-parenting or merging. M13. Indented Related-families tree. Any new table, column, enum, policy, route, package. Editing earlier migrations. `db reset`, `db pull`, `migration down`. Stamping CLOSED.