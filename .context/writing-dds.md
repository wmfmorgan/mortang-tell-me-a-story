# Writing Design Documents (DDs)

A design document (DD) takes one accepted spec (merged after passing Gate 1), decides direction, components, and data movement, and splits the work into TDDs.
For file name and lifecycle, see [writing-specs.md#lifecycle](writing-specs.md#lifecycle).

## Language

Follow [writing-tdds.md#language](writing-tdds.md#language).
One deviation: short rationale paragraphs are allowed.

## Structure

Use these sections, in order. Hard cap: ~250 lines.

1. **Summary** - 2-4 sentences.
   Link the spec and list the goal IDs this DD serves.
   Never restate goals.
2. **Glossary** - one line per term.
   TDDs copy entries verbatim.
3. **Current state** - ASCII diagram, or `None.`
4. **Target state** - container-level ASCII diagram, one sentence per component.
5. **Data flow** - one short subsection per scenario: trigger, path, storage, refresh.
   Do not restate component responsibilities.
6. **Decisions** - per decision: options considered (one line each), the choice, and why in <= 2 sentences.
   Include cross-cutting decisions here.
   Decisions that outlive the project also go to the `## Durable Decisions` section of `.context/project-context.md`.
7. **Work breakdown** - one row per TDD:

   | TDD | Scope | Goal IDs | Depends on | Status |
   |---|---|---|---|---|

   Each row passes the [TDD sizing gate](writing-tdds.md#sizing-gate).
   Status is `planned`, `active`, or `done`. The PR that completes a TDD sets its row to `done`; the row keeps the TDD title after the file is deleted.
8. **Risks and open questions** - one line each, with owner.
   Mark items that block a TDD `blocks <TDD>`.

## What a DD leaves out

- Function signatures.
- Full schemas.
- Per-unit acceptance criteria.
- File pointers.

These belong in the TDDs.

## Editing pass

Cut any sentence a TDD author would not need to stay consistent with sibling TDDs.
Every non-optional `G` in the spec appears in at least one work-breakdown row.
