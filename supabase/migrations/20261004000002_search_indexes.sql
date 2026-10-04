-- M7 lookup indexes. No new columns, policies, or search functions.
-- Timeframe lookup already exists as stories_family_id_timeframe_idx.

create index story_people_person_id_idx on public.story_people (person_id);

create index stories_place_id_idx on public.stories (place_id);

create index people_family_id_name_idx on public.people (family_id, name);

create index places_family_id_label_idx on public.places (family_id, label);
