# ADR-004: Pre-commit Code Review Hook

## Status
Accepted

## Context
During validation of the blueprint on `amaia-agent`, we discovered that relying
solely on on-demand code review (skills, agents, manual request) leaves gaps.
Bugs reached production that automated checks could have caught:

1. **Price accuracy bug**: coupon final price calculation was wrong because ML
   coupons have hidden discount caps. The code calculated `price * coupon%` but
   the actual coupon gave a fraction of that. Users saw misleading prices,
   damaging trust.

2. **Pix transparency bug**: ML shows Pix-specific prices as the main price on
   listings, but the bot posted them without mentioning "no Pix", making the
   discount appear larger than it was for other payment methods.

3. **Affiliate link redirect bug**: `fetch()` followed ML's redirect to a login
   page, breaking product links for end users.

All three bugs would have been caught by simple grep-based checks run before commit.

## Decision
Add `scripts/pre-commit-review.sh` as a Claude Code hook that runs automatically
before every `git commit`. The script:

- Checks staged source files only (fast, focused)
- Runs universal checks (compilation, tests, secrets, quality)
- Supports project-specific checks via `[SPEC]` sections
- Blocks commits on MUST FIX issues (exit code 2)
- Warns on SHOULD FIX issues (exit code 0)

The hook is registered in `.claude/hooks.json` as a `PreToolUse` matcher on
`Bash(git commit*)`.

## Alternatives considered

1. **Git native pre-commit hook (.git/hooks/pre-commit)**
   - Pro: Works outside Claude Code
   - Con: Doesn't integrate with Claude Code's hook system, harder to manage
   - Con: .git/hooks/ not committed to repo

2. **CI-only checks (GitHub Actions)**
   - Pro: Runs on every push regardless of local setup
   - Con: Feedback loop too slow (push → wait → fail → fix → push)
   - Con: Doesn't prevent bad commits from being created

3. **Agent-only review (invoke agents before commit)**
   - Pro: Deep, context-aware analysis
   - Con: Requires explicit invocation — easy to forget
   - Con: Slow for small changes (agent spawns full context)

4. **Husky / lint-staged (Node.js tooling)**
   - Pro: Well-established ecosystem
   - Con: Only works for Node.js projects
   - Con: Doesn't integrate with Claude Code hooks

## Consequences
- Positive: Every commit goes through automated review — no exceptions
- Positive: Project-specific checks encode lessons from production bugs
- Positive: Fast feedback (seconds, not minutes)
- Positive: Template is stack-agnostic (TypeScript, Python, Go)
- Negative: Adds ~5-15 seconds to commit time (compilation + tests)
- Negative: Grep-based checks have false positives — may need tuning
- Risks: Over-aggressive checks could slow down development

## Impact on specs
- Security: Catches hardcoded secrets before they reach git history
- Testing: Enforces test existence for changed files
- Observability: Catches console.log leaks (should use structured logger)

## References
- Spec: `docs/specs/code-review-gates.md`
- Hook: `.claude/hooks.json` → `PreToolUse` → `Bash(git commit*)`
- Script: `scripts/pre-commit-review.sh`
- Origin: `amaia-agent` production bugs (2026-03-31)
