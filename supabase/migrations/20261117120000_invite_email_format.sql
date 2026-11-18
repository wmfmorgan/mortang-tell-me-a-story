-- Reject an invite email that is not an address on insert, or update of email.
-- A status change does not recheck, so the pending prod row email = 'joe blow'
-- can still be revoked.
-- Blank addresses become null (shareable links, LA-04).

create or replace function public.invites_email_format()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  if new.email is null then
    return new;
  end if;
  new.email := btrim(new.email);
  if new.email = '' then
    new.email := null;
    return new;
  end if;
  if new.email !~ '^[^@[:space:]]+@[^@[:space:]]+\.[^@[:space:]]+$' then
    raise exception 'VALIDATION: Please enter a full email address.';
  end if;
  return new;
end;
$$;

revoke all on function public.invites_email_format() from public;
revoke all on function public.invites_email_format() from anon, authenticated;

create trigger invites_email_format
  before insert or update of email on public.invites
  for each row
  execute function public.invites_email_format();
