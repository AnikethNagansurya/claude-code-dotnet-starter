# Technical Debt Review Prompt Template

> Use this when asking Claude to analyse and prioritise technical debt in a codebase area.
> Pair with `@refactoring-agent` if the remediation involves structural refactors.

---

## Prompt

Review the following area for technical debt and produce a prioritised remediation plan:

**Area:** [File, module, service, or feature area to review]

**Symptoms motivating this review:**
- [e.g. "This area changes frequently but tests fail unpredictably"]
- [e.g. "Every new feature in this module takes 3× longer than expected"]
- [e.g. "New team members are confused by this code consistently"]

**What I already know is problematic (optional):**
- [Specific issue 1]
- [Specific issue 2]

---

## What I need

1. **Identify** all debt items in the specified area:
   - Code smells (complexity, duplication, naming)
   - Missing tests or incomplete test coverage
   - Outdated patterns inconsistent with the rest of the codebase
   - Missing documentation on non-obvious behaviour
   - Performance problems
   - Security risks

2. **Prioritise** each item by:
   - Impact (HIGH / MEDIUM / LOW) — how much does this slow the team down or risk production?
   - Effort (HOURS / DAYS / WEEKS) — rough estimate
   - Risk (HIGH / LOW) — likelihood of introducing bugs when fixing

3. **Propose** a remediation plan:
   - What to fix first and why
   - What can be deferred safely
   - What requires a larger architectural change (flag for ADR via `prompts/architecture-decision.md`)

4. **Output format:**
```
## Technical Debt: [area]

### HIGH Impact Items
| Item | File:Line | Effort | Risk | Fix |
|------|-----------|--------|------|-----|
| [debt] | [location] | [effort] | [risk] | [approach] |

### MEDIUM Impact Items
...

### LOW / Defer
...

### Recommended remediation order
1. [item] — [reason it's first]
2. [item]
...
```

---

## Constraints

- [Only fix debt that can be done without breaking the public API]
- [Each fix must be independently deployable]
- [Time budget: [N] developer-days]
- Frozen names in `.claude/lessons.md` Naming Constraints are off-limits regardless of debt level
