# #42 Unloaded story people (UX)

Status: LOCKED by Bill, 2026-10-19 5:52 AM CT ("Yes, lock both").
Applies to: New story / Edit story (`new_story_page.dart`) and the story reader (`story_reader_page.dart`), wherever person chips are shown with a remove X.

## Definition
"Unloaded" = a person id linked to the story that the page could not load (for example, their family was soft-deleted, or the people load failed). Same set the code already tracks as `_unloadedPersonIds`.

## Rule 1: no remove X while anyone is unloaded
- While at least one linked person is unloaded, hide the remove X on **every** person chip on that story. The chips stay visible, but they can't be removed.
- Once every linked person has loaded, the X comes back on every chip.
- Adding people works exactly as it does today (picker, Create new person, multi-add).
- Why: removing a person in this state doesn't save, so the chip would vanish and then come back on reload. Hiding the X stops that silent failure.

## Rule 2: unloaded links count for publishing
- `publishReadiness` treats an unloaded linked person as a person. A story whose only linked person is unloaded is **not** "missing person".
- Why: the link exists in the database. The warning would be false.

## Unchanged / do-nots
- No new copy, no tooltip, no banner, no new colors or tokens. Chips keep their current look, minus the X.
- How unloaded people show today (or don't) stays the same. Don't add a placeholder chip for them.
- Semantics: a chip without an X exposes no remove action.
