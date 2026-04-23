Scan codebase for technical debt and produce a prioritized report.

Arguments: $ARGUMENTS (optional: directory to scan, or "full" for everything)

Workflow:
1. Activate the `tech-debt` skill
2. Phase 1 — Automated scan: TODOs, type suppressions, large files, high-churn files, outdated deps, skipped tests
3. Phase 2 — Manual assessment: classify each finding as real debt or justified exception
4. Phase 3 — Prioritize: score by frequency × severity × (1/effort)
5. Phase 4 — Write report to docs/architecture/tech-debt-report-{date}.md
6. Present summary: total items, critical/important/minor counts, top 5 to fix

Does NOT fix anything — only catalogs and prioritizes. Use /refactor or /clean to fix.
