create function public.same_family_tree(a uuid, b uuid)
returns boolean
language sql stable security definer
set search_path = ''
as $$
  select coalesce(public.is_tree_member(a) and public.is_tree_member(b) and public.family_tree_root(a) = public.family_tree_root(b), false);
$$;
revoke all on function public.same_family_tree(uuid, uuid) from public, anon;
grant execute on function public.same_family_tree(uuid, uuid) to authenticated;

alter policy story_people_insert_editor on public.story_people
  with check (
    public.can_edit_story(story_id)
    and exists (
      select 1 from public.people p
      join public.stories s on s.id = story_people.story_id
      where p.id = story_people.person_id
        and public.same_family_tree(p.family_id, s.family_id)
    )
  );

alter policy story_people_update_editor on public.story_people
  using (public.can_edit_story(story_id))
  with check (
    public.can_edit_story(story_id)
    and exists (
      select 1 from public.people p
      join public.stories s on s.id = story_people.story_id
      where p.id = story_people.person_id
        and public.same_family_tree(p.family_id, s.family_id)
    )
  );
