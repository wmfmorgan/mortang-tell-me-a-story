revoke execute on function public.upsert_story_member(uuid, uuid)   from anon, authenticated;
revoke execute on function public.resolve_person_user(uuid, text)   from anon, authenticated;
revoke execute on function public.family_tree_ids(uuid)             from anon, authenticated;
revoke execute on function public._require_family(uuid)             from anon, authenticated;
revoke execute on function public.purge_expired_families()          from anon, authenticated;
-- hygiene (trigger functions; not callable, no behavior change):
revoke execute on function public.handle_new_user()                 from public, anon, authenticated;
revoke execute on function public.sync_profile_email()              from public, anon, authenticated;
revoke execute on function public.photos_cap_insert()               from authenticated;

revoke execute on function public.is_family_member(uuid)                 from anon;
revoke execute on function public.is_family_owner(uuid)                  from anon;
revoke execute on function public.is_family_co_owner(uuid)               from anon;
revoke execute on function public.create_family(text)                    from anon;
revoke execute on function public.add_co_owner(uuid, uuid)               from anon;
revoke execute on function public.remove_co_owner(uuid, uuid)            from anon;
revoke execute on function public.rename_family(uuid, text)              from anon;
revoke execute on function public.soft_delete_family(uuid)               from anon;
revoke execute on function public.recover_family(uuid)                   from anon;
revoke execute on function public.transfer_ownership(uuid, uuid, text)   from anon;
revoke execute on function public.remove_member(uuid, uuid)              from anon;
revoke execute on function public.resend_invite(uuid)                    from anon;
revoke execute on function public.revoke_invite(uuid)                    from anon;

drop function if exists public.ensure_story_person_membership();
