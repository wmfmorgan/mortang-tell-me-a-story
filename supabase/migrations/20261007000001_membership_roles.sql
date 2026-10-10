-- M10: add owner and co_owner. Do not use the new labels in this file.
-- Postgres cannot use an enum value in the same transaction that adds it.

alter type public.membership_role add value if not exists 'owner';
alter type public.membership_role add value if not exists 'co_owner';
