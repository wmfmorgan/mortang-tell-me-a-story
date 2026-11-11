# M14 People profiles — implementation plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.
>
> Planning only until plan approved. After approval, first commit copies file to `docs/superpowers/plans/2026-10-12-m14-people-profiles.md`. One PR. No merge. No READY or CLOSED stamp.

**Goal:** Ship Impl Spec §15 M14: person has one profile across family tree; tree members see/edit it until person signs in; sign-in links account, no "this is me" step.

**Architecture:** Two migrations after `20261011210000_fit_and_finish.sql`. First adds columns, `is_tree_member`, `person_profile`, people RLS, `person-avatars` bucket, invite linking; stops `create_branch_family` copying people. Second merges people rows M11b copied into child timelines. Edge changes only `create-invite`, `accept-invite`, `remove-member`. Flutter client adds eight locked screens on M13 date picker + blur shell.

**Tech Stack:** Flutter, Supabase Postgres RLS, pgTAP, Deno Edge tests. No new package. No new Edge function.

## Global constraints

- Branch `feat/m14-people-profiles` from `origin/main` `0f47be8524c1572c14c0a133abe9766ac8e16913` (`0f47be8`, PR #29). Worktree `.worktrees/feat-m14-people-profiles`. Main checkout still `59f91a9`. No fast-forward. No push main. No merge.
- Sources, in order: Impl Spec §15 M14 playbook, Design Doc "M14 — People profiles", UXD M14, PRD M14. Plan vs §15 conflict → §15 wins, except four calls in "Calls this plan locks".
- Stitch project `12192342757314667328`. Build only: Add person `b473d44aa3d245a190c0e63e4b3a8d5d`, Send invite confirm `b1fe8caf283040809781a10bba45c97c`, Add person passed `58464879b06c48148d22314e9b57ad3c`, member profile `ed49266f0c1e49a08588e65e583b36a9`, name-only profile `3e69375b469e4e9ab5878de281428bda`, Edit person `98ba67f7f2c04e1187dbbb40f46d26e2`, Settings `c285e4a01e444a80b784bbbec167af27`, invite-link picker `ef1bb744f41a478091a09d80c3538669`. Linking stays on existing invite sign-in page. No new route.
- Copy rule beats mock text. Labels: Name, Date of birth, Date of passing, Picture, About, Email. Buttons: "Add person" with plus-circle, "Send invite to {name}?", "Send invite", "Not now", "Edit", "Save". Invite link lists not-signed-in names + "Someone new". Ignore mock subtitles, helpers, footers, badges, breadcrumbs, tabs, Stories lists, account-email lines, Cancel, link chrome, Copy link, expiry, counts, sample names. Keep shipped invite link copy + expiry. Layout, colors, blur, plus-circle follow mocks.
- Dates reuse `StoryDatePicker` (`apps/tell_me_a_story/lib/features/stories/story_date_picker.dart`), incl. "Year is required. Add the month or day only if you remember. Day unlocks after Month." and "Shows as". Both dates may be blank. Year required only once date started. Never write `decade`.
- Profile modal uses `familyBlurShell` (sigma 4, scrim `0x662C2416`) from `family_blur_dialog.dart`. Don't change `showFamilyBlurDialog` signature.
- Migrations sort after `20261011210000`. Never edit earlier migration. Apply only with `supabase migration up --local`. Never `db reset`, `db pull`, `migration down`. If `migration up` fails because local DB has versions `20261010000001`, `20261010142736`, or `20261010143527`, stop and ask. No reset.
- Policy count 44 → exactly 47. `people_delete_member` unchanged. No fifth error prefix. Definer functions: `search_path = ''`, schema-qualified names, `(select auth.uid())`, null uid fails closed.
- Don't widen `profiles` select. No production `/invite/**` redirect. Cloud staging stays open. Trinity's M14 review deferred to H1.
- Don't kill Flutter processes on ports 3000/3001. Don't restart Supabase with `--no-backup`. Widget tests + pgTAP = implementation checks. Browser screenshots of eight screens wait until Bill says port 3000 server can move.
- Gates once new tests exist: `flutter analyze` ≤ 27 issues, `flutter test` ≥ 393 passing + 0 failing, pgTAP ≥ 433 passing, Deno ≥ 27 passing, policy count 47. Record `origin/main` baseline in PR. If `origin/main` analyze still 29, don't clean unrelated infos to force 27. Report playbook gate vs M13 baseline disagreement; leave count at baseline + zero new issues.

## Calls this plan locks

1. **Who may invite.** PRD: any family member can invite. M10: any member can still create invites. Playbook sentence "FORBIDDEN stays only for a caller who isn't an owner or co-owner" conflicts. Plan keeps today's gate: `is_family_member` false → 403 `FORBIDDEN` / `Not a family member`. Non-owner member can still invite. `person_id` failures use only `NOT_FOUND:` or `VALIDATION:`.
2. **Double link.** Caller already has another `people.user_id` in tree → accept still creates membership, skips link, no error. "Refused" = second `user_id` not written.
3. **Normalized name.** `lower(btrim(name))`, internal whitespace collapsed to one space (`regexp_replace` of `\s+`). Empty after → never matches. No other folding.
4. **What a date column stores.** Year → `YYYY-01-01`, precision `year`. Month → `YYYY-MM-01`, precision `month`. Day → that date, precision `day`. Null date + null precision together.
5. **Settings writes `profiles` only** (`display_name`, `birth_date`, `birth_precision`, `about`, existing avatar object). Not `people.name` or passing date. Passing stays on Edit person. Pills keep using `people.name`.
6. **Merge keeps a link.** Tags move to parent row. Survivor `user_id` null + copy's non-null → copy `user_id` onto survivor before deleting copy. Same for email. Never overwrite non-null survivor value.

## File map

- Create `supabase/migrations/20261012100000_people_profiles.sql`
- Create `supabase/migrations/20261012100100_people_merge_copies.sql`
- Create `supabase/tests/people_profiles.sql`
- Create `supabase/tests/people_merge.sql`
- Create `supabase/functions/create-invite/index_test.ts` if folder has none
- Modify `supabase/functions/create-invite/index.ts`, `accept-invite/index.ts`, `remove-member/index.ts`, plus their Deno tests
- Modify `supabase/tests/manage_families.sql`, `start_timeline.sql`, `origin_stories.sql`, `origin_stories_hardening.sql`, `fit_and_finish.sql`, `family_tree_read.sql` only where assertion becomes false
- Create `apps/tell_me_a_story/lib/features/people/person_profile_dialog.dart`
- Create `apps/tell_me_a_story/lib/features/people/edit_person_dialog.dart`
- Modify `people_api.dart`, `add_person_modal.dart`, `invite_api.dart`, `invite_modal.dart`, `settings_page.dart`, story/search/timeline name chips, tests constructing `Person`

---

### Task 1: Worktree and plan file

**Files:**
- Create: `docs/superpowers/plans/2026-10-12-m14-people-profiles.md` (this plan)

- [ ] From repo root, main checkout clean + untouched:

```bash
git fetch origin main
git worktree add .worktrees/feat-m14-people-profiles -b feat/m14-people-profiles origin/main
```

Expected tip: `0f47be8`.

- [ ] Copy plan into worktree at `docs/superpowers/plans/2026-10-12-m14-people-profiles.md`.
- [ ] Commit: `docs(m14): people profiles plan`

### Task 2: Columns, checks, and `is_tree_member`

**Files:**
- Create: `supabase/migrations/20261012100000_people_profiles.sql`
- Test: `supabase/tests/people_profiles.sql`

**Produces:** `public.is_tree_member(fid uuid) returns boolean`. Columns on `public.people`: `birth_date date`, `birth_precision public.story_date_precision`, `passing_date date`, `passing_precision public.story_date_precision`, `about text`, `avatar_path text`, `updated_at timestamptz not null default now()`. `relationship` nullable. Same three on `public.profiles` minus passing + avatar (`profiles.avatar_path` exists).

- [ ] **Step 1.** Write pgTAP failing pre-migration:
  - `is_tree_member` true for member of any live family sharing `family_tree_root`; false for outsider, soft-deleted family, null uid.
  - `pg_proc.proconfig` contains `search_path=""`. Anon no execute.
  - Insert `birth_precision = 'decade'` on `people` or `profiles` fails. Date without precision fails. `about` 501 chars fails. `avatar_path` other than `{id}/avatar.jpg` fails. `relationship` null succeeds.
- [ ] **Step 2.** Run `supabase test db supabase/tests/people_profiles.sql`; confirm new assertions fail.
- [ ] **Step 3.** Add columns + checks. Checks: each date/precision pair null together; precision null or distinct from `'decade'`; `about is null or char_length(about) <= 500`; `avatar_path is null or avatar_path = id::text || '/avatar.jpg'`. `alter column relationship drop not null`.
- [ ] **Step 4.** Add `is_tree_member`. Same live-tree rule as `is_family_tree_readable`, but don't replace that function.

```sql
create or replace function public.is_tree_member(fid uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(
    (select auth.uid()) is not null
    and exists (
      select 1
      from public.memberships m
      join public.families mine on mine.id = m.family_id
      join public.families target on target.id = fid
      where m.user_id = (select auth.uid())
        and mine.deleted_at is null
        and target.deleted_at is null
        and public.family_tree_root(m.family_id) = public.family_tree_root(fid)
    ),
    false
  );
$$;

revoke all on function public.is_tree_member(uuid) from public, anon;
grant execute on function public.is_tree_member(uuid) to authenticated;
```

- [ ] **Step 5.** `supabase migration up --local`, rerun new pgTAP file, confirm column + helper tests pass.
- [ ] Commit: `feat(m14): people profile columns and is_tree_member`

### Task 3: People RLS, name-only view, and `person_profile`

**Files:**
- Modify: `supabase/migrations/20261012100000_people_profiles.sql`
- Test: `supabase/tests/people_profiles.sql`

**Produces:** `public.person_profile(p_person_id uuid)` returns `id, family_id, name, birth_date, birth_precision, about, avatar_path, passing_date, passing_precision, is_linked`. Never `user_id` or email.

- [ ] **Step 1.** Extend pgTAP, watch fail:
  - Tree member selects full `people` row, updates unlinked person.
  - After `user_id` set, only that user updates row. Other tree member can't.
  - After `user_id` reset to null, tree members can update again.
  - Outside-tree reader selects `people_tree_read` columns `id, family_id, name` only. View has no `relationship`.
  - `update people set user_id = ...` as `authenticated` rejected.
  - Anon + public no execute on `person_profile`. Authenticated has. `search_path=""`.
  - Missing id, outsider, null uid raise `NOT_FOUND:`.
  - Linked: set `profiles` birth/about/avatar wins. Unset account field falls back to `people`. Passing always from `people`. `is_linked` matches `user_id is not null`. Result row no `user_id` or email column.
  - `profiles_select_own_or_comember` qual unchanged.
- [ ] **Step 2.** Replace view:

```sql
create or replace view public.people_tree_read
with (security_barrier = true) as
  select p.id, p.family_id, p.name
  from public.people p
  where public.is_live_family_member(p.family_id)
     or public.is_family_tree_readable(p.family_id);

revoke all on public.people_tree_read from public, anon;
grant select on public.people_tree_read to authenticated;
```

- [ ] **Step 3.** Drop + recreate only these policies:

```sql
drop policy if exists people_select_member on public.people;
create policy people_select_member
  on public.people for select to authenticated
  using (public.is_tree_member(family_id));

drop policy if exists people_insert_member on public.people;
create policy people_insert_member
  on public.people for insert to authenticated
  with check (public.is_live_family_member(family_id));

drop policy if exists people_update_member on public.people;
create policy people_update_member
  on public.people for update to authenticated
  using (
    (user_id is null and public.is_tree_member(family_id))
    or user_id = (select auth.uid())
  )
  with check (
    (user_id is null and public.is_tree_member(family_id))
    or user_id = (select auth.uid())
  );
```

Leave `people_delete_member` in place.

- [ ] **Step 4.** Revoke table update from `authenticated`, `anon`, `public`. Grant update on `name, relationship, email, birth_date, birth_precision, passing_date, passing_precision, about, avatar_path, updated_at` to `authenticated`. No grant on `user_id`, `id`, `family_id`, `created_by`.
- [ ] **Step 5.** Add `person_profile` as `language plpgsql stable security definer set search_path = ''`. Null uid, missing row, or `not public.is_tree_member(person.family_id)` raises `NOT_FOUND:` with exact text. Coalesce birth date, birth precision, about, avatar each independently from `profiles` when `user_id` not null and account field not null. Passing columns + `name` always from `people`. `is_linked` = `user_id is not null`. Revoke from `public` + `anon`. Grant execute to `authenticated` only.
- [ ] **Step 6.** Update existing view assertions requiring `relationship` on `people_tree_read` (`origin_stories_hardening.sql` column list, `family_tree_read.sql` "reads the child relationship"). Must expect column gone. Don't weaken any cross-family leak test.
- [ ] **Step 7.** `supabase migration up --local` by re-running changed statements if version already applied. Confirm new pgTAP file passes.
- [ ] Commit: `feat(m14): person profile read and people RLS`

### Task 4: `person-avatars` and the policy-count pin

**Files:**
- Modify: M14 migration + `supabase/tests/people_profiles.sql`
- Modify four `policy count` expectations still at 44: `fit_and_finish.sql`, `origin_stories.sql`, `origin_stories_hardening.sql`, `start_timeline.sql`

- [ ] **Step 1.** pgTAP: outsider can't select/insert/update `storage.objects` in `person-avatars`. Tree member can select `{person_id}/avatar.jpg`. Tree member can insert/update that object only while `user_id` null. Linked user can insert/update own object. Others in tree can't. Policy count 47. Pin exact `qual` / `with_check` for `people_select_member`, `people_insert_member`, `people_update_member`, three new storage policies.
- [ ] **Step 2.** Watch fail, then add private bucket `person-avatars` + three policies `person_avatars_select_tree`, `person_avatars_insert_editor`, `person_avatars_update_editor`. Path must be `(storage.foldername(name))[1] = people.id::text` and `name = people.id::text || '/avatar.jpg'`. Select requires `is_tree_member(people.family_id)`. Insert + update use same boolean as `people_update_member`. No delete policy.
- [ ] **Step 3.** Change four old count assertions 44 → 47. Don't edit migrations those tests target.
- [ ] **Step 4.** `supabase test db` passes new file + four updated count tests.
- [ ] Commit: `feat(m14): person-avatars bucket`

### Task 5: Drop auto-membership and add invite person helpers

**Files:**
- Modify: M14 migration, `supabase/tests/manage_families.sql`, `supabase/tests/people_profiles.sql`

**Produces:**
- `public.list_unlinked_people(p_family_id uuid)` returns `id, family_id, name` for tree people with `user_id is null` and `passing_date is null`. Missing family or non-tree caller raises `NOT_FOUND:`.
- `public.assert_invite_person(p_family_id uuid, p_person_id uuid) returns void`. Missing + out-of-tree person both raise `NOT_FOUND:`, no other text. `user_id is not null` raises `VALIDATION: person is already linked`. `passing_date is not null` raises `VALIDATION: person has passed`.
- `public.link_accepted_person(p_person_id uuid) returns void`.

- [ ] **Step 1.** Replace tests so they fail on old behavior, pass on new:
  - `manage_families.sql`: "tagging a matching email upserts member" + block "Tagging a resolved person upserts member…". New assertion: tagging + saving email create no membership. Both triggers absent.
  - `start_timeline.sql`: "an email match becomes a member" → "an email match does not become a member".
  - New pgTAP: `list_unlinked_people` covers whole tree, omits linked people, omits anyone with `passing_date`.
  - New pgTAP: `link_accepted_person` sets `user_id` when null. Person already linked to someone else stays so, no raise. Caller already on another person in tree gets no second row, no exception. Null uid raises `NOT_FOUND:`.
- [ ] **Step 2.** Confirm tests fail.
- [ ] **Step 3.** Drop triggers `story_people_ensure_membership` + `people_ensure_membership`. Leave `ensure_story_person_membership()` in DB if something else calls it, but nothing fires it. Don't drop `upsert_story_member`.
- [ ] **Step 4.** `alter table public.invites add column person_id uuid null references public.people (id) on delete set null`.
- [ ] **Step 5.** Add three functions: all definer, `search_path = ''`, execute for `authenticated` only. `link_accepted_person` uses `(select auth.uid())`. Updates `people.user_id` only when column null, caller not already on another person in `family_tree_root(people.family_id)`, caller not null. No membership insert.
- [ ] **Step 6.** Tests pass. Commit: `feat(m14): drop auto-membership and link helpers`

### Task 6: Stop copying people in `create_branch_family`

**Files:**
- Modify: M14 migration + `supabase/tests/start_timeline.sql`

- [ ] **Step 1.** Find assertion `people row count equals distinct picks` in `start_timeline.sql`. Change so new timeline adds zero `people` rows. Membership seeding for picked person with `user_id` still happens. Picked person with no resolvable user still adds no membership.
- [ ] **Step 2.** Watch fail.
- [ ] **Step 3.** New migration: `create or replace function public.create_branch_family` with current arg list, current seven checks, origin flag, owner insert. Schema-qualify every name, set `search_path = ''`. Delete `insert into public.people` in pick loop. Keep `upsert_story_member(fam.id, resolve_person_user(...))` so M11b membership seeding stays. Picked id not in parent family → raise `VALIDATION: members must come from the parent family`, write nothing else in that call.
- [ ] **Step 4.** Replaced function grants stay `authenticated` + `service_role`. Revoke from `public` + `anon`.
- [ ] **Step 5.** `start_timeline.sql` passes. Commit: `feat(m14): new timelines do not copy people`

### Task 7: Merge copied people

**Files:**
- Create: `supabase/migrations/20261012100100_people_merge_copies.sql`
- Test: `supabase/tests/people_merge.sql`

Merge = one statement block in migration, runs once. pgTAP file builds own parent + child copies in transaction, re-runs same match function. Put match in `public.merge_copied_people()` defined in second migration: security definer, `search_path = ''`, execute revoked from `public`, `anon`, `authenticated`. Migration calls it once. pgTAP calls it as table owner in test transaction, rolls fixture back. No client grant.

- [ ] **Step 1.** pgTAP fixtures, all rolled back:
  - Equal `user_id` merges. Story tags point at parent row. Child row gone.
  - Email matches only as `lower(trim())`.
  - Null + blank email never match. Null `user_id` never matches.
  - Name-only match uses normalized-name rule; no merge when rows have different non-empty emails or different non-null `user_id`s.
  - Two parent candidates → copy left in place.
  - Grandchild copy merges to child, then that child copy merges to root, in one call.
  - After function, fixture has one person per matched identity. Seed data needn't contain duplicates. Assert idempotent on second call.
- [ ] **Step 2.** Watch fail.
- [ ] **Step 3.** Implement `merge_copied_people`. Walk branch families deepest first. Candidates = people on immediate parent only. Match if any: both `user_id`s equal + non-null; both emails non-empty + equal under `lower(trim())`; normalized names equal and no conflicting email or `user_id`. >1 candidate → skip copy. One candidate: move `story_people` via `insert ... on conflict do nothing`, delete copy's tags, fill null survivor `user_id` + email from copy, delete copy. `story_people.person_id` is `on delete cascade`, so repoint before delete.
- [ ] **Step 4.** Tests pass. Commit: `feat(m14): merge copied people`

### Task 8: Edge invite linking

**Files:**
- Modify: `supabase/functions/create-invite/index.ts`
- Modify: `supabase/functions/accept-invite/index.ts`
- Modify: `supabase/functions/remove-member/index.ts` only if RPC name stays `remove_member`
- Modify: M14 migration's `remove_member`
- Test: Deno tests under those three function folders

- [ ] **Step 1.** Deno tests, watch fail:
  - Absent `person_id` still returns 201.
  - Unknown person + person outside caller's tree both return 404 `NOT_FOUND`, same message body.
  - Linked person → 400 `VALIDATION`, message `person is already linked`.
  - Person with `passing_date` → 400 `VALIDATION`, message `person has passed`.
  - Caller failing `is_family_member` → 403 `FORBIDDEN`, message `Not a family member`. Ordinary member allowed.
  - `accept-invite` with unlinked `person_id` sets `user_id` to caller. Already linked to someone else → still 200, `user_id` unchanged. Null `person_id` sets no `user_id`. Caller already linked in tree → still 200, no second link.
  - `remove-member` sets `user_id` null on that user's people rows in tree, leaves `story_people` rows.
  - Existing Deno tests still pass. `mapRpcError` still exactly four prefixes.
- [ ] **Step 2.** `create-invite` reads optional `person_id`. When present, user-scoped client calls `assert_invite_person` before service insert. Service insert writes `person_id`. Member check unchanged.
- [ ] **Step 3.** `accept-invite` selects `person_id`. After membership upsert, before marking invite accepted, user-scoped client calls `link_accepted_person` when `person_id` not null. `NOT_FOUND:` from null uid → 401. No email-match linking. Keep M13 behavior: existing membership role not demoted.
- [ ] **Step 4.** Replace `remove_member` in M14 migration. Copy current checks + membership delete. Schema-qualify, set `search_path = ''`. After delete:

```sql
update public.people
set user_id = null
where user_id = target
  and family_id = any (tree_ids);
```

Don't delete `story_people`. Keep current exception strings.

- [ ] **Step 5.** `deno test` for three functions passes. Commit: `feat(m14): invite links a person`

### Task 9: Client data and Add person

**Files:**
- Modify: `apps/tell_me_a_story/lib/data/people_api.dart`
- Modify: `apps/tell_me_a_story/lib/features/people/add_person_modal.dart`
- Modify: `apps/tell_me_a_story/test/people_api_test.dart`
- Modify: `apps/tell_me_a_story/test/add_person_modal_test.dart`
- Test: `apps/tell_me_a_story/test/m14_people_profiles_test.dart`

**Produces:** `Person.relationship` is `String?`. `PeopleApi.createPerson` takes name, optional birth, passing, about, email, JPEG bytes. No relationship. `AddPersonModal.show` returns created person + whether caller chose "Send invite".

- [ ] **Step 1.** Widget tests:
  - Labels exactly Name, Date of birth, Date of passing, Picture, About, Email. No Relationship control. Button text "Add person", shows plus-circle.
  - Year-only birth + About of 500 chars save. 501 doesn't call API.
  - Passing date set hides Email. Saving that person sends no email, no invite.
  - Saving with email opens blur dialog titled `Send invite to Ada?` with "Send invite" + "Not now". "Not now" saves email, no create-invite call. "Send invite" saves, calls create-invite with that `person_id` + email, then existing send-invite-email.
  - Both date pickers show M13 helper + "Shows as".
- [ ] **Step 2.** Run new tests, confirm fail.
- [ ] **Step 3.** Implement. Store dates per "Calls this plan locks". Insert person, upload JPEG bytes to `person-avatars` at `{id}/avatar.jpg` via existing story-photo compressor, then update `avatar_path`. Passing set → drop email before insert. Reuse `familyBlurShell` for confirm. No Cancel button on Add person.
- [ ] **Step 4.** Fix every current `Person(...)` + `createPerson(relationship:)` call so suite compiles. Reader may still show non-empty stored relationship. New people send null.
- [ ] **Step 5.** New tests pass. Commit: `feat(m14): add person profile fields`

### Task 10: Profile modal from name pills

**Files:**
- Create: `apps/tell_me_a_story/lib/features/people/person_profile_dialog.dart`
- Modify: reader person row, new-story person chip, search person result, search story person chip, timeline full-card person chip
- Modify: `stories_api.dart` so story carries `({String id, String name})` people, not names only
- Test: `m14_people_profiles_test.dart`

- [ ] **Step 1.** Tests:
  - Pill tap opens blur modal.
  - `person_profile` data shows Name, birth "Shows as" line, passing, About, picture. No relationship, Stories list, or email.
  - `is_linked` false shows Edit. `is_linked` true hides Edit for different account.
  - Failed `person_profile` (`NOT_FOUND:`) shows name only: no Edit, dates, About, picture.
  - Picture order = path `person_profile` already coalesced. Null path paints empty circle, not email initials.
  - Add-person chooser rows, start-timeline member chips, invite picker don't open modal.
- [ ] **Step 2.** Watch fail.
- [ ] **Step 3.** Thread person ids into full-card chip, search story chip, reader row. Place chip tap does nothing new. Modal calls `person_profile`. Signed URLs: `person-avatars` when path is `{person_id}/avatar.jpg`, else existing `avatars` bucket for account path `{uid}/avatar.jpg`.
- [ ] **Step 4.** Tests pass. Commit: `feat(m14): open a person profile from a name pill`

### Task 11: Edit person

**Files:**
- Create: `apps/tell_me_a_story/lib/features/people/edit_person_dialog.dart`
- Test: `m14_people_profiles_test.dart`

- [ ] **Step 1.** Tests:
  - Edit shown for unlinked person; writes name, dates, about, picture via `people` update + `person-avatars`.
  - Email prefilled from `people` row, changeable while unlinked. Change to non-empty value shows same send confirm. "Not now" saves email, creates no invite.
  - Passing set hides Email.
  - `user_id` equals signed-in user → email visible + read-only. Date of birth, About, Picture not on form. Save writes passing + name to `people` only.
  - `user_id` is other id → Edit absent.
- [ ] **Step 2.** Watch fail, implement. Edit gate reads `people.user_id` from tree-member select, not from `person_profile`.
- [ ] **Step 3.** Tests pass. Commit: `feat(m14): edit an unlinked person`

### Task 12: Settings, one Save

**Files:**
- Modify: `apps/tell_me_a_story/lib/features/settings/settings_page.dart`
- Modify: `apps/tell_me_a_story/test/settings_page_test.dart`
- Profile API already updating `profiles.display_name` + `avatar_path`

- [ ] **Step 1.** Tests: Settings shows Name, Date of birth, Picture, About, existing email control. One Save writes `profiles.display_name`, `birth_date`, `birth_precision`, `about`; still uploads account picture to `avatars` bucket. Doesn't write `people`. Date of passing absent. Header menu still opens page.
- [ ] **Step 2.** Watch fail, implement. Keep M8 rule: blank name not saved. Keep existing email-change call. Client never writes `profiles.email`.
- [ ] **Step 3.** Tests pass. Commit: `feat(m14): settings save writes the account profile`

### Task 13: Invite-link person picker

**Files:**
- Modify: `apps/tell_me_a_story/lib/data/invite_api.dart`
- Modify: `apps/tell_me_a_story/lib/features/invites/invite_modal.dart`
- Modify: `apps/tell_me_a_story/test/invite_chrome_test.dart`

- [ ] **Step 1.** Tests: Link tab lists `list_unlinked_people` names + "Someone new". People with passing date absent (RPC omits). Choosing person calls create-invite with `person_id`, no email. "Someone new" calls create-invite without `person_id`. Existing copy control + 7-day line stay. Switching pick creates another invite, doesn't revoke previous. Email tab doesn't show picker.
- [ ] **Step 2.** Watch fail. Add optional `personId` to `InviteGateway.createInvite`.
- [ ] **Step 3.** Stop creating link when Link tab opens. Create on row choice. SMS tab stays non-sending placeholder.
- [ ] **Step 4.** Tests pass. Commit: `feat(m14): invite link picks a person`

### Task 14: Gates

- [ ] From `apps/tell_me_a_story`: `flutter analyze` + `flutter test`.
- [ ] From worktree: `supabase test db` + `deno test supabase/functions`.
- [ ] Paste four outputs in PR body. Include test counts, policy count, four locked calls, note that browser screenshots of eight screens wait on port 3000 server.
- [ ] PR title: `feat(m14): people profiles`. One PR. No merge.

## Spec coverage

| Playbook item | Task |
| --- | --- |
| 1 `is_tree_member` | 2 |
| 2 people columns, nullable relationship | 2 |
| 3 `person-avatars` | 4 |
| 4 account profile columns | 2 and 12 |
| 5 `person_profile` | 3 and 10 |
| 6 people RLS and name-only view | 3 |
| 7 `user_id` not client-writable, unique per tree in the write path | 3 and 5 |
| 8 drop the two triggers | 5 |
| 9 `invites.person_id` | 5 |
| 10 create-invite `person_id` and the email confirm | 8 and 9 |
| 11 accept-invite link, no email match | 8 |
| 12 remove-member unlinks | 8 |
| 13 picker RPC | 5 and 13 |
| 14 stop copying people | 6 |
| 15 merge copies | 7 |
| 16 the eight screens | 9–13 |
| Policy count 47 | 4 |
| Replace M10 and M11b membership tests | 5 and 6 |

## Out

Relationships as feature, deceased mark, family tree view, family friends, SMS send, email-match auto-link, "this is me" step, new error prefix, wider `profiles` select, M13 date-rule changes, H1, staging. Don't reopen M10, M11a, M11a.2, M11b, M12, M13.

## Done

Bill smokes locally with nine playbook steps. Lanes after PR: Gilfoyle, Big Head, Mugatu, Dinesh, Jared. Trinity waits for H1. Bill merges.