# M14 People profiles — implementation plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.
>
> Planning only until this plan is approved. After approval, the first commit copies this file to `docs/superpowers/plans/2026-10-12-m14-people-profiles.md`. One PR. Do not merge. Do not stamp READY or CLOSED.

**Goal:** Ship Impl Spec §15 M14 so a person has one profile across a family tree, tree members can see and edit it until that person signs in, and sign-in links the account without a "this is me" step.

**Architecture:** Two migrations after `20261011210000_fit_and_finish.sql`. The first adds columns, `is_tree_member`, `person_profile`, people RLS, the `person-avatars` bucket, invite linking, and stops `create_branch_family` from copying people. The second merges people rows that M11b copied into child timelines. Edge changes are only `create-invite`, `accept-invite`, and `remove-member`. The Flutter client adds the eight locked screens on top of the M13 date picker and blur shell.

**Tech Stack:** Flutter, Supabase Postgres RLS, pgTAP, Deno Edge tests. No new package. No new Edge function.

## Global constraints

- Branch `feat/m14-people-profiles` from `origin/main` `0f47be8524c1572c14c0a133abe9766ac8e16913` (`0f47be8`, PR #29). Worktree `.worktrees/feat-m14-people-profiles`. The main checkout is still `59f91a9`. Do not fast-forward it. Do not push main. Do not merge.
- Sources, in order: Impl Spec §15 M14 playbook, then Design Doc "M14 — People profiles", then UXD M14, then PRD M14. Where this plan and §15 differ, §15 wins, except the four calls in "Calls this plan locks" below.
- Stitch project `12192342757314667328`. Build only these screens: Add person `b473d44aa3d245a190c0e63e4b3a8d5d`, Send invite confirm `b1fe8caf283040809781a10bba45c97c`, Add person passed `58464879b06c48148d22314e9b57ad3c`, member profile `ed49266f0c1e49a08588e65e583b36a9`, name-only profile `3e69375b469e4e9ab5878de281428bda`, Edit person `98ba67f7f2c04e1187dbbb40f46d26e2`, Settings `c285e4a01e444a80b784bbbec167af27`, invite-link picker `ef1bb744f41a478091a09d80c3538669`. Linking stays on the existing invite sign-in page. No new route.
- Copy rule wins over mock text. Labels: Name, Date of birth, Date of passing, Picture, About, Email. Buttons: "Add person" with the plus-circle, "Send invite to {name}?", "Send invite", "Not now", "Edit", "Save". Invite link lists not-signed-in names plus "Someone new". Ignore mock subtitles, helpers, footers, badges, breadcrumbs, tabs, Stories lists, account-email lines, Cancel, link chrome, Copy link, expiry, counts, and sample names. Keep the shipped invite link copy and expiry. Layout, colors, blur, and the plus-circle follow the mocks.
- Dates reuse `StoryDatePicker` (`apps/tell_me_a_story/lib/features/stories/story_date_picker.dart`), including "Year is required. Add the month or day only if you remember. Day unlocks after Month." and "Shows as". Both dates may be blank. Year is required only after a date is started. Never write `decade`.
- Profile modal uses `familyBlurShell` (sigma 4, scrim `0x662C2416`) from `family_blur_dialog.dart`. Do not change `showFamilyBlurDialog`'s signature.
- Migrations sort after `20261011210000`. Never edit an earlier migration. Apply with `supabase migration up --local` only. Never `db reset`, `db pull`, or `migration down`. If `migration up` fails because the local database has versions `20261010000001`, `20261010142736`, or `20261010143527`, stop and ask. Do not reset.
- Policy count goes from 44 to exactly 47. `people_delete_member` stays as it is. No fifth error prefix. Definer functions: `search_path = ''`, schema-qualified names, `(select auth.uid())`, null uid fails closed.
- Do not widen `profiles` select. Do not add a production `/invite/**` redirect. Cloud staging stays open. Trinity's M14 review stays deferred to H1.
- Do not kill the Flutter processes on ports 3000 or 3001. Do not restart Supabase with `--no-backup`. Widget tests and pgTAP are the implementation checks. Browser screenshots for the eight screens wait until Bill says the port 3000 server can move.
- Gates after the new tests exist: `flutter analyze` ≤ 27 issues, `flutter test` ≥ 393 passing and 0 failing, pgTAP ≥ 433 passing, Deno ≥ 27 passing, policy count 47. Record the `origin/main` baseline in the PR. If `origin/main` analyze is still 29, do not clean unrelated infos to force 27. Report that the playbook gate and the M13 baseline disagree, and leave the count at the baseline plus zero new issues.

## Calls this plan locks

1. **Who may invite.** PRD says any family member can invite. M10 says any member can still create invites. The playbook sentence "FORBIDDEN stays only for a caller who isn't an owner or co-owner" conflicts with that. This plan keeps today's gate: `is_family_member` false returns 403 `FORBIDDEN` / `Not a family member`. A member who is not an owner can still invite. `person_id` failures use `NOT_FOUND:` or `VALIDATION:` only.
2. **Double link.** If the caller already has another `people.user_id` in that tree, accept still creates the membership, skips the link, and returns no error. "Refused" means the second `user_id` is not written.
3. **Normalized name.** `lower(btrim(name))` with internal whitespace collapsed to one space (`regexp_replace` of `\s+`). Empty after that never matches. No other folding.
4. **What a date column stores.** Year → `YYYY-01-01` and precision `year`. Month → `YYYY-MM-01` and precision `month`. Day → that date and precision `day`. Null date and null precision together.
5. **Settings writes `profiles` only** (`display_name`, `birth_date`, `birth_precision`, `about`, and the existing avatar object). It does not write `people.name` or a date of passing. Passing stays on Edit person. Pills keep using `people.name`.
6. **Merge keeps a link.** Tags move to the parent row. If the survivor's `user_id` is null and the copy's is not, copy that `user_id` onto the survivor before the copy is deleted. Same for email. Do not overwrite a non-null survivor value.

## File map

- Create `supabase/migrations/20261012100000_people_profiles.sql`
- Create `supabase/migrations/20261012100100_people_merge_copies.sql`
- Create `supabase/tests/people_profiles.sql`
- Create `supabase/tests/people_merge.sql`
- Create `supabase/functions/create-invite/index_test.ts` if the folder has none
- Modify `supabase/functions/create-invite/index.ts`, `accept-invite/index.ts`, `remove-member/index.ts`, and their Deno tests
- Modify `supabase/tests/manage_families.sql`, `start_timeline.sql`, `origin_stories.sql`, `origin_stories_hardening.sql`, `fit_and_finish.sql`, `family_tree_read.sql` only where an assertion becomes false
- Create `apps/tell_me_a_story/lib/features/people/person_profile_dialog.dart`
- Create `apps/tell_me_a_story/lib/features/people/edit_person_dialog.dart`
- Modify `people_api.dart`, `add_person_modal.dart`, `invite_api.dart`, `invite_modal.dart`, `settings_page.dart`, story/search/timeline name chips, and the tests that construct a `Person`

---

### Task 1: Worktree and plan file

**Files:**
- Create: `docs/superpowers/plans/2026-10-12-m14-people-profiles.md` (this plan)

- [ ] From the repo root, with a clean main checkout left untouched:

```bash
git fetch origin main
git worktree add .worktrees/feat-m14-people-profiles -b feat/m14-people-profiles origin/main
```

Expected tip: `0f47be8`.

- [ ] Copy this plan into the worktree at `docs/superpowers/plans/2026-10-12-m14-people-profiles.md`.
- [ ] Commit: `docs(m14): people profiles plan`

### Task 2: Columns, checks, and `is_tree_member`

**Files:**
- Create: `supabase/migrations/20261012100000_people_profiles.sql`
- Test: `supabase/tests/people_profiles.sql`

**Produces:** `public.is_tree_member(fid uuid) returns boolean`. Columns on `public.people`: `birth_date date`, `birth_precision public.story_date_precision`, `passing_date date`, `passing_precision public.story_date_precision`, `about text`, `avatar_path text`, `updated_at timestamptz not null default now()`. `relationship` nullable. Same three columns on `public.profiles` except passing and avatar (`profiles.avatar_path` already exists).

- [ ] **Step 1.** Write pgTAP that fails before the migration:
  - `is_tree_member` is true for a member of any live family that shares `family_tree_root`, false for an outsider, a soft-deleted family, and a null uid.
  - `pg_proc.proconfig` contains `search_path=""`. Anon has no execute.
  - Inserting `birth_precision = 'decade'` on `people` or `profiles` fails. A date without its precision fails. `about` of 501 characters fails. `avatar_path` other than `{id}/avatar.jpg` fails. `relationship` null succeeds.
- [ ] **Step 2.** Run `supabase test db supabase/tests/people_profiles.sql` and confirm the new assertions fail.
- [ ] **Step 3.** Add the columns and checks. Checks: each date/precision pair is null together; precision is null or distinct from `'decade'`; `about is null or char_length(about) <= 500`; `avatar_path is null or avatar_path = id::text || '/avatar.jpg'`. `alter column relationship drop not null`.
- [ ] **Step 4.** Add `is_tree_member`. Same live-tree rule as `is_family_tree_readable`, but do not replace that function.

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

- [ ] **Step 5.** `supabase migration up --local`, rerun the new pgTAP file, confirm the column and helper tests pass.
- [ ] Commit: `feat(m14): people profile columns and is_tree_member`

### Task 3: People RLS, name-only view, and `person_profile`

**Files:**
- Modify: `supabase/migrations/20261012100000_people_profiles.sql`
- Test: `supabase/tests/people_profiles.sql`

**Produces:** `public.person_profile(p_person_id uuid)` returns `id, family_id, name, birth_date, birth_precision, about, avatar_path, passing_date, passing_precision, is_linked`. Never `user_id` or email.

- [ ] **Step 1.** Extend pgTAP, then watch it fail:
  - A tree member selects the full `people` row and updates an unlinked person.
  - After `user_id` is set, only that user updates the row. A tree member who is not that user cannot.
  - After `user_id` is set back to null, tree members can update again.
  - An outside-tree reader selects `people_tree_read` columns `id, family_id, name` only. The view has no `relationship`.
  - `update people set user_id = ...` as `authenticated` is rejected.
  - Anon and public have no execute on `person_profile`. Authenticated does. `search_path=""`.
  - A missing id, an outsider, and a null uid raise `NOT_FOUND:`.
  - When linked, a set `profiles` birth, about, or avatar wins. An unset account field falls back to `people`. Passing always comes from `people`. `is_linked` matches `user_id is not null`. The result row has no `user_id` or email column.
  - `profiles_select_own_or_comember` qual is unchanged.
- [ ] **Step 2.** Replace the view:

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

- [ ] **Step 3.** Drop and recreate only these policies:

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

- [ ] **Step 4.** Revoke table update from `authenticated`, `anon`, and `public`. Grant update on `name, relationship, email, birth_date, birth_precision, passing_date, passing_precision, about, avatar_path, updated_at` to `authenticated`. Do not grant `user_id`, `id`, `family_id`, or `created_by`.
- [ ] **Step 5.** Add `person_profile` as `language plpgsql stable security definer set search_path = ''`. Null uid or a missing row or `not public.is_tree_member(person.family_id)` raises `NOT_FOUND:` with that exact text. Coalesce each of birth date, birth precision, about, and avatar independently from `profiles` when `user_id` is not null and that account field is not null. Passing columns and `name` always come from `people`. `is_linked` is `user_id is not null`. Revoke from `public` and `anon`. Grant execute to `authenticated` only.
- [ ] **Step 6.** Update the existing view assertions that require `relationship` on `people_tree_read` (`origin_stories_hardening.sql` column list, `family_tree_read.sql` "reads the child relationship"). Those tests must expect the column to be gone. Do not weaken a cross-family leak test.
- [ ] **Step 7.** `supabase migration up --local` by re-running the changed statements if the migration version is already applied. Confirm the new pgTAP file passes.
- [ ] Commit: `feat(m14): person profile read and people RLS`

### Task 4: `person-avatars` and the policy-count pin

**Files:**
- Modify: the M14 migration and `supabase/tests/people_profiles.sql`
- Modify the four `policy count` expectations that still say 44: `fit_and_finish.sql`, `origin_stories.sql`, `origin_stories_hardening.sql`, `start_timeline.sql`

- [ ] **Step 1.** pgTAP: an outsider cannot select, insert, or update `storage.objects` in `person-avatars`. A tree member can select `{person_id}/avatar.jpg`. A tree member can insert and update that object only while `user_id` is null. The linked user can insert and update their own object. Someone else in the tree cannot. Policy count is 47. Pin exact `qual` / `with_check` for `people_select_member`, `people_insert_member`, `people_update_member`, and the three new storage policies.
- [ ] **Step 2.** Watch that fail, then add private bucket `person-avatars` and three policies named `person_avatars_select_tree`, `person_avatars_insert_editor`, and `person_avatars_update_editor`. Path must be `(storage.foldername(name))[1] = people.id::text` and `name = people.id::text || '/avatar.jpg'`. Select requires `is_tree_member(people.family_id)`. Insert and update use the same boolean as `people_update_member`. No delete policy.
- [ ] **Step 3.** Change the four old count assertions from 44 to 47. Do not edit the migrations those tests were written against.
- [ ] **Step 4.** `supabase test db` passes the new file and the four updated count tests.
- [ ] Commit: `feat(m14): person-avatars bucket`

### Task 5: Drop auto-membership and add invite person helpers

**Files:**
- Modify: the M14 migration, `supabase/tests/manage_families.sql`, `supabase/tests/people_profiles.sql`

**Produces:**
- `public.list_unlinked_people(p_family_id uuid)` returns `id, family_id, name` for tree people with `user_id is null` and `passing_date is null`. Missing family or a non-tree caller raises `NOT_FOUND:`.
- `public.assert_invite_person(p_family_id uuid, p_person_id uuid) returns void`. Missing person and out-of-tree person both raise `NOT_FOUND:` and no other text. `user_id is not null` raises `VALIDATION: person is already linked`. `passing_date is not null` raises `VALIDATION: person has passed`.
- `public.link_accepted_person(p_person_id uuid) returns void`.

- [ ] **Step 1.** Replace these tests so they fail on old behavior and pass on the new rule:
  - `manage_families.sql`: "tagging a matching email upserts member" and the block "Tagging a resolved person upserts member…". New assertion: tagging and saving an email create no membership. Both triggers are absent.
  - `start_timeline.sql`: "an email match becomes a member" becomes "an email match does not become a member".
  - New pgTAP: `list_unlinked_people` covers the whole tree, omits linked people, omits anyone with `passing_date`.
  - New pgTAP: `link_accepted_person` sets `user_id` when it was null. A person already linked to someone else stays that way and does not raise. A caller who already has another person in the tree does not get a second row, and no exception is raised. A null uid raises `NOT_FOUND:`.
- [ ] **Step 2.** Confirm those tests fail.
- [ ] **Step 3.** Drop triggers `story_people_ensure_membership` and `people_ensure_membership`. Leave `ensure_story_person_membership()` in the database if something else still calls it, but nothing fires it. Do not drop `upsert_story_member`.
- [ ] **Step 4.** `alter table public.invites add column person_id uuid null references public.people (id) on delete set null`.
- [ ] **Step 5.** Add the three functions, all definer, `search_path = ''`, execute for `authenticated` only. `link_accepted_person` uses `(select auth.uid())`. It updates `people.user_id` only when that column is null, the caller is not already on another person in `family_tree_root(people.family_id)`, and the caller is not null. It does not insert a membership.
- [ ] **Step 6.** Tests pass. Commit: `feat(m14): drop auto-membership and link helpers`

### Task 6: Stop copying people in `create_branch_family`

**Files:**
- Modify: the M14 migration and `supabase/tests/start_timeline.sql`

- [ ] **Step 1.** Find the assertion `people row count equals distinct picks` in `start_timeline.sql`. Change it so a new timeline adds zero `people` rows. Membership seeding for a picked person who already has `user_id` still happens. A picked person with no resolvable user still adds no membership.
- [ ] **Step 2.** Watch it fail.
- [ ] **Step 3.** In the new migration, `create or replace function public.create_branch_family` with the current argument list and the current seven checks, origin flag, and owner insert. Schema-qualify every name and set `search_path = ''`. Delete the `insert into public.people` inside the pick loop. Keep `upsert_story_member(fam.id, resolve_person_user(...))` so M11b membership seeding stays. If the picked id is not in the parent family, raise `VALIDATION: members must come from the parent family` and write nothing else in that call.
- [ ] **Step 4.** The replaced function's grants stay `authenticated` and `service_role`. Revoke from `public` and `anon`.
- [ ] **Step 5.** `start_timeline.sql` passes. Commit: `feat(m14): new timelines do not copy people`

### Task 7: Merge copied people

**Files:**
- Create: `supabase/migrations/20261012100100_people_merge_copies.sql`
- Test: `supabase/tests/people_merge.sql`

The merge is one statement block in the migration, so it runs once. The pgTAP file builds its own parent and child copies inside a transaction and re-runs the same match function. Put the match in `public.merge_copied_people()` defined in this second migration, security definer, `search_path = ''`, execute revoked from `public`, `anon`, and `authenticated`. The migration calls it once. pgTAP calls it as the table owner inside the test transaction and rolls the fixture back. Do not grant it to clients.

- [ ] **Step 1.** pgTAP fixtures, all rolled back:
  - Equal `user_id` merges. Story tags point at the parent row. The child row is gone.
  - Email matches only as `lower(trim())`.
  - Null and blank email never match. Null `user_id` never matches.
  - Name-only match uses the normalized-name rule and does not merge when both rows have different non-empty emails or different non-null `user_id`s.
  - Two parent candidates leave the copy in place.
  - A grandchild copy merges to the child, then that child copy merges to the root, in one function call.
  - After the function, the fixture has one person per matched identity. Seed data is not required to contain duplicates. Assert the function is idempotent on a second call.
- [ ] **Step 2.** Watch it fail.
- [ ] **Step 3.** Implement `merge_copied_people`. Walk branch families deepest first. Candidates are people on the immediate parent only. A candidate matches when any of these is true: both `user_id`s equal and non-null; both emails non-empty and equal under `lower(trim())`; normalized names equal and the rows do not have conflicting email or `user_id`. More than one candidate skips that copy. One candidate: move `story_people` with `insert ... on conflict do nothing` then delete the copy's tags, fill null survivor `user_id` and email from the copy, then delete the copy. `story_people.person_id` is `on delete cascade`, so the repoint happens before the delete.
- [ ] **Step 4.** Tests pass. Commit: `feat(m14): merge copied people`

### Task 8: Edge invite linking

**Files:**
- Modify: `supabase/functions/create-invite/index.ts`
- Modify: `supabase/functions/accept-invite/index.ts`
- Modify: `supabase/functions/remove-member/index.ts` only if the RPC name stays `remove_member`
- Modify: the M14 migration's `remove_member`
- Test: Deno tests under those three function folders

- [ ] **Step 1.** Deno tests, then watch them fail:
  - Absent `person_id` still returns 201.
  - Unknown person and a person outside the caller's tree both return 404 `NOT_FOUND` with the same message body.
  - Linked person returns 400 `VALIDATION` and message `person is already linked`.
  - A person with `passing_date` returns 400 `VALIDATION` and message `person has passed`.
  - A caller who fails `is_family_member` returns 403 `FORBIDDEN` and message `Not a family member`. An ordinary member is allowed.
  - `accept-invite` with an unlinked `person_id` sets `user_id` to the caller. Already linked to someone else still returns 200 and does not change `user_id`. Null `person_id` does not set any `user_id`. A caller already linked in the tree still returns 200 and does not write a second link.
  - `remove-member` sets `user_id` null on that user's people rows in the tree and leaves `story_people` rows.
  - Existing Deno tests still pass. `mapRpcError` still has exactly the four prefixes.
- [ ] **Step 2.** `create-invite` reads optional `person_id`. When present, the user-scoped client calls `assert_invite_person` before the service insert. The service insert writes `person_id`. Do not change the member check.
- [ ] **Step 3.** `accept-invite` selects `person_id`. After the membership upsert and before marking the invite accepted, the user-scoped client calls `link_accepted_person` when `person_id` is not null. A `NOT_FOUND:` from a null uid is a 401. Do not add email-match linking. Keep the M13 behavior that an existing membership role is not demoted.
- [ ] **Step 4.** Replace `remove_member` in the M14 migration. Copy the current checks and the membership delete. Schema-qualify them and set `search_path = ''`. After the delete:

```sql
update public.people
set user_id = null
where user_id = target
  and family_id = any (tree_ids);
```

Do not delete `story_people`. Keep the current exception strings.

- [ ] **Step 5.** `deno test` for the three functions passes. Commit: `feat(m14): invite links a person`

### Task 9: Client data and Add person

**Files:**
- Modify: `apps/tell_me_a_story/lib/data/people_api.dart`
- Modify: `apps/tell_me_a_story/lib/features/people/add_person_modal.dart`
- Modify: `apps/tell_me_a_story/test/people_api_test.dart`
- Modify: `apps/tell_me_a_story/test/add_person_modal_test.dart`
- Test: `apps/tell_me_a_story/test/m14_people_profiles_test.dart`

**Produces:** `Person.relationship` is `String?`. `PeopleApi.createPerson` takes name, optional birth, passing, about, email, and JPEG bytes. It does not take relationship. `AddPersonModal.show` returns the created person plus whether the caller chose "Send invite".

- [ ] **Step 1.** Widget tests:
  - Labels are exactly Name, Date of birth, Date of passing, Picture, About, Email. No Relationship control. The button text is "Add person" and the button shows a plus-circle.
  - A year-only birth and an About of 500 characters save. 501 does not call the API.
  - Setting a passing date hides Email. Saving that person sends no email and no invite.
  - Saving with an email opens a blur dialog titled `Send invite to Ada?` with "Send invite" and "Not now". "Not now" saves the email and does not call create-invite. "Send invite" saves, then calls create-invite with that `person_id` and email, then the existing send-invite-email.
  - Both date pickers show the M13 helper and "Shows as".
- [ ] **Step 2.** Run the new tests and confirm they fail.
- [ ] **Step 3.** Implement. Store dates with the rule in "Calls this plan locks". Insert the person, then upload JPEG bytes to `person-avatars` at `{id}/avatar.jpg` using the existing story-photo compressor, then update `avatar_path`. If passing is set, drop the email before insert. Reuse `familyBlurShell` for the confirm. No Cancel button on Add person.
- [ ] **Step 4.** Fix every current `Person(...)` and `createPerson(relationship:)` call so the suite compiles. Reader may still show a non-empty stored relationship. New people send null.
- [ ] **Step 5.** The new tests pass. Commit: `feat(m14): add person profile fields`

### Task 10: Profile modal from name pills

**Files:**
- Create: `apps/tell_me_a_story/lib/features/people/person_profile_dialog.dart`
- Modify: reader person row, new-story person chip, search person result, search story person chip, timeline full-card person chip
- Modify: `stories_api.dart` so a story carries `({String id, String name})` people, not names alone
- Test: `m14_people_profiles_test.dart`

- [ ] **Step 1.** Tests:
  - A pill tap opens a blur modal.
  - `person_profile` data shows Name, the birth "Shows as" line, passing, About, and the picture. No relationship, no Stories list, no email.
  - `is_linked` false shows Edit. `is_linked` true hides Edit for a different account.
  - A failed `person_profile` (`NOT_FOUND:`) shows the name only, with no Edit, no dates, no About, and no picture.
  - Picture order is the path `person_profile` already coalesced. Null path paints an empty circle, not email initials.
  - Add-person chooser rows, start-timeline member chips, and the invite picker do not open this modal.
- [ ] **Step 2.** Watch the tests fail.
- [ ] **Step 3.** Thread person ids into the full-card chip, the search story chip, and the reader row. Tapping a place chip does nothing new. The modal calls `person_profile`. Signed URLs: `person-avatars` when the path is `{person_id}/avatar.jpg`, otherwise the existing `avatars` bucket for an account path `{uid}/avatar.jpg`.
- [ ] **Step 4.** Tests pass. Commit: `feat(m14): open a person profile from a name pill`

### Task 11: Edit person

**Files:**
- Create: `apps/tell_me_a_story/lib/features/people/edit_person_dialog.dart`
- Test: `m14_people_profiles_test.dart`

- [ ] **Step 1.** Tests:
  - Edit is shown for an unlinked person and writes name, dates, about, and picture through the `people` update and `person-avatars`.
  - Email is prefilled from the `people` row and can be changed while unlinked. Changing it to a non-empty value shows the same send confirm. "Not now" saves the email and creates no invite.
  - Passing set hides Email.
  - When `user_id` equals the signed-in user, email is visible and read-only. Date of birth, About, and Picture are not on this form. Save writes passing, and name, to `people` only.
  - When `user_id` is some other id, Edit is absent.
- [ ] **Step 2.** Watch them fail, then implement. The edit gate reads `people.user_id` from the tree-member select. It does not read `user_id` from `person_profile`.
- [ ] **Step 3.** Tests pass. Commit: `feat(m14): edit an unlinked person`

### Task 12: Settings, one Save

**Files:**
- Modify: `apps/tell_me_a_story/lib/features/settings/settings_page.dart`
- Modify: `apps/tell_me_a_story/test/settings_page_test.dart`
- The profile API that already updates `profiles.display_name` and `avatar_path`

- [ ] **Step 1.** Tests: Settings shows Name, Date of birth, Picture, About, and the existing email control. One Save writes `profiles.display_name`, `birth_date`, `birth_precision`, and `about`, and still uploads the account picture to the `avatars` bucket. It does not write `people`. Date of passing is absent. The header menu still opens this page.
- [ ] **Step 2.** Watch them fail, then implement. Keep the M8 rule that a blank name is not saved. Keep the existing email-change call. Do not write `profiles.email` from the client.
- [ ] **Step 3.** Tests pass. Commit: `feat(m14): settings save writes the account profile`

### Task 13: Invite-link person picker

**Files:**
- Modify: `apps/tell_me_a_story/lib/data/invite_api.dart`
- Modify: `apps/tell_me_a_story/lib/features/invites/invite_modal.dart`
- Modify: `apps/tell_me_a_story/test/invite_chrome_test.dart`

- [ ] **Step 1.** Tests: the Link tab lists `list_unlinked_people` names plus "Someone new". People with a passing date are absent because the RPC omits them. Choosing a person calls create-invite with `person_id` and no email. "Someone new" calls create-invite with no `person_id`. The existing copy control and the 7-day line stay. Switching the pick creates another invite and does not revoke the previous one. The Email tab does not show this picker.
- [ ] **Step 2.** Watch them fail. Add optional `personId` to `InviteGateway.createInvite`.
- [ ] **Step 3.** Stop creating the link at the moment the Link tab opens. Create it when a row is chosen. Keep the SMS tab as a non-sending placeholder.
- [ ] **Step 4.** Tests pass. Commit: `feat(m14): invite link picks a person`

### Task 14: Gates

- [ ] From `apps/tell_me_a_story`: `flutter analyze` and `flutter test`.
- [ ] From the worktree: `supabase test db` and `deno test supabase/functions`.
- [ ] Paste the four outputs in the PR body. Include test counts, the policy count, the four locked calls, and the note that browser screenshots of the eight screens wait on the port 3000 server.
- [ ] PR title: `feat(m14): people profiles`. One PR. Do not merge.

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

Relationships as a feature, a deceased mark, family tree view, family friends, SMS send, email-match auto-link, a "this is me" step, a new error prefix, a wider `profiles` select, M13 date-rule changes, H1, and staging. Do not reopen M10, M11a, M11a.2, M11b, M12, or M13.

## Done

Bill smokes locally with the nine steps in the playbook. Lanes after the PR: Gilfoyle, Big Head, Mugatu, Dinesh, Jared. Trinity waits for H1. Bill merges.
