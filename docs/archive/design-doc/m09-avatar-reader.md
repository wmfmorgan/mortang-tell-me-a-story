## M9 avatar visibility (Gilfoyle, 2026-10-05)
Architecture lock only. Not a milestone stamp. Bill, 2026-10-05: within a family, anyone can see anyone's name and picture. Amends M8. Names already work this way (co-member `profiles` SELECT, 2026-09-27). This adds pictures.
### Storage
- Bucket `avatars` stays private. No public URL. Path stays `{uid}/avatar.jpg`.
- SELECT is your own object, or the object of any user who shares at least one family with you. Same co-member rule as `profiles` SELECT.
- INSERT, UPDATE, DELETE stay own object only. `avatars_insert_own`, `avatars_update_own`, `avatars_delete_own` do not change.
- New migration, timestamped after `20261005000001`. Do not edit `20261005000001_profile_avatar.sql`; it is on main.
```sql
drop policy if exists avatars_select_own on storage.objects;

create policy avatars_select_own_or_comember
  on storage.objects for select
  to authenticated
  using (
    bucket_id = 'avatars'
    and (
      name = (auth.uid()::text || '/avatar.jpg')
      or exists (
        select 1
        from public.memberships mine
        join public.memberships theirs
          on theirs.family_id = mine.family_id
        where mine.user_id = auth.uid()
          and name = (theirs.user_id::text || '/avatar.jpg')
      )
    )
  );
```
### Client
- The reader author circle uses the M8 circle rule. Picture when the author's `avatar_path` is not null. Otherwise initials from the author's saved `display_name`. Empty only when both are missing.
- Load another member's picture with a signed URL from the `avatars` bucket. No public URL. If the load fails, paint initials.
- Read `avatar_path` and `display_name` through the existing `profiles` join. Do not copy them onto `stories`.
### Tests
- RLS SQL: a co-member can select another member's avatar object. A user in a different family cannot. A co-member cannot insert, update, or delete another member's object.
> 🚫 FORBIDDEN: A public avatar URL or a public bucket. Read access for anyone outside a shared family. Write access to another member's object. Denormalizing `avatar_path` or author name onto `stories`. Editing the merged M8 migration.
## M9 reader data map (Gilfoyle, 2026-10-05)
Architecture lock only. Not a stamp. Maps Mugatu's locked screen `221229a5` onto columns already on main. M9 adds no table or column. The only migration is M9 avatar visibility above.
- "Recorded event: \{date\}" is `stories.timeframe_start`, plus `timeframe_end` when it is set.
- "Documented \{Month YYYY\}" is `stories.published_at`. `stories` has no `created_at`; do not add one.
- "by \{author\}" plus the avatar comes from `stories.author_id` joined to `profiles` (`display_name`, `avatar_path`), using the M8 circle rule and M9 visibility.
- "\{n\} min read" is computed on the client from `stories.body`: word count divided by 200, rounded up, with a minimum of 1. Nothing is stored.
- The people chips come from `story_people` joined to `people` (`name`, `relationship`).
- The place chip is `places.label`, or `places.address` when the label is blank.
- The decade chip is computed on the client from `timeframe_start` (1974 shows as 1970s).
- The wide top image is the `photos` row with the lowest `sort_order`, loaded through a signed URL from `story-photos`. No photo means no image block.
- The "Family Keepsake" eyebrow is static text.
- The modal reuses the existing reader query. The reader route stays the deep-link target. The Macro year tap is client navigation only.
> 🚫 FORBIDDEN: A photo caption. `photos` has no caption column, so the caption line in the Stitch screen is not built. Print and Share buttons (Mugatu marked them OPEN, not M9). Any new column, table, Edge function, or package for M9.
## M9 zoom taps (Gilfoyle, 2026-10-06)
Architecture lock only. Not a stamp. Bill 2026-10-06: supersedes the 2026-10-05 Macro-dot → reader rule on Spec §15 / M9 playbook.
### Taps
- Macro **decade label**, Macro **decade node**, and Macro **story dot** open Mid, centered on that year or story. They do **not** open the reader.
- Mid **stub** and Near **full card** still open the reader modal (`221229a5`).
- Mid **rail node** (the circle on the dashed rail) opens Near (full cards), focused on that story. It does **not** open the reader.
- Up/down arrow keys step each zoom rail. Client-only. No new route, table, or Edge.
### Reader open paths (unchanged otherwise)
- Mid stub, Near full card, cold `/stories/:id`, and Search “Read Story →” still open the reader (modal when pushed over the timeline; full page on cold deep link).
> 🚫 FORBIDDEN: Macro story dots opening the reader. Treating Mid rail nodes as reader opens. New tables, columns, Edge, or packages for zoom/arrows.
## Invite Stitch chrome on M9 PR (Gilfoyle, 2026-10-06)
Architecture lock only. Not a stamp. Bill 2026-10-06: allow the invite dialog restyle on PR #22 even though it is outside the M9 reader playbook.
- Email, Text (SMS), and Link tabs match the locked Stitch invite screens.
- **Email** and **Link** stay the only send paths in v1: `create-invite` + `send-invite-email` (Resend) and shareable link copy/generate. Contracts unchanged.
- **SMS tab is visual only.** No phone send, no SMS Edge, no Twilio. Placeholder until the Design Doc SMS fast-follow.
- Personal note fields on the screen are chrome only; `send-invite-email` has no note body field.
> 🚫 FORBIDDEN: Inventing an SMS Edge function or client SMS send in this PR. Changing create-invite / send-invite-email / accept-invite contracts. Treating the SMS tab as a working send.
