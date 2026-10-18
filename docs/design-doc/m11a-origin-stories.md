## M11a Origin stories (Gilfoyle, LOCKED Bill 2026-10-11)
Product decisions are on the PRD and Decisions (Jared, 2026-10-11). UI is Mugatu's four M11a Stitch screens: Set as origin, the Set origin story banner, the origin dot with its tag and ring, and the delete warning. M11b (start a new timeline from a story or from the menu, plus the M12 leftovers) is out of scope here and gets its own section after M11a merges.
### Scope
- Every timeline, root or child, has one origin story. Owners and co-owners set or change it from the reader overflow menu (Set as origin). Changes take effect immediately.
- A child's origin must be a published story in its parent family. A root's origin must be a published story in its own family. One story can be the origin of several timelines.
- Until an origin is set, owners and co-owners see the Set origin story banner and the ring stays where M12 put it (`branch_year`, then the M12 no-year rule).
- On the child timeline the origin is the same story row, not a copy, drawn at its own `timeframe_start` with the tag Origin · from \{Parent\}. The parent ring sits beside that dot.
- Live members of the child family can add comments, perspectives and photos to its origin story. Only the author edits the story.
- Deleting an origin story shows the warning, then deletes. The link clears, the banner comes back, and `branch_year` stays as the ring fallback.
### Data (new migration; do not edit earlier files)
- `families.origin_story_id uuid null references public.stories (id) on delete set null`, plus index `families_origin_story_id_idx`.
- `families_guard_update()` adds `origin_story_id` to the locked fields unless `current_setting('app.family_origin', true) = 'on'`. Only the RPC below sets that flag (same pattern as `app.family_purge`). Direct PATCH of `origin_story_id` raises `FORBIDDEN: field is locked`.
- `branch_year` is unchanged and stays the fallback.
### Effective origin (one helper, used everywhere)
`public.family_origin(fid uuid) returns uuid`, security definer, stable. It returns `f.origin_story_id` only when all of these hold, otherwise null:
1. The family `fid` is live (`deleted_at is null`).
2. The story exists, `status = 'published'`, and its family is live.
3. `s.family_id = coalesce(f.parent_family_id, f.id)`.
This covers every edge without extra writes: a soft-deleted parent makes the origin unset until restore, an unpublished story reads as unset, and a parent purge (which nulls `parent_family_id`) makes a child's old origin unset because the story is no longer in its family. The stored id is kept, so a restore brings the origin back.
### RPCs (security definer, `(select auth.uid())`, null uid fails closed)
- `set_family_origin(p_family_id uuid, p_story_id uuid) returns void`
	- `FORBIDDEN` unless the caller is owner or co-owner of `p_family_id` and the family is live.
	- `NOT_FOUND` if the story doesn't exist.
	- `VALIDATION: origin must be published` if the story isn't published.
	- `VALIDATION: origin must be in parent family` (child) or `VALIDATION: origin must be in this family` (root) if `s.family_id <> coalesce(parent_family_id, id)`.
	- `VALIDATION: parent family is deleted` if the story's family is soft-deleted.
	- Sets `app.family_origin` locally, updates the row, done. No clear-origin call in M11a.
- `list_origin_dependents(p_story_id uuid) returns table (family_id uuid, name text)`: live families whose `family_origin(id) = p_story_id`. Caller must be a live member of the story's family, otherwise zero rows. The client calls it before delete; empty means the normal delete dialog, non-empty means the warning naming those families.
- `list_family_tree(fid)` gains a column `origin_story_id uuid` = `family_origin(id)`. Return type changes, so drop and recreate it in the new migration with the same body, guards and grants.
### Contributing to an origin story (amends RLS)
New security-definer helper `public.can_contribute_to_story(fid uuid, sid uuid) returns boolean` = `is_live_family_member(fid)` OR the caller is a live member of a live family `c` where `family_origin(c.id) = sid` and `c.parent_family_id = fid`.
- Comments, perspectives and photos keep `family_id` = the story's family. The M12 same-family check (`s.family_id = <tbl>.family_id`) stays as is.
- In those three tables, every INSERT and UPDATE policy that today uses `is_live_family_member(<tbl>.family_id)` uses `can_contribute_to_story(<tbl>.family_id, <tbl>.story_id)` instead. Author or uploader ownership checks stay. Delete-own policies get the same swap so a child member can remove their own row.
- Storage `story-photos` INSERT, UPDATE and DELETE use `can_contribute_to_story(seg1, seg2)` with the existing guarded uuid casts. The path stays `{story_family_id}/{story_id}/file`.
- SELECT needs no change: the story is published and in the same tree, so `is_family_tree_readable` already shows the story, comments, perspectives and photos to child members.
- Recreate policies under their existing names. The policy count must stay at 44.
- If the origin changes or goes unset, a child member's existing rows stay readable but they can no longer edit or delete them. That's intended.
### Client
- Banner shows when `origin_story_id` from `list_family_tree` for the open family is null and the caller is owner or co-owner.
- Set as origin (LOCKED Bill 2026-10-11, option 1): on a published story, the reader overflow shows one "Set as origin for \{Child\}" item for each live child family of the story's family that the caller owns or co-owns (from `list_family_tree` rows with `parent_family_id = story.family_id`, plus the caller's memberships with role owner or co_owner). For a root, it shows "Set as origin" when the caller owns or co-owns the story's own family and that family is a root. Each item calls `set_family_origin(<that family id>, story.id)`. The server checks the role on the target family, not on the family that's open, so the server is still the real gate.
- Child banner button "Choose from \{Parent\}" opens the parent timeline. Root banner tells the owner to open one of its own stories and use the same menu.
- Origin tags: a child's origin story shows "Origin · from \{Parent\}". A root's origin story shows a plain "Origin" tag (sage).
- The child timeline fetches the origin story by id (tree-read RLS already allows it) and merges it into its dots with the Origin · from \{Parent\} tag. The parent ring is placed beside it instead of at `branch_year`.
- The reader on an origin story shows add actions to child members. Realtime subscriptions for that story filter on `story_id`, not on the open family.
- Delete calls `list_origin_dependents` first and shows Mugatu's warning when it returns rows.
### Carried security item
Trinity TMAS-24-05 (places and `people_tree_read` scoped to published stories) was deferred to M11 and ships in M11a.
### Tests (pgTAP, mandatory)
- `set_family_origin`: owner and co-owner succeed. Member, non-member and no-uid get `FORBIDDEN`. Draft, wrong-family and soft-deleted-parent stories get `VALIDATION`. A root takes its own story and a child takes its parent's. One story can be the origin of two children.
- Direct `update families set origin_story_id` by an owner raises `FORBIDDEN`.
- `family_origin` is null after the parent is soft-deleted and is back after restore. It's null after the story is unpublished and null after the story is deleted (FK set null).
- A child member can insert a comment, perspective, photo row and storage object on the origin story. The same member is denied on a different parent story. A non-member of both is denied. After the origin changes, the child member is denied new rows.
- `list_origin_dependents` returns the dependents to a story-family member and zero rows to an outsider.
- Policy count is exactly 44. `flutter test` covers the banner gate, the overflow gate, origin dot placement and the delete-warning branch.
## M11a.2 Origin stories hardening (LOCKED — Bill, 2026-10-11, relayed by Erlich)
Source: Trinity's audit of 7cd6bc4, which passed with 0 Critical, 0 High, 1 Medium and 3 Low findings. This section does not change the M11a access model. Policy count is unchanged by these calls. It ships before M11b, on its own migration after 20261011150000.
### M11A-01: lock row identity on contributor updates
- Add a BEFORE UPDATE guard trigger on public.comments, public.perspectives and [public.photos](http://public.photos), built the same way as families_guard_update.
- Comments and perspectives may change only body and updated_at. Any change to id, story_id, family_id, author_id or created_at raises `FORBIDDEN: field is locked`.
- Photos may change only sort_order. Any change to id, story_id, family_id, uploader_id or storage_path raises `FORBIDDEN: field is locked`.
- No column-limited grants. They are fragile next to the DDL's `grant all` plus the default privileges, and they break upserts without saying so.
- FK cascades are deletes, so the guard does not need to exempt them.
### M11A-02: one error for an origin story you can't use
- In set_family_origin, FORBIDDEN stays the first gate (signed in, live family, owner or co-owner).
- A missing story, a story that isn't published, and a story outside coalesce(parent_family_id, id) all raise one error, `NOT_FOUND`.
- `VALIDATION: parent family is deleted` stays, because it's about the caller's own family.
- The client error mapping in families_api.dart already handles `NOT_FOUND`.
### M11A-03: story_row_exists keeps its grant (accepted residual risk)
- families_guard_update runs as security invoker so its current_user check sees the real caller, which means authenticated needs execute on story_row_exists.
- The only thing it reveals is whether a random UUID exists, with no row content. That is accepted and recorded here.
- anon stays revoked, and a pgTAP test pins that.
### Info items
- Every security definer function added in 20261011150000 moves to `set search_path = ''`. Their bodies already name public.\* explicitly. Sweeping older functions is out of scope.
- Photo cap enforced on the server: a security definer BEFORE INSERT trigger on [public.photos](http://public.photos) locks the parent stories row (`for update`) and raises `VALIDATION: photo limit reached` once the story already has 20 photos, matching maxPhotosPerStory. The client cap stays as UX.
### Tests (pgTAP)
- For each table, every locked column rejects a change, and the allowed columns still update.
- A row can't be moved to another story the author could also contribute to.
- set_family_origin returns `NOT_FOUND` for a missing story, a draft, and a story in the wrong family.
- The 21st photo insert fails, and the 20th succeeds.
- Deleting the origin story still lets the FK set origin_story_id to null.
- anon can't execute story_row_exists.
### Not in M11a.2
- Owner and co-owner story editing (M13 item 8).
- Moving older definer functions to an empty search_path.
- Any change to who can contribute.
### M11a.2 plan-review amendments (Gilfoyle, 2026-10-11; Bill accepted Trinity 02/03 as residual)
- Guards compare with a whitelist: `to_jsonb(new) - allowed` against `to_jsonb(old) - allowed`. No bypass for any role, because every FK on these tables is `on delete cascade`.
- `set_family_origin` order: the FORBIDDEN gate, then a deleted-parent `VALIDATION`, then one story lookup where every miss is `NOT_FOUND`.
- The photo cap locks the story row with `for no key update`.
- Photo Remove shows only to the uploader or the story author, matching `photos_delete_uploader_or_author`.
- Trinity 02/03 (storage uploads aren't counted, and members can overwrite files in their family's paths) are accepted residual risks. There are no storage policy changes in M11a.2.
