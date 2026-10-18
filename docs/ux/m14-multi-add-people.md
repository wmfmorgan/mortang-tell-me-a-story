# Multi-add people from the Add person picker (#50)

Status: LOCKED by Bill 2026-10-18. Amended 2026-10-18 to settle the Create new person and Cancel conflicts.
Source: PRD addendum (APPROVED) https://app.notion.com/p/3e0c4bcef238813e843af14d12c9a4b2 and the Decisions entry from 2026-10-18.
Applies to the Add person picker step (`add_person_modal.dart`) from both New story and Edit story. No new screen, no checkboxes, no Stitch edit. The M14.1 picker rules stay unless this note changes them.

## Selected-pill state
- Tapping a person pill selects it instead of linking right away. Tapping it again clears the selection.
- A selected pill gets a sage tint fill (`albumSage` at 0.18), a full `albumSage` border, and a check icon in place of the initials circle. The check means the state isn't shown by color alone.
- Hover stays a hover only, as M14.1 says.
- Screen readers announce the pill as selected.
- Searching filters the list but keeps every selection, including people filtered out of view.
- People already on the story stay hidden. There's no cap.

## Commit
- The picker step footer has the existing Cancel button on the left and the existing terracotta "Add person" button on the right. Add person stays disabled until at least one pill is selected.
- One tap links every selected person to the story, then the picker closes. While it's saving, the label reads "Adding…", the existing busy label.
- If some links fail, the existing error pop-up shows the usual text. People who saved drop off the list, and the rest stay selected so the user can tap Add person again.
- Cancel and the header X both close the picker and add nobody.

## Create new person
- You can add several existing people, or create one new person, but not both in one go (Bill, 2026-10-18).
- "Create new person" works as it does today. Opening it clears any selected pills, and the form's Add person button adds only the new person.
- Invites stay per person as they are today.

## Unchanged
- The Search screen's Add Person filter.
- Copy: no new words. Labels are "Add person", "Adding…", "Cancel", "Create new person" and "Search people in this family".
- Colors: `album_theme.dart` tokens only.
