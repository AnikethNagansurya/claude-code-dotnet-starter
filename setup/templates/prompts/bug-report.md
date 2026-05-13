# Bug Report Prompt Template

> Use this when asking Claude to investigate and fix a bug.
> The more evidence you provide, the faster the root cause is found.
> For bug triage from a build/test failure log, use `/fix-bug` directly.

---

## Prompt

Investigate and fix the following bug:

**Summary:** [One sentence describing what's wrong]

**Expected behaviour:** [What should happen]

**Actual behaviour:** [What is actually happening]

**Steps to reproduce:**
1. [Step 1]
2. [Step 2]
3. [Observed result]

**Error / stack trace:**
```
[Paste the full error message or stack trace here]
```

**When it started:** [Always happened / started after commit X / started after deploying Y]

**Frequency:** [Always / intermittent ~N% / only under specific conditions]

**Affected version / branch:** [version number or branch name]

**Environment:** [Local / Dev / Staging / Production]

---

## Evidence already gathered (what you've tried)

- [What you already investigated and ruled out]
- [Any hypothesis you have]
- [Relevant logs or metrics]

---

## Constraints

- [Must not change the public API]
- [Fix must be backward-compatible with existing data]
- [Cannot require a deployment of service X to fix]

---

## Definition of done

- [ ] Root cause identified and documented
- [ ] Fix applied with minimal scope (no unrelated changes)
- [ ] Regression test added that would catch this bug
- [ ] Affected tests all pass (`dotnet test`)
- [ ] If pattern is recurring, surfaced as a Lesson Candidate for `@lesson-curator`
