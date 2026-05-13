# Code Review Request Prompt Template

> Use this when asking `@code-reviewer` to review a specific changeset with context about what to focus on.
> For pre-merge review including breaking-change / migration / dependency safety, use `@pr-reviewer` instead.

---

## Prompt

Please review the following code changes:

**What changed:** [1–2 sentences describing the change]

**Why it was made:** [The motivation — bug fix, new feature, refactor]

**PR / branch:** [PR number or branch name, or paste the diff below]

**Review focus** (what I'm most uncertain about):
- [ ] Correctness — [specific logic I want verified]
- [ ] Async safety — [specific async path or cancellation flow]
- [ ] EF Core — [specific query, transaction, or migration concern]
- [ ] Null safety — [specific nullable annotations]
- [ ] Security — [specific auth/input concern]
- [ ] Performance — [specific hot path or query]
- [ ] Design — [specific pattern or abstraction choice]
- [ ] Test coverage — [specific scenarios I may have missed]

**Explicitly out of scope** (do not review):
- [File or concern to ignore]

---

## Context

**Testing done:**
- [What you manually tested]
- [What automated tests cover this]

**Known limitations:**
- [Anything you knowingly left out and why]

**Dependencies or follow-up work:**
- [Any PRs this depends on]
- [Any cleanup planned in a follow-up]

---

## Diff (paste if not on a branch)

```diff
[paste diff here if not referencing a branch/PR]
```
