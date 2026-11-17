-- Invite emails are trimmed and rejected when the address is not an email.
-- The check runs on insert only, so a row already stored (prod 'joe blow')
-- can still be updated.
begin;
create extension if not exists pgtap with schema extensions;

select plan(4);

insert into auth.users (id, email, raw_user_meta_data)
values (
  'c0ffee00-0000-4000-8000-000000000001',
  'owner@test.local',
  '{"display_name":"Owner"}'::jsonb
);

insert into public.families (id, name, created_by)
values (
  'c0ffee00-0000-4000-8000-000000000002',
  'Ada',
  'c0ffee00-0000-4000-8000-000000000001'
);

select throws_ok(
  $$insert into public.invites (family_id, invited_by, email, token)
    values (
      'c0ffee00-0000-4000-8000-000000000002',
      'c0ffee00-0000-4000-8000-000000000001',
      'joe blow',
      'tok-bad-email'
    )$$,
  'P0001',
  'VALIDATION: Please enter a full email address.',
  'a name is not stored as an invite email'
);

insert into public.invites (family_id, invited_by, email, token)
values (
  'c0ffee00-0000-4000-8000-000000000002',
  'c0ffee00-0000-4000-8000-000000000001',
  null,
  'tok-link-only'
);

select ok(
  exists (
    select 1 from public.invites
    where token = 'tok-link-only' and email is null
  ),
  'an invite with no email is still allowed'
);

insert into public.invites (family_id, invited_by, email, token)
values (
  'c0ffee00-0000-4000-8000-000000000002',
  'c0ffee00-0000-4000-8000-000000000001',
  '  a@b.co  ',
  'tok-trimmed'
);

select is(
  (select email from public.invites where token = 'tok-trimmed'),
  'a@b.co',
  'the stored email is trimmed'
);

alter table public.invites disable trigger invites_email_format;
insert into public.invites (family_id, invited_by, email, token)
values (
  'c0ffee00-0000-4000-8000-000000000002',
  'c0ffee00-0000-4000-8000-000000000001',
  'joe blow',
  'tok-existing-bad'
);
alter table public.invites enable trigger invites_email_format;

update public.invites
set status = 'revoked'
where token = 'tok-existing-bad';

select is(
  (select status::text from public.invites where token = 'tok-existing-bad'),
  'revoked',
  'an invite email already stored can still be updated'
);

select * from finish();
rollback;
