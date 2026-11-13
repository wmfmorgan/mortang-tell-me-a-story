# #82 Family switch landing (UX rev 4, LOCKED 2026-10-22)

Locked: Bill 2026-10-22 6:18 AM CT, relayed by Erlich: "Lock #82 UX rev 4, including the first-sentence-only body on non-switch exits".
Source: PRD "Family switch landing (#82)", approved by Bill 2026-10-21 8:53 PM CT, narrowed 2026-10-22 using Bill's 5:52 AM CT quote. Issue: https://github.com/wmfmorgan/mortang-tell-me-a-story/issues/82
No new screens, menu or chrome. The only new copy is the Leave this story? prompt (Bill-approved mock copy). The existing header family menu (`_FamilyMenu`, `core/theme/album_header.dart`) stays as it looks today.

## Rule 1: a different family lands on its timeline
Picking a family other than the current one in the header menu sets it as the session family (as today, uxd-handoff :149) and goes to `/timeline` for that family, from every screen that shows the menu:

| Screen | Today | #82 |
|---|---|---|
| Timeline | reloads in place | unchanged (already the timeline) |
| Drafts | reloads drafts in place | go to that family's timeline |
| Settings | relabels menu, stays | go to that family's timeline |
| Manage hub / family detail | goes to timeline | unchanged |
| New story / resumed draft / Edit story | relabels menu only; draft keeps old family | go to timeline, after the Rule 2 prompt when needed |

- Landing is a normal open of that family's timeline: the same first view you get from the Timeline link (uxd-handoff :150). It does not carry over scroll position or zoom from the previous family.
- Related-family rows in the same menu follow the same rule (they use the same handler today).
- No toast, banner or animation. The changed menu label and the new timeline are the feedback.
- No family menu on the story reader modal, the shared-link reader or the person pop-up (PRD). Those stay as they are.

## Rule 3: the current family does nothing
Picking the family that is already current just closes the menu. No navigation, no reload, no re-save of the selection, on any screen, including New story and Edit story.

## Rule 2: ask only where typing would be lost
Bill 2026-10-22 6:06 AM CT (relayed by Erlich): "ask Save/Discard/Stay only on screens where typing would be lost". Every other screen switches instantly. Facts: Gilfoyle's code check of which edit screens can lose input (2026-10-22, main @ 5161164).

### When the prompt shows
Only when you pick a **different** family, and only when the screen has input that isn't saved:

| Screen | Prompts when | Save means |
|---|---|---|
| New story / resumed draft | Year, month, day, place, or a removed person changed since the last autosave (autosave doesn't watch those), or a brand-new story has only date/place filled in | Save draft, the same action as the Save draft button |
| Edit story | Anything changed since the page opened | Save changes |
| Settings (profile) | A profile field differs from what's saved | the page's Save |
| Manage family detail | The rename field differs from the family's saved name | Rename |

- Title or body typing on New story that has already autosaved (the grey "Saved" label) does **not** prompt. It switches instantly, flushing the autosave as it does on leave today.
- Picking the current family never prompts (Rule 3).
- Dialog-only edits (Add person, Edit person, comments, perspectives, invite) are out of scope. The family menu can't be reached while they're open.

### The prompt
One dialog for all four screens: the M10 blur dialog (`showFamilyBlurDialog` look). The whole page is dimmed and blurred, on a #FFF8F6 card with a Newsreader title, Literata body and an X close. It is not a stock AlertDialog.
- Buttons are right-aligned: **Stay** (ink text button), **Discard** (outlined: ink text, sage border), **Save** (filled terracotta). Discard isn't red, because red is kept for permanent deletes. On phone widths the buttons stack full-width with Save on top, then Discard, then Stay.
- Copy:
  - Title, all screens (Bill 2026-10-22 6:15 AM CT, "Keep the mock copy exactly: 'Leave this story?' everywhere"): "Leave this story?"
  - Body on a family switch (mock): "You have changes that aren't saved. Save them before switching to <family name>?"
  - Body on a leave that isn't a family switch: the first sentence only, "You have changes that aren't saved." There is no family name to show, and no other new copy is added.
  - Buttons: Stay, Discard, Save.
- Stay, the X, tapping outside the card and Esc all mean Stay.

### What each button does
- **Stay:** the dialog closes. You stay on the page with your input untouched, and the menu still shows the current family. The switch never happened.
- **Discard:** the unsaved input is dropped and you land on the new family's timeline. On New story, anything already autosaved stays in Drafts; only the unsaved date, place or person change is lost. A brand-new story with nothing autosaved is not kept.
- **Save:** runs that screen's own save, shown in the table above. When it succeeds you land on the new family's timeline.
  - While it saves, all three buttons are disabled and tapping outside does nothing. There's no new spinner copy; Save shows its existing busy state.
  - If the save fails, or the screen's own checks block it (for example Edit story's required fields), the dialog closes and you stay on the page with that screen's existing error. There's no switch and no new error copy.

### New and Edit story with nothing unsaved
- You land on the new family's timeline right away. A New story or draft keeps its autosave-on-leave, as it does today.
- A draft stays in the family it was started in, and you find it in that family's Drafts (Bill 2026-10-22 6:10 AM CT, relayed by Erlich). Switching never moves a draft. Whenever a story or draft is open, the header shows the family it belongs to.

## Rule 5: leaving a story with unsaved input
PRD (Bill 2026-10-22 6:11 to 6:13 AM CT). This amends the 2026-10-16 lock and replaces uxd-handoff.md:160 ("There is no leave prompt").
- Screens: New story or resumed draft, and Edit story only. Settings and Rename prompt on a family switch only (Rule 2).
- Unsaved input means:
  - New story: anything autosave hasn't captured yet. That's a date (year, month or day), a place or a person removal, or title or body text typed within the 2-second autosave delay.
  - Edit story: any change not yet saved with Save changes.
- Exits that trigger the prompt (the same dialog as Rule 2):
  - In-app links: Timeline, Drafts, Search, Settings, Logout, Start a family, and Manage families.
  - The page's own back, and Cancel on Edit story.
  - A family switch.
  - Browser or system back.
- Nothing unsaved: you leave quietly, and the draft stays in Drafts.
- Tab close and refresh show only the browser's generic leave warning. There's no custom dialog there.
- The buttons behave as in Rule 2:
  - Stay keeps you on the page.
  - Discard drops the unsaved input and finishes the exit.
  - Save runs Save draft (New story) or Save changes (Edit story), then finishes the exit. If the save fails, you stay on the page with the existing error.
- Logout: Save runs before sign-out begins.
- Publish, Save draft and Save changes are not exits. They save first, so they never prompt.

## Stitch
- Prompt screen, picked by Bill 2026-10-22 6:10 AM CT: https://stitch.withgoogle.com/projects/12192342757314667328?node-id=0c0f60eae17b44bfbbfc12298c2ae4e3 (New story behind the prompt).
- Written rules override mock quirks: the mock shows the family menu still open behind the dialog, but in the app it closes when you pick. The mock's "PROPOSED COPY" label is not shipped.
- Duplicates `13b9d93cd2b34dd9adb5eb306ae0a257` and `cb071407e53943f7a7d00e396158264e` (mislabeled M13) are not part of the lock.

## OPEN
None.
