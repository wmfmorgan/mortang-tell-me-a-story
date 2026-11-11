# Writing Technical Design Documents (TDDs)

A TDD is reviewed by a human and implemented by a coding agent.
It pins every decision that crosses a contract boundary and stays silent on the rest.
Its source is one row of a DD work breakdown, or a spec when you [skip the DD](writing-specs.md#skip-the-dd).
For file name and lifecycle, see [writing-specs.md#lifecycle](writing-specs.md#lifecycle).

## Gate 2: before you start

Source is a DD: start only when every item holds:

- [ ] The DD is accepted.
- [ ] The DD glossary covers every term this TDD uses.
- [ ] The work breakdown names this TDD, its scope, and its dependencies.
- [ ] This TDD passes the sizing gate.
- [ ] No open question in the DD `blocks` this TDD.

Source is a spec (DD skipped): start only when the spec is accepted and this TDD passes the sizing gate.

If this TDD needs to change a DD decision, stop and amend the DD first.

## Sizing gate

One TDD = one independently shippable and revertable unit of work.
The scope is too big or too low-level if any of these hold:

- The architecture diagram needs more than ~6 components.
- The doc needs more than 3 sequence diagrams.
- A diagram cannot be drawn in simple ASCII.

Then stop and propose a split instead of writing one TDD.

## Structure

Use these sections, in order. Hard cap: ~250 lines.
If a section holds nothing a reviewer would reject a PR over, write `None.`

1. **Context** - 2-4 sentences on what exists and what is missing.
   Link the source DD or spec and list the goal IDs served.
   Copy glossary entries verbatim from the DD. DD skipped: write the glossary here.
2. **Non-goals and forbidden approaches** - scope this work will not address.
   Add forbidden approaches only to stop a specific, plausible mistake.
3. **Requirements and invariants** - requirements `R1`, `R2`, ...; each has one reading and a finite check.
   Invariants `I1`, `I2`, ... hold before and after the work ships.
4. **Architecture** - container-level ASCII diagram, one sentence per component.
   Then ASCII sequence diagrams for the flows that touch the most surface.
5. **Data model and interfaces** - entities, relationships, access patterns; interface names and purpose.
   Pin exact types only when a different shape would fail review.
6. **Behavior rules** - each rule numbered `B1`, `B2`, ..., stated once in prose, then 1-3 worked examples (input -> outcome), including the ugliest edge case.
   Examples are normative: if prose and example conflict, the example wins and you fix the doc.
7. **Acceptance criteria** - observable checks that convert directly into tests.
   Each cites the `G`, `R`, `I`, or `B` IDs it verifies and does not restate them.
   For large work, group criteria into ordered milestones.
8. **Cross-cutting concerns** - only deviations from repo conventions.
9. **References** - patterns to imitate, one line each with a file path.
   Alternatives considered, one line each.
10. **Halt conditions** - every unresolved item, as `If X, stop and ask.`
    Leave no ambient open questions.

## Language

This section is the single home of style rules for specs, DDs, and TDDs.
Each rule has at most one bad example.

- One term per concept, defined in the glossary, used identically every time.
  Bad: "page metadata" / "target page" / `PageMetadata` for one thing.
- Active voice with a named actor as subject.
  Bad: "Output is accepted after validation." (accepted by what?)
- One fact per sentence, under ~20 words.
- Use verbs, not zombie nouns.
  Bad: "the extraction of claims" / "claim extraction processing" (write "extract claims").
- Keep noun clusters to 3 words at most.
  Bad: "source-plan-bound extraction result contract".
- State behavior positively; never stack negations.
  Bad: "Do not publish unsupported claims as supported."
- No weak words. must = required; can = is able to; may = permitted and optional. No other modals.
  Bad: "Show the source span when available." (available when?)
- Keep enumerations parallel: every item at the same level of abstraction.
- Cross-reference by ID instead of restating a rule in another section.
- State decisions, not arguments. Write "Uses Postgres", not a comparison.
- Bullets for enumerable facts; prose only for rationale.
- No pseudocode, snippets, or signatures, except pinned contract types.
- Diagrams are plain ASCII only. If it does not fit ASCII, it is too low-level.
- Write for an engineer who knows the stack. Do not explain the framework.
- Keep the doc self-contained. Link outside context; never summarize a chat.

Editing pass: for each sentence, ask "if the implementer decided this differently, would the PR be rejected?"
If no, cut it.
Coverage: every listed `G` and every `R`, `I`, and `B` has at least one acceptance criterion.

## Agents

- Read the whole chain (spec, DD, TDD) before implementing.
- Never edit an accepted doc, except in a PR whose description states the change. Exceptions: setting a work-breakdown status and the deletes in the lifecycle.
- Create design docs only when asked.
