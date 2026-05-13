# Architecture Decision Prompt Template

> Use this when asking `@architecture-reviewer` to evaluate an architectural decision and produce an ADR.

---

## Prompt

Help me make the following architecture decision:

**Decision needed:** [What choice needs to be made?]
Example: "Choose between a monolith and microservices for the new reporting module"
Example: "Decide whether to use a message queue or direct HTTP calls between Service A and B"

**Context:**
- Current system: [brief description of what exists today]
- Why this decision needs to be made now: [driver — new requirement, scaling problem, etc.]
- Who is affected: [teams, services, users]

**Constraints (non-negotiable):**
- [Must use Azure cloud infrastructure]
- [Must not require downtime for migration]
- [Team has no Kubernetes expertise]

**Quality attributes to optimise for (in priority order):**
1. [e.g. Reliability — 99.9% uptime SLA]
2. [e.g. Developer velocity — small team, 2-week sprints]
3. [e.g. Operational simplicity — small ops team]

**Options already considered:**
- Option A: [description] — [why you're considering it]
- Option B: [description] — [why you're considering it]
- Option C: [description] — [why you're considering it]

---

## What I need from you

1. Evaluate each option against the stated quality attributes
2. Identify risks and unknowns for each option
3. Recommend one option with justification
4. Have `@doc-generator` write an ADR (Architecture Decision Record) for the chosen option in `docs/adr/`
5. List the decisions that must be made BEFORE implementation begins
6. If the decision constrains future work in a project-wide way, surface as a Lesson Candidate (heading: Architecture Deltas)

---

## References

- Related ADRs: [links]
- Relevant tech docs: [links]
- Similar decisions in the industry: [context]
