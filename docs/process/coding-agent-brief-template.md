# Coding-agent brief

Copy this into the agent prompt. Fill every heading. Erlich sends one brief per PR.

## Goal

[One sentence. What this PR ships.]

## Lane

[client | backend | docs]

## Base branch & branch name

- Repo: `<owner/name>`
- Base branch: `main` (or active feature branch)
- Branch name: `<lane>/<milestone>-<slug>`, or `docs/<slug>` for a docs PR

## Approved Spec section URL

[URL of the one plan or Notion spec section, plus the heading.]

## UI Visual Lock

For a UI slice, fill all four fields. Stitch is the visual lock. The cited `docs/ux/` sections supply the exact tokens and numbers, in sync with Stitch. For a non-UI or docs slice, replace this body with `N/A`.

- Stitch project ID:
- Locked R-IDs:
- `docs/ux/` sections:
- Contact sheet path:

## Acceptance checks

- [ ] [Observable check a reviewer can read from the diff or the running slice.]

## Standard execution rules

- Work directly in the repo.
- Do not spawn nested worker subagents for a single-PR slice.
- Make the first commit within 15 minutes.
- Do not take VM screenshots. Never attach real-family or prod screenshots to this public repo.
- End the run after opening the PR. Do not watch CI.

## Definition of Done

- [ ] The diff is only the files this brief names, on this lane, branched from the base branch above.
- [ ] The PR body uses the section order in `AGENTS.md`, including **Visual acceptance** (cited Stitch screen IDs and cited `docs/ux/` sections, or `N/A (non-UI)`).
- [ ] A UI PR leaves Deploy Preview verification to Mugatu: 1280px and 390px against the dedicated synthetic fixture family per FT-R15.
- [ ] The PR is open against the base branch above. The run stops there.
