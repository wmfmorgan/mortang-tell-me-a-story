# Writing Specs

A spec states what problem to solve, for whom, and how to tell it is solved.
It is the first document in the spec -> DD -> TDD flow and says nothing about how to build the solution.

## The flow

```
spec --gate 1--> DD --gate 2--> TDD (n) --ship--> project-context.md (durable decisions)
```

| Stage | Answers | Written for | File name | Deleted by | Guide |
|---|---|---|---|---|---|
| Spec | What and why | Stakeholders, approver | `YYYYMMDD-<title>-spec.md` | PR that completes the last TDD | this file |
| DD | Direction, components, split into TDDs | TDD authors | `YYYYMMDD-<title>-dd.md` | PR that completes the last TDD | [writing-dds.md](writing-dds.md) |
| TDD | Contracts for one shippable unit | Reviewer, coding agent | `YYYYMMDD-<title>-tdd.md` | PR that completes that TDD | [writing-tdds.md](writing-tdds.md) |

## Lifecycle

- Specs, DDs, and TDDs live in `.context/active/` as `YYYYMMDD-<title>-spec.md`, `-dd.md`, and `-tdd.md`, dated the day you create them.
- Other active docs (migration plans, findings) use `YYYYMMDD-<title>.md`.
- A doc is accepted when the PR that adds it merges after review by the spec's approver.
- A spec PR merges only when the spec passes Gate 1.
- The PR that completes a TDD deletes that TDD and sets its work-breakdown row in the DD to `done`.
- The PR that completes the last TDD of a chain also deletes its spec and DD.
- That PR description records the result of each goal check (`G1: pass (4.2 s)`); write `pending: <how and when measured>` for checks that need production data.
- Before any delete, move durable decisions into the `## Durable Decisions` section of `.context/project-context.md`.
- Never leave a finished doc behind.

## Skip the DD

Small work goes spec -> one TDD, with no DD.
Skip the DD only if the work passes the [TDD sizing gate](writing-tdds.md#sizing-gate).
If you find a second TDD, stop and write a DD.

## Scope

A spec states the problem and the outcome only.
It names no components, tools, or data layouts, except fixed constraints.

## Language

Follow [writing-tdds.md#language](writing-tdds.md#language).
One deviation: specs can use short prose, because stakeholders read them.

## Structure

Use these sections, in order. Hard cap: ~120 lines.

1. **Summary** - the problem and the outcome in 2-4 sentences.
2. **Background** - who needs this, how they work today, what fails, and the current baseline as a number or `unknown`.
   Link notes; never paste them.
3. **Stakeholders** - one line each, with role (requester, user, data owner, approver).
   Name exactly one approver.
4. **Goals** - numbered `G1`, `G2`, ...
   Each goal has a finite check.
   Mark optional goals `(optional)`.
   The work is done when every non-optional check passes.
   - Bad: `G1: Reports are faster.`
   - Good: `G1: The weekly report renders in < 5 s for the largest project (today: 40 s).`
5. **Non-goals** - scope this work will not address.
6. **Constraints** - each applicable item, for example upstream systems, access, deadlines, data freshness, sensitivity.
   Write `None.` if nothing applies.
7. **Open questions** - one line each, with owner and tag `blocks gate 1` or `can wait`.
   Close every `can wait` question before the DD is accepted, or list it under the DD's risks.

## Gate 1: spec to DD

Start the DD only when every item holds:

- [ ] Every goal has an ID and a finite check.
- [ ] Stakeholders are listed, with exactly one approver.
- [ ] Background states a baseline, or `unknown`.
- [ ] Non-goals are listed.
- [ ] Constraints are filled in or `None.`
- [ ] No open question tagged `blocks gate 1` remains.
- [ ] The spec names no components, except fixed constraints.
