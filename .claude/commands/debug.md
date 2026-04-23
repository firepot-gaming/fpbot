Systematic debugging: reproduce, isolate, hypothesize, fix, verify, document.

Arguments: $ARGUMENTS (error message, file path, or description of the problem)

Workflow:
1. Activate the `debugger` skill
2. Understand the problem from $ARGUMENTS
3. Phase 1 — Reproduce: confirm the bug, get the exact error
4. Phase 2 — Isolate: check recent git changes, narrow scope
5. Phase 3 — Hypothesize: form 2+ possible causes with evidence
6. Phase 4 — Fix: apply minimal fix for the most likely cause
7. Phase 5 — Verify: run the failing test + full suite
8. Phase 6 — Document: post-mortem (production) or Gotcha (recurring trap)

Never guess. Always gather evidence first.
