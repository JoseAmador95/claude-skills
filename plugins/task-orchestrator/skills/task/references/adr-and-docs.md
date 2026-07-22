# Documentation and ADRs

Two distinct artifacts, depending on what the task has changed.

## 1. Documentation (`docs/`)

Update the affected `.md` files when the task changes observable behavior, API
contracts, configuration, or introduces new limitations. Examples: a module's
README, a usage guide, an endpoint reference, configuration notes.

Practical rule: if someone using the project a month from now would need to know
this, it goes in docs. If it's just an internal detail that can be inferred by
reading the code, don't duplicate it.

**Diagrams (Mermaid)**: text is the primary resource. A Mermaid diagram is
welcome when it clarifies something that prose would make convoluted — a flow, a
state machine, the relationships of an architecture — but never as a substitute
for a clear explanation nor as decoration. Embed it in a ```mermaid block inside
the `.md`. If you doubt whether the diagram adds value, it probably doesn't: leave
it as text.

## 2. ADR (Architecture Decision Record)

An ADR captures **one architecture decision** and its why, so that the future team
(or you six months from now) understands why things are the way they are.

**When to create one**: the task chose between alternatives with long-term
consequences (a pattern, a library, a design trade-off, a contract change).

**When NOT to**: trivial changes, fixes without an underlying decision. An empty
ADR is debt, not documentation — skip it and say so.

**Location and numbering**: `docs/adr/NNNN-<title-in-kebab>.md`, with `NNNN` an
incremental four-digit number (look at the last existing one and add one). Use
`assets/adr.template.md`.

**Fields specific to this flow** (in addition to the standard Context / Decision /
Consequences):
- **Workflow changes**: how the way the team works changes, if applicable.
- **Limitations**: what this decision does NOT solve, known constraints.
- **Decisions the user made**: the phase 4 answers that shaped the result.
  Attribute them explicitly — they're context that gets lost if not noted down.

The ADR's status usually starts at `Proposed` and moves to `Accepted` on merge.
